/**
 * موصال 5sim (أرقام التحقق الوهمية) على واجهة المزوّد v2.
 *
 * المضيف القديم api.5sim.net أُزيل، والمسارات القديمة
 * (/v1/user/auth/addNumber، /v1/user/service/getPricesNew …) صارت تعود بصفحة
 * 404، فكان كل طلب رقم يفشل. الشكل الحيّ اليوم:
 *   GET /v1/user/profile                                     (Bearer)
 *   GET /v1/guest/prices              (دولة ← خدمة ← مشغّل: cost/count)
 *   GET /v1/guest/countries                                   (أسماء الدول)
 *   GET /v1/user/buy/activation/{country}/{operator}/{product}
 *   GET /v1/user/check|finish|cancel/{id}
 * ويُقبل أي baseUrl محفوظ في اللوحة (رابط الموقع، أو …/v1، أو …/v1/user، أو
 * المضيف القديم) فيُصحَّح إلى الجذر الحيّ بدل تعطيل السجل.
 *
 * الأخطاء تصل نصاً صريحاً (order not found / bad country / no free phones)،
 * فتُقرأ كما هي؛ ودليل وصول الرمز هو sms[].code أو نص الرسالة لا اسم الحالة وحده.
 *
 * الأنواع المشتركة بين الموصّلات (كتالوج، رقم، حالة) معرّفة في
 * virtual-number-client.ts فيُعيد هذا الملف استخدامها بأسمائها العامة.
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
  readSmsText,
  toNumberValue,
  unwrapPayload,
} from './virtual-number-client';
import {
  resolveAppMeta,
  resolveCountryMeta,
} from './virtual-numbers-dictionary';

export const FIVESIM_DEFAULT_BASE = 'https://5sim.net/v1';

/** المضيف القديم أُزيل من المزوّد، فسجلات اللوحة القديمة تُعاد توجيهها حيّاً */
const LEGACY_HOST = /^https?:\/\/api\.5sim\.net/i;

/**
 * سيرفرات المزوّد الداخلية تصل بأسماء تقنية بلا معنى للعميل (virtual4، virtual21…)
 * فتُخفى من قائمة المشغّلين المعروضة، ويبقى أثرها في حساب السعر والمخزون وحده.
 */
export function isHiddenServerName(name: string): boolean {
  return /^virtual\d*$/i.test((name || '').trim());
}

/**
 * جذر مسارات API الحيّ: يقبل ما تحفظه الإدارة (رابط الموقع، أو …/v1، أو
 * …/v1/user، أو المضيف القديم) ويعيد دائماً https://<host>/v1.
 */
