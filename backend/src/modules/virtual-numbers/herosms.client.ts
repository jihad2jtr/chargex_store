import { BadRequestException, Logger } from '@nestjs/common';
import axios from 'axios';
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
  toEntries,
  toNumberValue,
  unwrapPayload,
} from './virtual-number-client';

/**
 * موصل Hero-SMS (أرقام التحقق الوهمية) — بروتوكول متوافق مع SMS-Activate:
 * نقطة واحدة `stubs/handler_api.php` تُستدعى بـ `action` في الـ query مع المفتاح،
 * وترجع JSON عند `json=1` أو نصاً قديماً بصيغة `TOKEN:جزء:بقية`.
 *
 * لذلك يُفكّ الشكلان معاً: القدام (`ACCESS_NUMBER:123:62812...`) والجديد
 * (`{"ids":[123],"phone_number":"62812..."}`). أسماء الأعمال تختلف بين إصدارات
 * التوثيق (addPhoneOrder/getNumber، getNumberStatus/getStatus)، فنجرّب الأشكال
 * بالترتيب. وأرقام الحالة ليست موحّدة، لذا يبقى «وجود نص الرسالة» هو الدليل
 * القاطع على وصول الرمز، وما يُجهل حالته يُترك للانتظار حتى تنتهي المهلة
 * فيرجع المبلغ — وهو المسار الأسلم مالياً من تخمين حالة إلغاء.
 */

export const HEROSMS_DEFAULT_ENDPOINT = 'https://hero-sms.com/stubs/handler_api.php';

/** رموز الغلط التي يعيدها البروتوكول النصي (تُقرأ قبل أي تفسير آخر) */
const ERROR_TOKEN =
  /^(ACCESS_(DENIED|NOT_ALLOWED|INCORRECT)|ERROR|WRONG|INCORRECT|BAD|NO_|BALANCE_IS_|SQL)/;

/** رموز قاطعة: إعادة المحاولة باسم عمل آخر لا فائدة منها */
const FATAL_TOKEN =
  /^(ACCESS_DENIED|ACCESS_NOT_ALLOWED|WRONG|ERROR_INCORRECT|NO_NUMBERS|NO_BALANCE|BALANCE_IS_)/;

export interface HeroSmsReply {
  /** هل الاستجابة نجحت (ليست رمز خطأ) */
  ok: boolean;
  /** الرمز الأول: من النص القديم أو حقل status في JSON */
  token: string;
  /** الجزء التالي بعد الرمز في البروتوكول النصي (غالباً المعرّف) */
  first: string;
  /** بقية النص بعد المعرّف (الرقم أو نص الرسالة) */
  rest: string;
  /** الحمولة المفكّرة إن كانت JSON، أو كائن يحوي status فقط */
  object: any;
  /** الاستجابة جاءت نصاً قديماً: تُقرأ منها first/rest بدل الحقول */
  legacy: boolean;
  message?: string;
}

