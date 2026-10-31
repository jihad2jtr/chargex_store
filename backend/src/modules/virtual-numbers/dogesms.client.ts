/**
 * موصال DogeSMS (أرقام التحقق الوهمية) على واجهة REST v1.
 *
 *   GET  /v1/balance                       → { data: { balance_cents, currency } }
 *   GET  /v1/catalog/services              → [ { code, name } ]
 *   GET  /v1/catalog/countries             → [ { code, name, phone_prefix, service_count } ]
 *   GET  /v1/catalog/channels?country_code=→ [ { service_code, channel_id, price_cents,
 *                                                 tier, available_count, quality, rank } ]
 *   POST /v1/orders            (X-Idempotency-Key) → 201 { data: { id, status: 'pending' } }
 *   GET  /v1/orders/:id                    (استطلاع الحالة)
 *   POST /v1/orders/:id/cancel
 *
 * الفرق الجوهري عن 5sim و Hero-SMS: الشراء لا يعيد الرقم. الطلب يولد بحالة
 * `pending` ثم يصبح `active` حين يُخصَّص الرقم (`phone_number`)، ثم `completed`
 * حين تصل الرسالة (`sms_code`). الخدمة هنا تتوقع رقماً في نفس اللحظة التي يُخصم
 * فيها مبلغ العميل، لذلك يستطلع هذا الموصّل حالة الطلب حتى يرى الرقم، وإن نفد
 * صبره يرمي خطأ isTimeout فيبقى الطلب معلّقاً يحسمه المسح لاحقاً — وهو المسار
 * الذي يمنع خصم مال بلا رقم أو إرجاع مال لرقمٍ سُلّم.
 *
 * كل المبالغ بالسنت (integer) فتُقسم على 100. ولأن رموز الخدمات والدول هنا نصية
 * إنجليزية (`whatsapp`, `US`) يشتق المعجم أسماءها العربية بلا خطر تصادم.
 */

import { BadRequestException, Logger } from '@nestjs/common';
import axios from 'axios';
import { randomUUID } from 'crypto';
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
  centsToUnit,
  digitsOnly,
  extractVerificationCode,
  isTimeoutError,
  pickStringValue,
  providerErrorMessage,
  toNumberValue,
  unwrapPayload,
} from './virtual-number-client';
import {
  resolveAppMeta,
  resolveCountryMeta,
} from './virtual-numbers-dictionary';

export const DOGESMS_DEFAULT_BASE = 'https://api.dogesms.com';

/** مهلة انتظار تخصيص الرقم داخل طلب الشراء: بعدها يُترك الطلب للمتابعة */
const ALLOCATE_WAIT_MS = 25_000;
const ALLOCATE_POLL_MS = 1_500;

/**
 * جذر API: يقبل رابط الموقع أو المضيف أو …/v1 ويعيد دائماً https://<host>/v1،
 * كما يفعل موصال 5sim كي لا يكسر السجل المحفوظ بأي صيغة.
 */
