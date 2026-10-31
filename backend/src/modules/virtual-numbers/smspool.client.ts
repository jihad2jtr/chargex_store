/**
 * موصال SMSPool (أرقام التحقق الوهمية) على واجهة REST.
 *
 *   GET  /country/retrieve_all          → قائمة الدول (ID, name, short_name, cc, region)
 *   GET  /service/retrieve_all          → قائمة الخدمات (ID, name)
 *   POST /pool/retrieve_all             → قائمة المجمّعات (ID, name)
 *   POST /sms/all_stock                 → صفوف (country, service, pool, stock, price) لكل العالم
 *   POST /purchase/sms                  → الرقم فوراً: { success, number, cc, phonenumber, order_id, cost }
 *   POST /sms/check   { orderid }       → 1 انتظار، 3 رسالة، 6 إرجاع
 *   POST /sms/cancel  { orderid }       → { success: 1 }
 *
 * ما يميّز هذا المزود تقنياً: يستجيب بأكواد MessagePack رغم أنه يعلن
 * `Content-Type: application/json`، فتُ解码 الاستجابة بالمفكّ المصغّر أدناه قبل
 * أي قراءة (ولو فُسّرت كـ JSON لانعدمت كل البيانات). والمفتاح يُرسل في ترويسة
 * `Authorization: Bearer` أو معلاً `key` في المتن، والأول أدقّ لأنه لا يظهر في السجلات.
 *
 * الدولة والخدمة رموزهما أرقام صريحة (1 = الولايات المتحدة)، وهي أكواد المزود
 * نفسه التي يجب أن تعود في الشراء، فلا تُستبدل بأكواد مزود آخر — وأسماء المعجم
 * لا تُقبل إلا حين تؤكدها تسمية المزود (trustDictionaryName).
 */

import { BadRequestException, Logger } from '@nestjs/common';
import axios, { AxiosRequestConfig } from 'axios';
import {
  VirtualNumberCancelParams,
  VirtualNumberClient,
  VirtualNumberCredentials,
  VirtualNumberHandle,
  VirtualNumberProfile,
  VirtualNumberProviderError,
  VirtualNumberServiceEntry,
  VirtualNumberState,
  VirtualNumberStatusResult,
  digitsOnly,
  extractVerificationCode,
  isTimeoutError,
  pickStringValue,
  providerErrorMessage,
  toEntries,
  toNumberValue,
  trustDictionaryName,
} from './virtual-number-client';
import {
  resolveAppMeta,
  resolveCountryMeta,
} from './virtual-numbers-dictionary';

export const SMSPOOL_DEFAULT_BASE = 'https://api.smspool.net';

/**
 * جذر API: يقبل رابط الموقع أو المضيف أو …/v1 ويترك الضبط كما هو — فمسارات
 * SMSPool بلا بادئة إصدار (https://api.smspool.net/sms/check).
 */