export function fiveSimApiRoot(baseUrl?: string): string {
  let raw = (baseUrl || '').trim();
  if (!raw) return FIVESIM_DEFAULT_BASE;
  if (!/^https?:\/\//i.test(raw)) raw = `https://${raw}`;
  raw = raw.replace(LEGACY_HOST, 'https://5sim.net');

  try {
    const url = new URL(raw);
    const path = url.pathname.replace(/\/+$/, '').replace(/\/user$/i, '');
    return `${url.origin}${/\/v\d+$/i.test(path) ? path : `${path}/v1`}`;
  } catch {
    return FIVESIM_DEFAULT_BASE;
  }
}

/** أسماء الدول من /guest/countries: مفتاح الدولة ← الاسم المقروء */
function countryNameIndex(countries: any): Map<string, string> {
  const map = new Map<string, string>();
  const source = unwrapPayload(countries);
  if (!source || typeof source !== 'object') return map;

  for (const [code, value] of Object.entries(source as Record<string, any>)) {
    const node: any = value ?? {};
    const name =
      typeof node === 'string'
        ? node
        : String(node.text_ar || node.text_en || node.name || node.title || '').trim();
    if (name) map.set(code, name);
  }
  return map;
}

interface OperatorRow {
  code: string;
  name: string;
  cost: number;
  count: number;
}

interface CountryRow {
  code: string;
  name: string;
  operators: OperatorRow[];
}

/**
 * /guest/prices يعود دولة ← خدمة ← مشغّل ← {cost, count}، والصفحة تحتاج العكس
 * (خدمة ← دول). سعر الدولة = أرخص مشغّل يملك مخزوناً (وإلا أرخص مشغّل بلا
 * مخزون)، والقائمة تحفظ المشغّلين كي يختار العميل مشغّلاً بعينه.
 * هذا الإصدار يعيد رموز الخدمات وحدها (tg، wa…) فيبقى الرمز اسماً بديلاً.
 */
export function normalizeFiveSimCatalog(input: {
  prices: any;
  countries?: any;
}): VirtualNumberServiceEntry[] {
  const body = unwrapPayload(input.prices);
  if (!body || typeof body !== 'object') return [];

  const names = countryNameIndex(input.countries);
  const services = new Map<string, Map<string, CountryRow>>();

  for (const [countryCode, products] of Object.entries(body as Record<string, any>)) {
    if (!products || typeof products !== 'object') continue;

    for (const [productCode, operators] of Object.entries(products as Record<string, any>)) {
      if (!operators || typeof operators !== 'object') continue;

      const byCountry = services.get(productCode) ?? new Map<string, CountryRow>();
      services.set(productCode, byCountry);
      const row = byCountry.get(countryCode) ?? {
        code: countryCode,
        name: names.get(countryCode) || countryCode,
        operators: [],
      };
      byCountry.set(countryCode, row);

      for (const [operatorCode, leaf] of Object.entries(operators as Record<string, any>)) {
        const cost = toNumberValue(leaf?.cost ?? leaf?.price);
        if (cost <= 0) continue;
        row.operators.push({
          code: operatorCode,
          name: operatorCode,
          cost,
          count: toNumberValue(leaf?.count ?? leaf?.num),
        });
      }
    }
  }

  const entries: VirtualNumberServiceEntry[] = [];
  for (const [code, byCountry] of services) {
    const countries = [...byCountry.values()]
      .filter((row) => row.operators.length > 0)
      .map((row) => {
        const stocked = row.operators.filter((op) => op.count > 0);
        const pool = stocked.length > 0 ? stocked : row.operators;
        const cheapest = pool.reduce((best, op) => (op.cost < best.cost ? op : best));
        // رمز الدولة (slug) يُطابق صف المعجم مباشرة، والاسم العربي يأتي منه
        const cMeta = resolveCountryMeta(row.code, 'fivesim');
        return {
          code: row.code,
          name: row.name || cMeta.nameAr || cMeta.nameEn || row.code,
          nameAr: cMeta.nameAr,
          nameEn: cMeta.nameEn,
          flag: cMeta.flag,
          iso: cMeta.iso,
          cost: cheapest.cost,
          count: row.operators.reduce((sum, op) => sum + op.count, 0),
          operators: pool
            .filter((op) => !isHiddenServerName(op.code) && !isHiddenServerName(op.name))
            .sort((a, b) => a.cost - b.cost)
            .map((op) => ({ code: op.code, name: op.name })),
        };
      })
      .sort((a, b) => a.cost - b.cost);

    if (countries.length > 0) {
      const appMeta = resolveAppMeta(code, 'fivesim');
      entries.push({
        code,
        name: appMeta.name,
        nameAr: appMeta.nameAr,
        nameEn: appMeta.nameEn,
        icon: appMeta.icon,
        herosmsCode: appMeta.herosmsCode,
        fivesimCode: appMeta.fivesimCode,
        countries,
      });
    }
  }

  return entries.sort((a, b) => a.countries[0].cost - b.countries[0].cost);
}

/** v2 يضع الرمز جاهزاً في sms[].code فلا حاجة لاستخراجه من النص */
export function pickFiveSimCode(payload: any): string | null {
  const list = payload?.sms;
  if (!Array.isArray(list)) return null;
  for (const item of list) {
    const code = pickStringValue(item, ['code', 'sms_code']);
    if (code) return code;
  }
  return null;
}

/**
 * حالات v2 نصية صريحة: PENDING/RECEIVED ثم CANCELED/BANNED/TIMEOUT/FINISHED.
 * «RECEIVED» بلا رسالة لا يكفي للحكم بوصول الرمز، فيبقى الانتظار حتى الجلب التالي.
 */
export function classifyFiveSimStatus(payload: any): VirtualNumberState {
  if (!payload || typeof payload !== 'object') return 'unknown';
  if (readSmsText(payload)) return 'received';

  const status = String(
    payload.status ?? payload.state ?? payload.statusText ?? '',
  )
    .trim()
    .toUpperCase();
  if (!status) return 'unknown';

  if (status === 'PENDING' || status === 'RECEIVED') return 'waiting';
  // أُغلق لدى المزوّد بلا رمز: لا شيء سُلّم فيُرجع المبلغ
  if (status === 'FINISHED') return 'cancelled';
  if (/CANCEL|BAN|TIMEOUT|EXPIRE|REFUND|NOT.?FOUND|REJECT|ERROR|FAIL/.test(status)) {
    return 'cancelled';
  }
  if (/WAIT|PROGRESS|SENT|PARK|RESEND|AGAIN/.test(status)) return 'waiting';

  // أرقام الحالة في الإصدار القديم: 1 انتظار، 3 رمز، 4 إلغاء، 5 غير موجود
  const numeric = Number(status);
  if (Number.isFinite(numeric)) {
    if (numeric === 1 || numeric === 2) return 'waiting';
    if (numeric === 3 || numeric === 6) return 'received';
    if (numeric >= 4) return 'cancelled';
  }
  return 'unknown';
}

/** طلب v2 كما يعرضه /user/check: الحالة والرسالة والرمز من كائن واحد */
export function readFiveSimOrder(payload: any): {
  state: VirtualNumberState;
  status?: string;
  smsText?: string;
  code?: string;
} {
  const smsText = readSmsText(payload) ?? undefined;
  const code =
    pickFiveSimCode(payload) ??
    (smsText ? extractVerificationCode(smsText) : null) ??
    undefined;

  return {
    state: code ? 'received' : classifyFiveSimStatus(payload),
    status: pickStringValue(payload, ['status', 'state', 'statusText']) ?? undefined,
    smsText,
    code,
  };
}

export class FiveSimClient implements VirtualNumberClient {
  private static readonly CALL_TIMEOUT_MS = 20_000;
  private static readonly STATUS_TIMEOUT_MS = 10_000;
  // /guest/prices يعيد كتالوج المزوّد كاملاً (~9MB) فلا تكفيه مهل قصيرة
  private static readonly CATALOG_TIMEOUT_MS = 120_000;

  private readonly logger = new Logger(FiveSimClient.name);

  constructor(private readonly creds: VirtualNumberCredentials) {}

  private get root(): string {
    return fiveSimApiRoot(this.creds.baseUrl);
  }

  private get authHeaders(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.creds.apiKey}`,
      Accept: 'application/json',
    };
  }

  private config(timeout: number): AxiosRequestConfig {
    return { timeout, headers: this.authHeaders };
  }

  // --- الرصيد والحساب -------------------------------------------------------

  async getProfile(): Promise<VirtualNumberProfile> {
    try {
      const res = await axios.get(
        `${this.root}/user/profile`,
        this.config(FiveSimClient.STATUS_TIMEOUT_MS),
      );
      const data = unwrapPayload(res.data) ?? {};
      return {
        balance: toNumberValue(data.balance),
        rating:
          data.rating !== undefined ? toNumberValue(data.rating) : undefined,
        raw: data,
      };
    } catch (err: any) {
      throw new BadRequestException(
        `تعذر التحقق من حساب مزود الأرقام الوهمية: ${this.errMessage(err)}`,
      );
    }
  }

  // --- كتالوج الخدمات والأسعار --------------------------------------------

  async getCatalog(): Promise<VirtualNumberServiceEntry[]> {
    const [prices, countries] = await Promise.all([
      this.getJson('/guest/prices'),
      // الأسماء تجميلية: غيابها لا يُفشل الكتالوج فيبقى رمز الدولة اسماً
      this.getJson('/guest/countries').catch(() => null),
    ]);

    const entries = normalizeFiveSimCatalog({ prices, countries });
    if (entries.length === 0) {
      throw new BadRequestException('قائمة الخدمات فارغة من المزود');
    }
    return entries;
  }

  private async getJson(
    path: string,
    params?: Record<string, any>,
    timeout = FiveSimClient.CATALOG_TIMEOUT_MS,
  ): Promise<any> {
    try {
      const res = await axios.get(`${this.root}${path}`, {
        ...this.config(timeout),
        params,
      });
      return unwrapPayload(res.data);
    } catch (err: any) {
      throw new BadRequestException(
        `تعذر جلب بيانات مزود الأرقام الوهمية: ${this.errMessage(err)}`,
      );
    }
  }

  // --- طلب رقم -------------------------------------------------------------

  async requestNumber(params: {
    service: string;
    country: string;
    operator?: string;
  }): Promise<VirtualNumberHandle> {
    const operator = (params.operator || 'any').trim() || 'any';
    const path =
      `/user/buy/activation/${encodeURIComponent(params.country)}` +
      `/${encodeURIComponent(operator)}/${encodeURIComponent(params.service)}`;

    let raw: any;
    try {
      const res = await axios.get(
        `${this.root}${path}`,
        this.config(FiveSimClient.CALL_TIMEOUT_MS),
      );
      raw = unwrapPayload(res.data);
    } catch (err: any) {
      throw new VirtualNumberProviderError(
        `تعذر الحصول على رقم من مزود الخدمة: ${this.errMessage(err)}`,
        isTimeoutError(err),
      );
    }

    const number = pickStringValue(raw, [
      'phone',
      'number',
      'full_number',
      'phoneNumber',
    ]);
    const id = pickStringValue(raw, ['id', 'order_id', 'orderId', 'requestId']);

    if (!id || !number) {
      throw new VirtualNumberProviderError(
        pickStringValue(raw, ['error', 'message', 'statusText']) ||
          (raw ? 'لم يعيد المزود رقماً' : 'استجابة فارغة من المزود'),
      );
    }

    return { id, number: digitsOnly(number), raw };
  }

  // --- حالة الطلب ----------------------------------------------------------

  async fetchStatus(id: string): Promise<VirtualNumberStatusResult> {
    let raw: any;
    try {
      const res = await axios.get(
        `${this.root}/user/check/${encodeURIComponent(id)}`,
        this.config(FiveSimClient.STATUS_TIMEOUT_MS),
      );
      raw = unwrapPayload(res.data);
    } catch (err: any) {
      const message = this.errMessage(err);
      // «order not found» يعني أن الطلب لم يعد لدى المزود، والإلغاء هو ما يُرجع المبلغ
      if (/not[ _-]?found/i.test(message)) {
        return { state: 'cancelled', status: 'NOT_FOUND', raw: { message } };
      }
      throw new VirtualNumberProviderError(
        `تعذر فحص حالة الرقم: ${message}`,
        isTimeoutError(err),
      );
    }

    return { ...readFiveSimOrder(raw), raw };
  }

  // --- إنهاء / إلغاء الرقم -------------------------------------------------

  /** يُستدعى بعد وصول الرمز: يُغلق الرقم لدى المزود ولا يُخصم شيء إضافي */
  async markFinished(id: string): Promise<void> {
    await this.callId('/user/finish', id, 'finish');
  }

  /** إلغاء الرقم قبل وصول الرمز كي لا يُحتسب على رصيد المزود */
  async cancelNumber(params: VirtualNumberCancelParams): Promise<void> {
    await this.callId('/user/cancel', params.id, 'cancel');
  }

  /**
   * الإنهاء/الإلغاء لا يرمي خطأ: الرقم قد يكون أُنهي مسبقاً فيرد المزوّد
   * «order not found»، وفشل التنظيف لا يجوز أن يُفشل عملية أتمّها العميل.
   */
  private async callId(path: string, id: string, action: string): Promise<void> {
    try {
      await axios.get(
        `${this.root}${path}/${encodeURIComponent(id)}`,
        this.config(FiveSimClient.CALL_TIMEOUT_MS),
      );
    } catch (err: any) {
      this.logger.warn(
        `5sim ${action} failed for ${id}: ${this.errMessage(err)}`,
      );
    }
  }

  // --- أدوات مساعدة --------------------------------------------------------

  /** أخطاء 5sim نصوص صريحة (order not found / bad country) لا كائنات JSON */
  private errMessage(err: any): string {
    const data = err?.response?.data;
    if (typeof data === 'string' && data.trim() && data.trim().length <= 200) {
      return data.trim();
    }
    return providerErrorMessage(err);
  }
}