export function dogeSmsApiRoot(baseUrl?: string): string {
  let raw = (baseUrl || '').trim();
  if (!raw) return DOGESMS_DEFAULT_BASE;
  if (!/^https?:\/\//i.test(raw)) raw = `https://${raw}`;

  try {
    const url = new URL(raw);
    const path = url.pathname
      .replace(/\/+$/, '')
      .replace(/\/v\d+(\/.*)?$/i, '$1');
    return `${url.origin}${path}/v1`;
  } catch {
    return DOGESMS_DEFAULT_BASE;
  }
}

/** الحالات التي لا تأتي بعدها أبداً: لا رقم ولا رسالة ولا رجاء في الانتظار */
const TERMINAL_STATUSES = /^(FAILED|EXPIRED|CANCELLED|CANCELED)$/i;

/**
 * كتالوج DogeSMS يُبنى من ثلاث قراءات: الخدمات، الدول، ثم قنوات كل دولة
 * (القناة أرخص وحدة شراء مباشرة وتحمل المخزون والجودة). تُجمَّع القنوات إلى
 * دولة ← خدمة، ويصبح سعر الدولة أرخص قناة تملك مخزوناً (وإلا أرخص قناة على
 * الإطلاق)، وتبقى المعرّفات الصالحة للترتيب في قائمة «المشغّلين».
 */
export function normalizeDogeSmsCatalog(input: {
  services: any;
  countries: any;
  channelsByCountry: Array<{ countryCode: string; rows: any }> | any;
}): VirtualNumberServiceEntry[] {
  const services = Array.isArray(unwrapPayload(input.services))
    ? (unwrapPayload(input.services) as any[])
    : [];
  const countries = Array.isArray(unwrapPayload(input.countries))
    ? (unwrapPayload(input.countries) as any[])
    : [];
  const countryNames = new Map<string, string>();
  for (const country of countries) {
    const code = pickStringValue(country, ['code']);
    if (code) countryNames.set(code.toLowerCase(), String(country.name ?? code));
  }

  interface ChannelRow {
    code: string;
    name: string;
    cost: number;
    count: number;
  }
  interface CountryRow {
    code: string;
    name: string;
    channels: ChannelRow[];
  }
  const byService = new Map<string, Map<string, CountryRow>>();

  const grouped = Array.isArray(input.channelsByCountry)
    ? (input.channelsByCountry as Array<{ countryCode: string; rows: any }>)
    : [];

  for (const { countryCode, rows } of grouped) {
    const list = Array.isArray(unwrapPayload(rows))
      ? (unwrapPayload(rows) as any[])
      : [];
    if (!countryCode || list.length === 0) continue;

    for (const row of list) {
      const serviceCode = pickStringValue(row, ['service_code', 'serviceCode']);
      const channelId = pickStringValue(row, ['channel_id', 'channelId']);
      const cost = centsToUnit(row?.price_cents ?? row?.price);
      if (!serviceCode || !channelId || cost <= 0) continue;

      const countriesOfService = byService.get(serviceCode) ?? new Map<string, CountryRow>();
      byService.set(serviceCode, countriesOfService);
      const countryRow = countriesOfService.get(countryCode) ?? {
        code: countryCode,
        name:
          countryNames.get(countryCode.toLowerCase()) ||
          pickStringValue(row, ['country_name', 'countryName']) ||
          countryCode,
        channels: [],
      };
      countriesOfService.set(countryCode, countryRow);

      const quality = pickStringValue(row, ['quality']);
      const count = toNumberValue(row?.available_count ?? row?.availableCount);
      countryRow.channels.push({
        code: channelId,
        // الجودة والرتبة تُبقي القناة المقترحة مفهومة للإدارة وللعميل
        name: [quality, pickStringValue(row, ['rank']) ? `#${pickStringValue(row, ['rank'])}` : null]
          .filter(Boolean)
          .join(' ')
          .trim() || channelId,
        cost,
        count,
      });
    }
  }

  const entries: VirtualNumberServiceEntry[] = [];
  for (const [serviceCode, countriesOfService] of byService) {
    const appMeta = resolveAppMeta(serviceCode, 'dogesms');
    const serviceName =
      services.find((s) => pickStringValue(s, ['code']) === serviceCode)?.name ||
      appMeta.nameEn ||
      serviceCode;

    const rows = [...countriesOfService.values()]
      .map((country) => {
        const stocked = country.channels.filter((channel) => channel.count > 0);
        const pool = stocked.length > 0 ? stocked : country.channels;
        const cheapest = pool.reduce((best, ch) => (ch.cost < best.cost ? ch : best));
        const cMeta = resolveCountryMeta(country.code, 'dogesms');
        return {
          code: country.code,
          name: country.name || cMeta.nameAr || cMeta.nameEn || country.code,
          nameAr: cMeta.nameAr,
          nameEn: cMeta.nameEn,
          flag: cMeta.flag,
          iso: cMeta.iso,
          cost: cheapest.cost,
          count: country.channels.reduce((sum, ch) => sum + ch.count, 0),
          operators: pool
            .slice()
            .sort((a, b) => a.cost - b.cost)
            .map((channel) => ({ code: channel.code, name: channel.name })),
        };
      })
      .filter((country) => country.cost > 0)
      .sort((a, b) => a.cost - b.cost);

    if (rows.length > 0) {
      entries.push({
        code: serviceCode,
        name: serviceName || appMeta.name,
        nameAr: appMeta.nameAr,
        nameEn: serviceName || appMeta.nameEn,
        icon: appMeta.icon,
        herosmsCode: appMeta.herosmsCode,
        fivesimCode: appMeta.fivesimCode,
        countries: rows,
      });
    }
  }

  return entries.sort((a, b) => a.countries[0].cost - b.countries[0].cost);
}

/**
 * حالة طلب DogeSMS: `completed` مع رمز تعني وصول الرسالة، و`active` تعني أن
 * الرقم جاهز وما زال انتظار الرمز مستمراً، والحالات النهائية الثلاث (failed /
 * expired / cancelled) تعني إلغاءً يُرجع المبلغ — المزود لا يحتبس مالاً على
 * طلب فاشل. رسالة `completed` بلا رمز تُترك للانتظار: لا شيء يُعرض للعميل بعد.
 */
export function classifyDogeSmsOrder(payload: any): {
  state: VirtualNumberState;
  code?: string;
  smsText?: string;
} {
  if (!payload || typeof payload !== 'object') return { state: 'unknown' };

  const status = String(payload.status ?? payload.state ?? '')
    .trim()
    .toLowerCase();

  const smsText =
    pickStringValue(payload, ['sms_content', 'smsContent', 'sms', 'message']) ??
    undefined;
  const code =
    pickStringValue(payload, ['sms_code', 'smsCode']) ??
    (smsText ? extractVerificationCode(smsText) : null) ??
    undefined;

  if (code) return { state: 'received', code, smsText };
  if (status === 'completed') return { state: 'received', smsText };
  if (TERMINAL_STATUSES.test(status)) return { state: 'cancelled', smsText };
  if (status === 'active' || status === 'pending' || status === 'reserving') {
    return { state: 'waiting', smsText };
  }
  return { state: 'unknown', smsText };
}

/** رقم الطلب: الحقل الأساسي phone_number، وأشكال أخرى تحسّباً لتغيّر الواجهة */
export function pickDogeSmsNumber(payload: any): string | null {
  return pickStringValue(payload, [
    'phone_number',
    'phoneNumber',
    'number',
    'msisdn',
  ]);
}

/** رسالة خطأ المزود: كائن { code, message } أو نص axios */
function dogeSmsErrorText(err: any): string {
  const data = err?.response?.data;
  const fromBody =
    data && typeof data === 'object'
      ? pickStringValue(data, ['message', 'error', 'error_description']) ||
        pickStringValue((data as any).error ?? {}, ['code', 'message'])
      : typeof data === 'string'
        ? data.trim().slice(0, 200)
        : null;
  const status = err?.response?.status;
  const base = fromBody || providerErrorMessage(err);
  return status ? `${base} (${status})` : base;
}

export class DogeSmsClient implements VirtualNumberClient {
  private static readonly CALL_TIMEOUT_MS = 20_000;
  private static readonly STATUS_TIMEOUT_MS = 10_000;
  private static readonly CATALOG_TIMEOUT_MS = 30_000;

  private readonly logger = new Logger(DogeSmsClient.name);

  constructor(private readonly creds: VirtualNumberCredentials) {}

  private get root(): string {
    return dogeSmsApiRoot(this.creds.baseUrl);
  }

  private config(
    timeout: number,
    extraHeaders: Record<string, string> = {},
  ): Record<string, any> {
    return {
      timeout,
      headers: {
        Authorization: `Bearer ${this.creds.apiKey}`,
        Accept: 'application/json',
        ...extraHeaders,
      },
    };
  }

  private async getJson(path: string, params?: Record<string, any>, timeout = DogeSmsClient.CATALOG_TIMEOUT_MS): Promise<any> {
    try {
      const res = await axios.get(`${this.root}${path}`, {
        ...this.config(timeout),
        params,
      });
      return res.data;
    } catch (err: any) {
      throw new BadRequestException(`تعذر جلب بيانات مزود الأرقام الوهمية: ${dogeSmsErrorText(err)}`);
    }
  }

  // --- الرصيد والحساب -------------------------------------------------------

  async getProfile(): Promise<VirtualNumberProfile> {
    let data: any;
    try {
      const res = await axios.get(`${this.root}/balance`, this.config(DogeSmsClient.STATUS_TIMEOUT_MS));
      data = res.data;
    } catch (err: any) {
      throw new BadRequestException(
        `تعذر التحقق من حساب مزود الأرقام الوهمية: ${dogeSmsErrorText(err)}`,
      );
    }

    const body = unwrapPayload(data) ?? {};
    return {
      // الرصيد بالسنت: يُخزَّن بالدولار كما تفعل اللوحة مع بقية المزودين
      balance: centsToUnit(body.balance_cents ?? body.balance),
      raw: body,
    };
  }

  // --- كتالوج الخدمات والأسعار --------------------------------------------

  /**
   * الدول تُقرأ منها الأسماء والمرجعيات، ثم قناة واحدة لكل دولة: القنوات تحمل
   * السعر والمخزون لكل خدمة في طلب واحد، فعدد الطلبات = عدد الدول.
   */
  async getCatalog(): Promise<VirtualNumberServiceEntry[]> {
    const [services, countries] = await Promise.all([
      this.getJson('/catalog/services'),
      this.getJson('/catalog/countries'),
    ]);

    const countryList = (Array.isArray(unwrapPayload(countries)) ? unwrapPayload(countries) : []) as any[];
    const codes = countryList
      .map((country) => pickStringValue(country, ['code']))
      .filter((code): code is string => Boolean(code));

    if (codes.length === 0) {
      throw new BadRequestException('قائمة الخدمات فارغة من المزود');
    }

    const channelsByCountry: Array<{ countryCode: string; rows: any }> = [];
    // تجميل الطلبات: الدول عشرات ومهلة المزود لا تحتمل عشرات الآلاف منها
    const CONCURRENCY = 6;
    for (let index = 0; index < codes.length; index += CONCURRENCY) {
      const slice = codes.slice(index, index + CONCURRENCY);
      const settled = await Promise.allSettled(
        slice.map(async (code) => ({
          countryCode: code,
          rows: await this.getChannelsForCountry(code),
        })),
      );
      for (const item of settled) {
        if (item.status === 'fulfilled') channelsByCountry.push(item.value);
      }
    }

    const entries = normalizeDogeSmsCatalog({ services, countries, channelsByCountry });
    if (entries.length === 0) {
      throw new BadRequestException('قائمة الخدمات فارغة من المزود');
    }
    return entries;
  }

  /** قنوات دولة: fallback إلى جدول أسعار الدولة إن خابت قراءة القنوات */
  private async getChannelsForCountry(countryCode: string): Promise<any> {
    const channels = await axios
      .get(`${this.root}/catalog/channels`, {
        ...this.config(DogeSmsClient.CATALOG_TIMEOUT_MS),
        params: { country_code: countryCode },
      })
      .then((res) => res.data)
      .catch(() => null);

    if (Array.isArray(unwrapPayload(channels)) && unwrapPayload(channels).length > 0) {
      return channels;
    }

    return this.getJson('/catalog/prices', { country_code: countryCode }).catch(() => null);
  }

  // --- طلب رقم -------------------------------------------------------------

  async requestNumber(params: {
    service: string;
    country: string;
    operator?: string;
  }): Promise<VirtualNumberHandle> {
    const operator = (params.operator || '').trim();
    const body: Record<string, any> = {
      service_code: params.service,
      country_code: params.country,
    };
    // قناة محددة من الكتالوج: سعرها مثبّت وتوفّره أضمن من ترك المزود يختار
    if (operator && operator !== 'any') body.channel_id = operator;

    let created: any;
    try {
      const res = await axios.post(`${this.root}/orders`, body, {
        timeout: DogeSmsClient.CALL_TIMEOUT_MS,
        headers: {
          Authorization: `Bearer ${this.creds.apiKey}`,
          Accept: 'application/json',
          'Content-Type': 'application/json',
          // مفتاح التكرار: إعادة المحاولة بعد انقطاع لا تولّد طلباً ثانياً بمبلغ ثانٍ
          'X-Idempotency-Key': randomUUID(),
        },
      });
      created = unwrapPayload(res.data) ?? {};
    } catch (err: any) {
      throw new VirtualNumberProviderError(
        `تعذر الحصول على رقم من مزود الخدمة: ${dogeSmsErrorText(err)}`,
        isTimeoutError(err),
        err?.response?.status,
      );
    }

    const id = pickStringValue(created, ['id', 'order_id', 'orderId', 'uuid']);
    if (!id) {
      throw new VirtualNumberProviderError('لم يعيد المزود معرّف الطلب');
    }

    // الرقم قد يكون في الرد مباشرة (بعض الحسابات تعرض الحالة النهائية فوراً)
    let number = pickDogeSmsNumber(created);
    if (!number) {
      number = await this.awaitNumber(id);
    }
    if (!number) {
      // لم يُخصَّس الرقم بعد: الطلب قائم لدى المزود، والمهلة هي ما يُبقي حق العميل محفوظاً
      throw new VirtualNumberProviderError(
        'جارٍ تجهيز الرقم لدى مزود الخدمة',
        true,
      );
    }

    return { id, number: digitsOnly(number), raw: created };
  }

  /**
   * استطلاع قصير حتى يظهر الرقم. الخطأ القاطع (حظر الاستطلاع أو فشل الطلب)
   * يُلغي الطلب لدى المزود كي لا يُحتبس الرصيد، وانتهاء المهلة يتركه حيّاً.
   */
  private async awaitNumber(orderId: string): Promise<string | null> {
    const deadline = Date.now() + ALLOCATE_WAIT_MS;

    while (Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, ALLOCATE_POLL_MS));

      let order: any;
      try {
        const res = await axios.get(
          `${this.root}/orders/${encodeURIComponent(orderId)}`,
          this.config(DogeSmsClient.STATUS_TIMEOUT_MS),
        );
        order = unwrapPayload(res.data) ?? {};
      } catch (err: any) {
        if (isTimeoutError(err)) continue;
        const status = err?.response?.status;
        // 404: الطلب غير قابل للقراءة بالاستطلاع (مفعّل عبر webhook فقط) أو زال
        if (status === 404 || status === 403) {
          await this.cancelQuietly(orderId, 'polling-unavailable');
          throw new VirtualNumberProviderError(
            `لا يمكن قراءة حالة الطلب لدى المزود (${status})، فعّل استطلاع حالة الطلبات أو استخدم الويب هوك`,
            false,
            status,
          );
        }
        if (status === 429) continue;
        throw new VirtualNumberProviderError(
          `تعذر الحصول على رقم من مزود الخدمة: ${dogeSmsErrorText(err)}`,
          false,
          status,
        );
      }

      const found = pickDogeSmsNumber(order);
      if (found) return found;

      const status = String(order?.status ?? '')
        .trim()
        .toLowerCase();
      if (TERMINAL_STATUSES.test(status)) {
        throw new VirtualNumberProviderError(
          `تعذّر تجهيز الرقم لدى المزود (${order?.error_code || status})`,
          false,
        );
      }
    }
    return null;
  }

  // --- حالة الطلب ----------------------------------------------------------

  async fetchStatus(id: string): Promise<VirtualNumberStatusResult> {
    let raw: any;
    try {
      const res = await axios.get(
        `${this.root}/orders/${encodeURIComponent(id)}`,
        this.config(DogeSmsClient.STATUS_TIMEOUT_MS),
      );
      raw = unwrapPayload(res.data) ?? {};
    } catch (err: any) {
      const message = dogeSmsErrorText(err);
      // الطلب لم يعد لدى المزود: لا رقم ولا رسالة فيُرجع المبلغ
      if (err?.response?.status === 404 || /not[ _-]?found/i.test(message)) {
        return { state: 'cancelled', status: 'NOT_FOUND', raw: { message } };
      }
      throw new VirtualNumberProviderError(
        `تعذر فحص حالة الرقم: ${message}`,
        isTimeoutError(err),
        err?.response?.status,
      );
    }

    const read = classifyDogeSmsOrder(raw);
    return {
      state: read.state,
      status: pickStringValue(raw, ['status', 'state']) ?? undefined,
      smsText: read.smsText,
      code: read.code,
      raw,
    };
  }

  // --- إنهاء / إلغاء الرقم -------------------------------------------------

  /**
   * لا عملية «إنهاء» لدى DogeSMS: وصول الرسالة يُغلق الطلب تلقائياً، وأي محاولة
   * أخرى للاستنزاف ستخصم أو تُخطئ، فيُترك الرقم كما هو.
   */
  async markFinished(id: string): Promise<void> {
    this.logger.debug(`DogeSMS has no finish operation (order ${id})`);
  }

  /** إلغاء الطلب قبل وصول الرسالة: يُطلق الرقم المحجوز ويعيد المبلغ لدى المزود */
  async cancelNumber(params: VirtualNumberCancelParams): Promise<void> {
    await this.cancelQuietly(params.id, 'cancel');
  }

  private async cancelQuietly(orderId: string, reason: string): Promise<void> {
    try {
      await axios.post(
        `${this.root}/orders/${encodeURIComponent(orderId)}/cancel`,
        {},
        this.config(DogeSmsClient.CALL_TIMEOUT_MS),
      );
    } catch (err: any) {
      // 409/422: الطلب نهائي أو في فترة منع الإلغاء — لا شيء يُنقذ غير الانتظار
      this.logger.warn(
        `DogeSMS cancel failed for ${orderId} (${reason}): ${dogeSmsErrorText(err)}`,
      );
    }
  }
}