export function smsPoolApiRoot(baseUrl?: string): string {
  let raw = (baseUrl || '').trim().replace(/\/+$/, '');
  if (!raw) return SMSPOOL_DEFAULT_BASE;
  if (!/^https?:\/\//i.test(raw)) raw = `https://${raw}`;

  try {
    const url = new URL(raw);
    return `${url.origin}${url.pathname.replace(/\/+$/, '')}`;
  } catch {
    return SMSPOOL_DEFAULT_BASE;
  }
}

// ---------------------------------------------------------------------------
// فك ترميز MessagePack
// ---------------------------------------------------------------------------

/**
 * مفكّ MessagePack مصغّر يغطي ما تُرجعه SMSPool فعلياً: nil والمنطق والأعداد
 * (بما فيها 64-bit) والنصوص والمصفوفات والقواميس. الامتدادات (0xc8…) لا تظهر في
 * responsesهم، فتُترك كقيمة null بدل أن تنهار المزامنة كلها على حقل واحد.
 */
export function decodeMsgPack(input: ArrayBuffer | Uint8Array | string): any {
  const bytes =
    typeof input === 'string'
      ? new Uint8Array(Buffer.from(input, 'binary'))
      : new Uint8Array(
          input instanceof Uint8Array
            ? input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength)
            : input,
        );
  const view = new DataView(bytes.buffer);
  let offset = 0;

  const need = (count: number): void => {
    if (offset + count > bytes.length) throw new RangeError('msgpack: truncated payload');
  };
  const u8 = (): number => (need(1), bytes[offset++]);
  const u16 = (): number => (need(2), (offset += 2), view.getUint16(offset - 2));
  const u32 = (): number => (need(4), (offset += 4), view.getUint32(offset - 4));
  const i8 = (): number => (need(1), (offset += 1), view.getInt8(offset - 1));
  const i16 = (): number => (need(2), (offset += 2), view.getInt16(offset - 2));
  const i32 = (): number => (need(4), (offset += 4), view.getInt32(offset - 4));
  const takeBytes = (length: number): Uint8Array => {
    need(length);
    const slice = bytes.subarray(offset, offset + length);
    offset += length;
    return slice;
  };
  const readString = (length: number): string =>
    Buffer.from(takeBytes(length)).toString('utf8');

  const readFloat32 = (): number => {
    const value = (need(4), view.getFloat32(offset));
    offset += 4;
    return value;
  };
  const readFloat64 = (): number => {
    const value = (need(8), view.getFloat64(offset));
    offset += 8;
    return value;
  };
  const readU64 = (): number => {
    const value = (need(8), view.getBigUint64(offset));
    offset += 8;
    return Number(value);
  };
  const readI64 = (): number => {
    const value = (need(8), view.getBigInt64(offset));
    offset += 8;
    return Number(value);
  };
  const readArray = (length: number): any[] => {
    const list: any[] = [];
    for (let index = 0; index < length; index += 1) list.push(readValue());
    return list;
  };
  const readMap = (length: number): Record<string, any> => {
    const node: Record<string, any> = {};
    for (let index = 0; index < length; index += 1) {
      const key = readValue();
      node[String(key)] = readValue();
    }
    return node;
  };

  const readValue = (): any => {
    const format = u8();

    // fixint موجب (0x00-0x7f) وسالب (0xe0-0xff)
    if (format <= 0x7f) return format;
    if (format >= 0xe0) return format - 256;
    // fixmap / fixarray / fixstr
    if ((format & 0xf0) === 0x80) return readMap(format & 0x0f);
    if ((format & 0xf0) === 0x90) return readArray(format & 0x0f);
    if ((format & 0xe0) === 0xa0) return readString(format & 0x1f);

    switch (format) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xc4:
        return Buffer.from(takeBytes(u8())).toString('utf8');
      case 0xc5:
        return Buffer.from(takeBytes(u16())).toString('utf8');
      case 0xc6:
        return Buffer.from(takeBytes(u32())).toString('utf8');
      case 0xca:
        return readFloat32();
      case 0xcb:
        return readFloat64();
      case 0xcc:
        return u8();
      case 0xcd:
        return u16();
      case 0xce:
        return u32();
      case 0xcf:
        return readU64();
      case 0xd0:
        return i8();
      case 0xd1:
        return i16();
      case 0xd2:
        return i32();
      case 0xd3:
        return readI64();
      case 0xd9:
        return readString(u8());
      case 0xda:
        return readString(u16());
      case 0xdb:
        return readString(u32());
      case 0xdc:
        return readArray(u16());
      case 0xdd:
        return readArray(u32());
      case 0xde:
        return readMap(u16());
      case 0xdf:
        return readMap(u32());
      default:
        // امتداد أو نمط غير معروف: لا يجوز أن يُفشل قراءة كتالوج كامل
        return null;
    }
  };

  return readValue();
}