/** يفك استجابة handler_api سواء كانت JSON أو نصاً قديماً بصيغة TOKEN:جزء:بقية */
export function decodeHeroSmsReply(body: any): HeroSmsReply {
  if (typeof body === 'string') {
    const text = body.trim();
    if (/^[[{]/.test(text)) {
      try {
        return decodeHeroSmsReply(JSON.parse(text));
      } catch {
        /* نص قديم يبدأ بـ { أو [ بلا طائل: يُعامل كنص */
      }
    }

    const cut = text.indexOf(':');
    const token = (cut === -1 ? text : text.slice(0, cut)).trim().toUpperCase();
    const tail = cut === -1 ? '' : text.slice(cut + 1).trim();
    const second = tail.indexOf(':');
    const first = second === -1 ? tail : tail.slice(0, second).trim();
    // بقية النص تُترك كما هي: نص الرسالة قد يحوي علامات :
    const rest = second === -1 ? '' : tail.slice(second + 1).trim();
    const failed = ERROR_TOKEN.test(token);

    return {
      ok: !failed,
      token,
      first,
      rest,
      object: { status: token },
      legacy: true,
      message: failed ? token.replace(/_/g, ' ') : undefined,
    };
  }

  const object = unwrapPayload(body);
  if (!object || typeof object !== 'object') {
    return {
      ok: false,
      token: '',
      first: '',
      rest: '',
      object: null,
      legacy: false,
      message: 'استجابة فارغة من Hero-SMS',
    };
  }

  const token = String(
    object.status ?? object.error ?? object.message ?? '',
  )
    .trim()
    .toUpperCase();
  const failed =
    ERROR_TOKEN.test(token) ||
    (typeof object.error === 'string' && object.error.trim() !== '');

  return {
    ok: !failed,
    token,
    first: '',
    rest: '',
    object,
    legacy: false,
    message: failed
      ? (typeof object.error === 'string' ? object.error : token.replace(/_/g, ' '))
      : undefined,
  };
}

/**
 * أرقام حالة الطلب لدى عائلة SMS-Activate: 4 (و20 للتكرار) تعني نصاً جاهزاً،
 * و8 تعني إلغاء؛ ما عداها انتظار. الحالة المجهولة تُترك للانتظار لا للإلغاء:
 * إن كان الرقم موجوداً فسيأتي رمزه، وإن لم تكن فالمهلة ترجع المال على أي حال.
 */
export function classifyHeroSmsStatus(
  payload: any,
  smsText?: string | null,
): VirtualNumberState {
  if (String(smsText ?? '').trim()) return 'received';

  const raw = String(
    typeof payload === 'string' || typeof payload === 'number'
      ? payload
      : (payload?.status ?? payload?.state ?? ''),
  )
    .trim()
    .toUpperCase();
  if (!raw) return 'unknown';

  if (/CANCEL|EXPIRED|NOT_FOUND|NOTFOUND|DELETE|REJECT|REFUND/.test(raw)) {
    return 'cancelled';
  }
  if (/OK|RECIVE|RECEIVE|RESULT|DELIVERED|TEXT/.test(raw)) return 'received';
  if (/WAIT|PROGRESS|PARK|AGAIN|PENDING|SENT|RESERVE/.test(raw)) {
    return 'waiting';
  }

  const numeric = Number(raw);
  if (Number.isFinite(numeric)) {
    if (numeric === 4 || numeric === 20) return 'received';
    if (numeric === 8) return 'cancelled';
    if ([1, 2, 3, 5, 6, 7, 10, 11].includes(numeric)) return 'waiting';
  }
  return 'unknown';
}

const isCurrencyKeyed = (node: any): boolean =>
  !!node &&
  typeof node === 'object' &&
  !Array.isArray(node) &&
  Object.keys(node).some(
    (key) => /^[A-Z]{3}$/.test(key) && typeof node[key] === 'object',
  );

/** العملة المعتمدة للبيع: USD إن وُجدت وإلا أول عملة في الاستجابة */
function pickCurrencyBlock(root: any): any {
  if (!isCurrencyKeyed(root)) return root;
  const keys = Object.keys(root).filter(
    (key) => /^[A-Z]{3}$/.test(key) && typeof root[key] === 'object',
  );
  return root['USD'] ?? root[keys[0]] ?? {};
}

/** نص → حقل تعريفي: يُستخدم لربط الأسماء بالرموز */
function indexNames(source: any, nameKeys: string[], codeKeys: string[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const entry of toEntries(source)) {
    const value = entry.value && typeof entry.value === 'object' ? entry.value : {};
    const code =
      pickStringValue(value, codeKeys) || entry.key || '';
    const name = pickStringValue(value, nameKeys) || code;
    if (code) map.set(String(code).trim(), name || String(code).trim());
  }
  return map;
}

/**
 * كتالوج Hero-SMS يُعاد بأشكال عدة حسب نقطة النهاية والإصدار:
 *  أ) { USD: { telgr: { '1': { count, price } } } }          (خدمة ← دولة)
 *  ب) { USD: { '1': { telgr: { count, price } } } }          (دولة ← خدمة)
 *  ج) [ { service|code, country|countryId, price, count } ]  (صفوف مسطّحة)
 * الاتجاه يُستنتج من مفاتيح المستوى الثاني: أرقام دول نقية أم رموز خدمات.
 */
export function normalizeHeroSmsCatalog(input: {
  prices: any;
  services?: any;
  countries?: any;
}): VirtualNumberServiceEntry[] {
  const root = unwrapPayload(input.prices);
  const body = pickCurrencyBlock(root);

  const serviceNames = indexNames(input.services, ['name', 'title'], ['code', 'service', 'key', 'id']);
  // أسماء الدول لدى هذا المزود في getCountries بحقل eng لا name، وإلا بقيت الرمز
  const countryNames = indexNames(
    input.countries,
    ['eng', 'name', 'title', 'country_name'],
    ['code', 'id', 'country', 'key'],
  );

  type Row = { cost: number; count?: number; operators: Array<{ code: string; name: string }> };
  const byService = new Map<string, Map<string, Row>>();

  const leafRow = (node: any): Row | null => {
    if (!node || typeof node !== 'object') return null;
    const price = node.price ?? node.cost ?? node.amount;
    if (price === undefined && node.count === undefined) return null;
    const operators = toEntries(node.operators ?? node.ops).map((entry) => ({
      code: String(
        (entry.value && typeof entry.value === 'object'
          ? pickStringValue(entry.value, ['code', 'id', 'name'])
          : entry.value) ?? entry.key,
      ).trim(),
      name: String(
        (entry.value && typeof entry.value === 'object'
          ? pickStringValue(entry.value, ['name', 'code'])
          : entry.value) ?? entry.key,
      ).trim(),
    }));
    return {
      cost: toNumberValue(price),
      count:
        node.count !== undefined || node.num !== undefined
          ? toNumberValue(node.count ?? node.num)
          : undefined,
      operators: operators.filter((op) => op.code && op.name),
    };
  };

  const push = (service: string, country: string, row: Row) => {
    if (!service || !country) return;
    const countries = byService.get(service) ?? new Map<string, Row>();
    // إن تكرّر المفتاح (عملتان أو أكثر) نأخذ الأرخص لأن الأعلى لا يفيدهما
    const previous = countries.get(country);
    if (!previous || row.cost < previous.cost) countries.set(country, row);
    byService.set(service, countries);
  };

  const rows = toEntries(body);
  for (const row of rows) {
    const flat = leafRow(row.value);
    if (flat) {
      // ج) صفوف مسطّحة: السطر نفسه يحمل الخدمة والدولة، ولا صف بغير رمز خدمة
      const service = pickStringValue(row.value, [
        'service',
        'serviceCode',
        'code',
      ]);
      const country = pickStringValue(row.value, [
        'country',
        'countryId',
        'id',
        'key',
      ]);
      if (service && country) {
        push(String(service).trim(), String(country).trim(), flat);
      }
      continue;
    }

    const inner = toEntries(row.value);
    if (inner.length === 0) continue;
    // مفاتيح رقمية نقية = دول، وإلا = رموز خدمات
    const countryFirst = inner.every((entry) => /^\d+$/.test(entry.key));

    for (const entry of inner) {
      const leaf = leafRow(entry.value);
      if (!leaf) continue;
      if (countryFirst) {
        push(row.key, entry.key, leaf);
      } else {
        push(entry.key, row.key, leaf);
      }
    }
  }

  const entries: VirtualNumberServiceEntry[] = [];
  for (const [code, countries] of byService) {
    if (!code || countries.size === 0) continue;
    entries.push({
      code,
      name: serviceNames.get(code) || code,
      countries: [...countries.entries()]
        .map(([countryCode, row]) => ({
          code: countryCode,
          name: countryNames.get(countryCode) || countryCode,
          cost: row.cost,
          count: row.count,
          operators: row.operators,
        }))
        .filter((country) => country.cost > 0)
        .sort((a, b) => a.cost - b.cost),
    });
  }

  return entries.filter((service) => service.countries.length > 0);
}

/** رابط النقطة: يقبل رابط الموقع أو الرابط الكامل بالملف ويشتق الصحيح */
export function heroSmsEndpoint(baseUrl?: string): string {
  const raw = (baseUrl || '').trim().replace(/\/+$/, '');
  if (!raw) return HEROSMS_DEFAULT_ENDPOINT;
  if (/handler_api/i.test(raw)) return raw;

  try {
    const url = new URL(raw.includes('://') ? raw : `https://${raw}`);
    return `${url.origin}/stubs/handler_api.php`;
  } catch {
    return HEROSMS_DEFAULT_ENDPOINT;
  }
}

export class HeroSmsClient implements VirtualNumberClient {
  private static readonly CALL_TIMEOUT_MS = 12_000;
  private static readonly STATUS_TIMEOUT_MS = 8_000;
  private static readonly CATALOG_TIMEOUT_MS = 20_000;

  private readonly logger = new Logger(HeroSmsClient.name);

  constructor(private readonly creds: VirtualNumberCredentials) {}

  private get endpoint(): string {
    return heroSmsEndpoint(this.creds.baseUrl);
  }

  /**
   * المفتاح يُرسل بأشكاله الثلاثة: الإصدارات المختلفة تقرأ api_key أو apikey
   * أو key، وjson=1 يطلب JSON مع بقاء tolerated للنص القديم في المفكّ.
   */
  private params(action: string, extra: Record<string, any> = {}): Record<string, any> {
    return {
      api_key: this.creds.apiKey,
      apikey: this.creds.apiKey,
      key: this.creds.apiKey,
      json: 1,
      lang: 'eng',
      action,
      ...extra,
    };
  }

  /**
   * يجرّب أسماء الأعمال بالترتيب ويعيد أول نجاح. أخطاء الحساب والرصيد قاطعة
   * فتُوقف المحاولة لأن تكرارها على اسم عمل آخر لن يغيّر شيئاً.
   */
  private async call(
    actions: string[],
    extra: Record<string, any> = {},
    timeout = HeroSmsClient.CALL_TIMEOUT_MS,
  ): Promise<HeroSmsReply> {
    let lastError = '';
    let sawTimeout = false;

    for (const action of actions) {
      try {
        const res = await axios.get(this.endpoint, {
          params: this.params(action, extra),
          timeout,
        });
        const reply = decodeHeroSmsReply(res.data);
        if (reply.ok) return reply;

        lastError = reply.message || 'رفض المزود الطلب';
        if (FATAL_TOKEN.test(reply.token)) break;
      } catch (err: any) {
        lastError = providerErrorMessage(err);
        sawTimeout = sawTimeout || isTimeoutError(err);
      }
    }

    throw new VirtualNumberProviderError(
      lastError || 'استجابة غير معروفة من Hero-SMS',
      sawTimeout,
    );
  }

  // --- الرصيد والحساب -------------------------------------------------------

  async getProfile(): Promise<VirtualNumberProfile> {
    let reply: HeroSmsReply;
    try {
      reply = await this.call(
        ['getBalance'],
        {},
        HeroSmsClient.STATUS_TIMEOUT_MS,
      );
    } catch (err: any) {
      throw new BadRequestException(
        `تعذر التحقق من حساب مزود الأرقام الوهمية: ${err?.message || 'استجابة غير معروفة'}`,
      );
    }

    const balance =
      toNumberValue(reply.object?.balance) ||
      (reply.legacy ? toNumberValue(reply.first || reply.token) : 0);

    return { balance, raw: reply.object };
  }

  // --- كتالوج الخدمات والأسعار --------------------------------------------

  /**
   * ثلاث قراءات تُدمج: مصفوفة الأسعار (خدمة × دولة)، ثم أسماء الخدمات وأسماء
   * الدول. فشل الأسماء لا يُفشل الكتالوج: الرمز نفسه يصلح اسماً بديلاً.
   */
  async getCatalog(): Promise<VirtualNumberServiceEntry[]> {
    const prices = await this.call(
      ['getCountriesServiceJson', 'getCountriesServicePrice', 'getPrices'],
      {},
      HeroSmsClient.CATALOG_TIMEOUT_MS,
    ).catch((err: any) => {
      // رسالة المزوّد تُنقل كما هي للإدارة: هي ما يفسّر تعطل الكتالوج
      throw err instanceof VirtualNumberProviderError
        ? new BadRequestException(err.message)
        : err;
    });

    const [services, countries] = await Promise.all([
      this.call(['getServicesJson', 'getServices'], {}, HeroSmsClient.CATALOG_TIMEOUT_MS)
        .then((reply) => reply.object)
        .catch(() => null),
      this.call(['getCountriesJson', 'getCountries'], {}, HeroSmsClient.CATALOG_TIMEOUT_MS)
        .then((reply) => reply.object)
        .catch(() => null),
    ]);

    const entries = normalizeHeroSmsCatalog({
      prices: prices.object,
      services,
      countries,
    });
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
    const extra: Record<string, any> = {
      service: params.service,
      country: params.country,
    };
    if (params.operator && params.operator !== 'any') {
      extra.operator = params.operator;
    }

    const reply = await this.call(
      ['addPhoneOrder', 'getNumber'],
      extra,
      HeroSmsClient.CALL_TIMEOUT_MS,
    ).catch((err: any) => {
      if (err instanceof VirtualNumberProviderError) throw err;
      throw new VirtualNumberProviderError(
        `تعذر الحصول على رقم من مزود الخدمة: ${err?.message || 'استجابة غير معروفة'}`,
        isTimeoutError(err),
      );
    });

    const object = reply.object ?? {};
    const ids = Array.isArray(object.ids) ? object.ids : undefined;
    const id =
      pickStringValue(object, ['id', 'orderId', 'idOrder', 'requestId']) ||
      String(ids?.[0] ?? '') ||
      (reply.legacy ? reply.first : '');
    const number =
      pickStringValue(object, [
        'phone_number',
        'phoneNumber',
        'number',
        'phone',
        'full_number',
      ]) || (reply.legacy && /^ACCESS_NUMBER/.test(reply.token) ? reply.rest : '');

    if (!id || !number) {
      throw new VirtualNumberProviderError(
        `تعذر الحصول على رقم من مزود الخدمة: ${reply.message || reply.token || 'لم يعيد المزود رقماً'}`,
      );
    }

    return { id: String(id).trim(), number: digitsOnly(String(number)), raw: object };
  }

  // --- حالة الطلب ----------------------------------------------------------

  async fetchStatus(id: string): Promise<VirtualNumberStatusResult> {
    const reply = await this.call(
      ['getNumberStatus', 'getStatus'],
      { id },
      HeroSmsClient.STATUS_TIMEOUT_MS,
    );

    // النص لا يُقرأ من rest إلا حين يكون الرمز دالاً عليه (لا على رقم مُعطى)
    let smsText = reply.legacy
      ? (/OK|RECIVE|RECEIVE|RESULT|TEXT/.test(reply.token) ? reply.rest || null : null)
      : readSmsText(reply.object);
    let state = classifyHeroSmsStatus(reply.object, smsText);

    // الأشكال التي لا تحمل النص في الحالة: تُجلب التفاصيل كاملة
    if (!smsText) {
      const info = await this.fetchFullInfo(id).catch(() => null);
      if (info) {
        smsText = readSmsText(info);
        const reclassified = classifyHeroSmsStatus(info, smsText);
        if (reclassified !== 'unknown') state = reclassified;
      }
    }

    const code = smsText ? extractVerificationCode(smsText) : undefined;
    // «وصل الرمز» بلا رمز ملموس تُترك للانتظار: المسار الأسلم مالياً للعميل والمزود
    if (state === 'received' && !code) state = 'waiting';

    return {
      state,
      status: pickStringValue(reply.object, ['status', 'state']) ?? reply.token ?? undefined,
      smsText: smsText ?? undefined,
      code: code ?? undefined,
      raw: reply.object,
    };
  }

  private async fetchFullInfo(id: string): Promise<any | null> {
    for (const action of ['getFullNumberInfo', 'getFullInfo']) {
      const reply = await this.call(
        [action],
        { id },
        HeroSmsClient.STATUS_TIMEOUT_MS,
      ).catch(() => null);
      if (reply?.object) return reply.object;
    }
    return null;
  }

  // --- إنهاء / إلغاء الرقم -------------------------------------------------

  /** يُستدعى بعد وصول الرمز: 6 = الرقم اكتمل لدى المزود */
  async markFinished(id: string): Promise<void> {
    await this.call(
      ['setStatus'],
      { id, status: 6 },
      HeroSmsClient.CALL_TIMEOUT_MS,
    ).catch((err: any) => {
      // الفشل هنا لا يُرجع مالاً: الرمز وصل والخدمة سُلّمت، والمصادقة تحصيل حاصل
      this.logger.warn(`Hero-SMS setStatus(6) failed for ${id}: ${err?.message}`);
    });
  }

  /** إلغاء الرقم قبل وصول الرمز (8 = ملغى) حتى لا يُحتسب على الحساب */
  async cancelNumber(params: VirtualNumberCancelParams): Promise<void> {
    const cancelled = await this.call(
      ['setStatus'],
      { id: params.id, status: 8 },
      HeroSmsClient.CALL_TIMEOUT_MS,
    ).catch(() => null);
    if (cancelled && /CANCEL|OK/.test(cancelled.token)) return;

    for (const action of ['cancelActivation', 'cancelOrder', 'setCanceled']) {
      const reply = await this.call(
        [action],
        { id: params.id },
        HeroSmsClient.CALL_TIMEOUT_MS,
      ).catch((err: any) => {
        this.logger.warn(`Hero-SMS ${action} failed: ${err?.message}`);
        return null;
      });
      if (reply && /CANCEL|OK/.test(reply.token)) return;
    }
  }
}