/**
 * إرجاع استجابة SMSPool: msgpack في الغالب، وJSON إن بدّل المزود سلوكه يوماً.
 * تُقرأ الاستجابة ثنائية (`arraybuffer`) كي لا تفسد الترميزَ تحويلات axios النصية.
 */
export function decodeSmsPoolResponse(data: any): any {
  if (data == null) return null;
  if (
    typeof data === 'object' &&
    !(data instanceof ArrayBuffer) &&
    !ArrayBuffer.isView(data)
  ) {
    return data;
  }

  const text = (
    typeof data === 'string' ? data : Buffer.from(data as Uint8Array).toString('utf8')
  ).trim();
  // JSON صريح (أو نص مُعلّب) يُقدَّم على المفكّ: msgpack لا يبدأ أبداً بـ { أو [
  if (/^[[{]/.test(text)) {
    try {
      return JSON.parse(text);
    } catch {
      /* ليس JSONاً كاملاً: يبقى محتملاً كمفكّ msgpack */
    }
  }

  try {
    return decodeMsgPack(typeof data === 'string' ? Buffer.from(data, 'binary') : data);
  } catch {
    // استجابة نصية عادية (رسالة خطأ مثلاً) تُترك كما وصلت
    return text || null;
  }
}

// ---------------------------------------------------------------------------
// الكتالوج
// ---------------------------------------------------------------------------

interface StockPool {
  id: string;
  name: string;
  cost: number;
  count: number;
}

interface StockCountry {
  code: string;
  name: string;
  iso: string;
  pools: StockPool[];
}

interface StockService {
  code: string;
  name: string;
  countries: Map<string, StockCountry>;
}

/**
 * /sms/all_stock صفوف مسطّحة (دولة × خدمة × مجمّع) تحمل السعر والمخزون. تُطوى
 * إلى خدمة ← دول كبقية الموصّلات: سعر الدولة أرخص مجمّع يملك مخزوناً (وإلا
 * أرخصها مطلقاً)، والمجمّعات تُعرض بأسمائها لكن بقابل «any» لأن الشراء لا يمرَّر
 * إليه معرّف المجمّع — اختيار مجمّع خطأ برسالة لا معنى لها للعميل أخطر من ترك
 * المزود يختار.
 */
export function normalizeSmsPoolCatalog(input: {
  stock: any;
  services?: any;
  countries?: any;
}): VirtualNumberServiceEntry[] {
  const rows = Array.isArray(decodeIfWrapped(input.stock))
    ? (decodeIfWrapped(input.stock) as any[])
    : [];

  const serviceNames = new Map<string, string>();
  for (const entry of toEntries(input.services)) {
    const id = pickStringValue(entry.value, ['ID', 'id', 'service_id']) ?? entry.key;
    const name = pickStringValue(entry.value, ['name', 'service_name']);
    if (id && name) serviceNames.set(String(id), name);
  }

  const countryMeta = new Map<string, { name: string; iso: string }>();
  for (const entry of toEntries(input.countries)) {
    const id = pickStringValue(entry.value, ['ID', 'id', 'country_id']) ?? entry.key;
    const name = pickStringValue(entry.value, ['name', 'country_name']);
    if (id) {
      countryMeta.set(String(id), {
        name: name ?? String(id),
        iso: pickStringValue(entry.value, ['short_name', 'iso']) ?? '',
      });
    }
  }

  const byService = new Map<string, StockService>();
  for (const row of rows) {
    if (!row || typeof row !== 'object') continue;
    const serviceCode = pickStringValue(row, ['service', 'service_id']);
    const countryCode = pickStringValue(row, ['country', 'country_id']);
    const cost = toNumberValue(row.price ?? row.cost);
    if (!serviceCode || !countryCode || cost <= 0) continue;

    const service = byService.get(serviceCode) ?? {
      code: serviceCode,
      name:
        pickStringValue(row, ['service_name']) ??
        serviceNames.get(serviceCode) ??
        serviceCode,
      countries: new Map<string, StockCountry>(),
    };
    byService.set(serviceCode, service);

    const meta = countryMeta.get(countryCode);
    const country = service.countries.get(countryCode) ?? {
      code: countryCode,
      name: pickStringValue(row, ['country_name']) ?? meta?.name ?? countryCode,
      iso: meta?.iso ?? '',
      pools: [],
    };
    service.countries.set(countryCode, country);

    country.pools.push({
      id: pickStringValue(row, ['pool', 'pool_id']) ?? '',
      name: pickStringValue(row, ['pool_name']) ?? 'Default',
      cost,
      count: toNumberValue(row.stock ?? row.count),
    });
  }

  const entries: VirtualNumberServiceEntry[] = [];
  for (const service of byService.values()) {
    const appMeta = resolveAppMeta(service.code, 'smspool');
    // الاسم المعجمي مقبول فقط إن طابق اسم المزود: الأرقام تتصادم مع أكواد غيره
    const named = trustDictionaryName(service.name, () =>
      resolveAppMeta(service.code, 'smspool'),
    );
    const countries = [...service.countries.values()]
      .map((country) => {
        const stocked = country.pools.filter((pool) => pool.count > 0);
        const pool = stocked.length > 0 ? stocked : country.pools;
        const cheapest = pool.reduce((best, item) => (item.cost < best.cost ? item : best));
        const dictionary = resolveCountryMeta(country.iso || country.code, 'smspool');
        const namedCountry = trustDictionaryName(country.name, () =>
          resolveCountryMeta(country.iso || country.code, 'smspool'),
        );
        return {
          // الرمز المُخزَّن هو معرّف المزود: الشراء يطلبه به حصراً
          code: country.code,
          name: country.name || dictionary.nameAr || country.code,
          nameAr: namedCountry.nameAr,
          nameEn: namedCountry.nameEn,
          flag: dictionary.flag,
          iso: country.iso || dictionary.iso,
          cost: cheapest.cost,
          count: country.pools.reduce((sum, item) => sum + item.count, 0),
          operators: pool
            .slice()
            .sort((a, b) => a.cost - b.cost)
            .map((item) => ({ code: 'any', name: item.name })),
        };
      })
      .filter((country) => country.cost > 0)
      .sort((a, b) => a.cost - b.cost);

    if (countries.length === 0) continue;
    entries.push({
      code: service.code,
      name: named.nameEn || service.name || appMeta.name,
      nameAr: named.nameAr,
      nameEn: named.nameEn,
      icon: appMeta.icon,
      herosmsCode: appMeta.herosmsCode,
      fivesimCode: appMeta.fivesimCode,
      smspoolCode: service.code,
      countries,
    });
  }

  return entries.sort((a, b) => a.countries[0].cost - b.countries[0].cost);
}

/** صفوف /sms/all_stock تصل قائمة صريحة؛ التفاف مستقبلي لا يُفشل القراءة */
function decodeIfWrapped(source: any): any {
  if (!source || typeof source !== 'object') return source;
  if (Array.isArray(source)) return source;
  const list = (source as any).data ?? (source as any).stock ?? (source as any).results;
  return Array.isArray(list) ? list : source;
}

// ---------------------------------------------------------------------------
// الحالة والأخطاء
// ---------------------------------------------------------------------------

/**
 * أرقام حالة /sms/check: 1 انتظار، 3 رسالة جاهزة، 6 إرجاع المبلغ. ما عداها
 * مجهول ويبقى انتظاراً حتى تُنهي المهلة الطلب — أضمن مالياً من تخمين إلغاء.
 */
export function classifySmsPoolStatus(payload: any): VirtualNumberState {
  if (!payload || typeof payload !== 'object') return 'unknown';

  const smsText = pickStringValue(payload, ['full_sms', 'sms']);
  const raw = String(payload.status ?? payload.state ?? '').trim().toUpperCase();

  if (smsText) return 'received';
  if (raw && !/^\d+$/.test(raw)) {
    if (/COMPLETE|RECEIVED|DELIVERED/.test(raw)) return 'received';
    if (/CANCEL|REFUND|EXPIRE|TIMEOUT|NOT.?FOUND|FAIL/.test(raw)) return 'cancelled';
    if (/PENDING|WAIT|PROGRESS|ACTIVE/.test(raw)) return 'waiting';
  }

  const numeric = toNumberValue(payload.status ?? payload.state);
  if (numeric === 1 || numeric === 2) return 'waiting';
  if (numeric === 3) return 'received';
  if (numeric === 6 || numeric === 4 || numeric === 5) return 'cancelled';
  return 'unknown';
}

/** نص الرسالة: full_sms هو الإعلان الكامل و sms الرمز وحده */
export function readSmsPoolSms(payload: any): { smsText?: string; code?: string } {
  const full = pickStringValue(payload, ['full_sms', 'sms_text', 'text']);
  const short = pickStringValue(payload, ['sms', 'code']);
  const smsText = full ?? short ?? undefined;
  const code = short && /^\d{3,10}$/.test(short) ? short : smsText ? extractVerificationCode(smsText) : null;
  return { smsText, code: code ?? undefined };
}

/** رسائل المزود تحمل وسوم HTML أحياناً، والعميل يقرأ عبارة نظيفة */
export function cleanSmsPoolMessage(payload: any): string | null {
  if (!payload || typeof payload !== 'object') return null;
  const raw =
    pickStringValue(payload, ['message', 'error', 'description']) ??
    (Array.isArray((payload as any).errors)
      ? pickStringValue((payload as any).errors[0], ['message', 'description'])
      : null);
  if (!raw) return null;
  const text = raw
    .replace(/<[^>]*>/g, ' ')
    .replace(/https?:\/\/\S+/g, '(الرابط في وثائق المزود)')
    .replace(/\s+/g, ' ')
    .trim();
  return text || null;
}

/** رقم الشراء: number قد يكون ناقصاً، و cc + phonenumber هما الصيغة الدولية */
export function pickSmsPoolNumber(payload: any): string | null {
  const composed = pickStringValue(payload, ['cc']) && pickStringValue(payload, ['phonenumber']);
  if (composed) {
    return digitsOnly(`${pickStringValue(payload, ['cc'])}${pickStringValue(payload, ['phonenumber'])}`);
  }
  const direct = pickStringValue(payload, ['number', 'phonenumber', 'phone']);
  return direct ? digitsOnly(direct) : null;
}

export class SmsPoolClient implements VirtualNumberClient {
  private static readonly CALL_TIMEOUT_MS = 20_000;
  private static readonly STATUS_TIMEOUT_MS = 10_000;
  // /sms/all_stock يعيد مخزون العالم كله (عشرات الميغابايت بعد فك الترميز)
  private static readonly CATALOG_TIMEOUT_MS = 180_000;

  private readonly logger = new Logger(SmsPoolClient.name);

  constructor(private readonly creds: VirtualNumberCredentials) {}

  private get root(): string {
    return smsPoolApiRoot(this.creds.baseUrl);
  }

  private headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.creds.apiKey}`,
      // الاستجابة msgpack دائماً، فلا فائدة من الادعاء بطلب JSON
      Accept: 'application/json',
    };
  }

  /**
   * طلب بنمط نموذج url-encoded كما توثّقه SMSPool: أغلب نقاطها لا تقبل JSON
   * في المتن، والمفتاح يُرسل في الترويسة وحدها.
   */
  private async call(
    path: string,
    init: { method: 'get' | 'post'; params?: Record<string, any>; form?: Record<string, any>; timeout: number },
  ): Promise<any> {
    const config: AxiosRequestConfig = {
      method: init.method,
      url: `${this.root}${path}`,
      headers: {
        ...this.headers(),
        ...(init.method === 'post'
          ? { 'Content-Type': 'application/x-www-form-urlencoded' }
          : {}),
      },
      params: init.params,
      data: init.method === 'post' ? new URLSearchParams(stringifyForm(init.form ?? {})).toString() : undefined,
      timeout: init.timeout,
      responseType: 'arraybuffer',
      // المفكّ يقرّر msgpack أم JSON، فلا تدع axios يحاول التخمين
      transformResponse: undefined,
      validateStatus: (status: number) => status < 400,
    };

    try {
      const res = await axios.request(config);
      const payload = decodeSmsPoolResponse(res.data);
      return payload;
    } catch (err: any) {
      throw new SmsPoolCallError(err);
    }
  }

  // --- الرصيد والحساب -------------------------------------------------------

  async getProfile(): Promise<VirtualNumberProfile> {
    let payload: any;
    try {
      payload = await this.call('/request/balance', {
        method: 'post',
        timeout: SmsPoolClient.STATUS_TIMEOUT_MS,
      });
    } catch (err: any) {
      throw new BadRequestException(
        `تعذر التحقق من حساب مزود الأرقام الوهمية: ${errMessage(err)}`,
      );
    }

    return {
      // balance نص لدى المزود ("5.00") لكنه دولار كما في اللوحة
      balance: toNumberValue(payload?.balance),
      raw: payload,
    };
  }

  // --- كتالوج الخدمات والأسعار --------------------------------------------

  async getCatalog(): Promise<VirtualNumberServiceEntry[]> {
    const stock = await this.call('/sms/all_stock', {
      method: 'post',
      timeout: SmsPoolClient.CATALOG_TIMEOUT_MS,
    }).catch((err: any) => {
      throw new BadRequestException(
        `تعذر جلب بيانات مزود الأرقام الوهمية: ${errMessage(err)}`,
      );
    });

    const [services, countries] = await Promise.all([
      // الأسماء تجميلية: صفوف المخزون تحملها أصلاً، وغيابها لا يُفشل الكتالوج
      this.call('/service/retrieve_all', {
        method: 'get',
        timeout: SmsPoolClient.CATALOG_TIMEOUT_MS,
      }).catch(() => null),
      this.call('/country/retrieve_all', {
        method: 'get',
        params: { show_all: 1 },
        timeout: SmsPoolClient.CATALOG_TIMEOUT_MS,
      }).catch(() => null),
    ]);

    const entries = normalizeSmsPoolCatalog({ stock, services, countries });
    if (entries.length === 0) {
      throw new BadRequestException('قائمة الخدمات فارغة من المزود');
    }
    return entries;
  }

  // --- طلب رقم -------------------------------------------------------------

  async requestNumber(params: {
    service: string;
    country: string;
    operator?: string;
  }): Promise<VirtualNumberHandle> {
    const form: Record<string, any> = {
      country: params.country,
      service: params.service,
      // أرخص رقم متاح: هو ما يُباع في اللوحة، والعميل لا يدفع فارق الجودة
      pricing_option: 0,
      activation_type: 'SMS',
    };

    let payload: any;
    try {
      payload = await this.call('/purchase/sms', {
        method: 'post',
        form,
        timeout: SmsPoolClient.CALL_TIMEOUT_MS,
      });
    } catch (err: any) {
      throw new VirtualNumberProviderError(
        `تعذر الحصول على رقم من مزود الخدمة: ${errMessage(err)}`,
        isTimeoutError(err),
        err?.status,
      );
    }

    const id = pickStringValue(payload, ['order_id', 'orderid', 'id']);
    const number = pickSmsPoolNumber(payload);

    // success:0 مع 200 لا يعني فشلاً قاطعاً فحسب، بل نوع الخطأ (OUT_OF_STOCK…)
    const failed = toNumberValue(payload?.success) !== 1;
    if (!id || !number || failed) {
      throw new VirtualNumberProviderError(
        cleanSmsPoolMessage(payload) ||
          (payload ? 'لم يعيد المزود رقماً' : 'استجابة فارغة من المزود'),
      );
    }

    return { id, number, raw: payload };
  }

  // --- حالة الطلب ----------------------------------------------------------

  async fetchStatus(id: string): Promise<VirtualNumberStatusResult> {
    let payload: any;
    try {
      payload = await this.call('/sms/check', {
        method: 'post',
        form: { orderid: id },
        timeout: SmsPoolClient.STATUS_TIMEOUT_MS,
      });
    } catch (err: any) {
      const message = errMessage(err);
      // الطلب لم يعد لدى المزود (انتهى أو أُلغي): الإلغاء هو ما يُرجع المبلغ
      if (err?.status === 404 || /not[ _-]?found/i.test(message)) {
        return { state: 'cancelled', status: 'NOT_FOUND', raw: { message } };
      }
      throw new VirtualNumberProviderError(
        `تعذر فحص حالة الرقم: ${message}`,
        isTimeoutError(err),
        err?.status,
      );
    }

    const read = readSmsPoolSms(payload);
    const state = classifySmsPoolStatus(payload);
    // إعلان وصول بلا رمز ملموس يبقى انتظاراً: لا شيء يُعرض للعميل بعد
    if (state === 'received' && !read.code) {
      return { state: 'waiting', status: String(payload?.status ?? ''), smsText: read.smsText, raw: payload };
    }

    return {
      state,
      status: pickStringValue(payload, ['status', 'state']) ?? undefined,
      smsText: read.smsText,
      code: read.code,
      raw: payload,
    };
  }

  // --- إنهاء / إلغاء الرقم -------------------------------------------------

  /** لا عملية إنهاء لدى SMSPool: الرمز المسجَّل يُنهي الطلب نفسه */
  async markFinished(id: string): Promise<void> {
    this.logger.debug(`SMSPool has no finish operation (order ${id})`);
  }

  /** إلغاء الطلب قبل وصول الرسالة: success:0 يعني أنه لم يُلغَ، ولا يُرجع مالاً */
  async cancelNumber(params: VirtualNumberCancelParams): Promise<void> {
    try {
      const payload = await this.call('/sms/cancel', {
        method: 'post',
        form: { orderid: params.id },
        timeout: SmsPoolClient.CALL_TIMEOUT_MS,
      });
      if (payload && toNumberValue(payload.success) !== 1) {
        this.logger.warn(
          `SMSPool cancel ignored for ${params.id}: ${cleanSmsPoolMessage(payload) ?? 'success=0'}`,
        );
      }
    } catch (err: any) {
      // فشل التنظيف لا يُفشل عملية أتمّها العميل
      this.logger.warn(`SMSPool cancel failed for ${params.id}: ${errMessage(err)}`);
    }
  }
}

/** تحويل متن النموذج إلى نصوص (القيم الرقمية مقبولة كما هي) */
function stringifyForm(form: Record<string, any>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(form)) {
    if (value === undefined || value === null || value === '') continue;
    out[key] = String(value);
  }
  return out;
}

/** خطأ SMSPool: يحفظ status ويترك رسالة axios الأصلية للقارئ */
class SmsPoolCallError extends Error {
  readonly status?: number;
  readonly isTimeout: boolean;

  constructor(readonly cause: any) {
    super(errMessage(cause));
    this.name = 'SmsPoolCallError';
    this.status = cause?.response?.status;
    this.isTimeout = isTimeoutError(cause);
  }
}

function errMessage(err: any): string {
  const data = err?.response?.data;
  const decoded = decodeSmsPoolResponse(data);
  return cleanSmsPoolMessage(decoded) || providerErrorMessage(err);
}
