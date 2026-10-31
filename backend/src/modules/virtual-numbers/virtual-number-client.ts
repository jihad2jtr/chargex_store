/**
 * عقد موحّد لموصّلات الأرقام الوهمية.
 *
 * كل مزوّد (5sim، Hero-SMS) يعرض العمليات نفسها — كتالوج، طلب رقم، فحص حالة،
 * إنهاء، إلغاء — لكن ببروتوكولات وأسماء حقول مختلفة. الخدمة لا تعرف إلا هذا
 * العقد، وتحصل على الموصّل المناسب من المصنع حسب نوع المزود.
 *
 * الدوال أدناه عامة (لا تخص مزوداً بعينه) فتُشترك بين الموصّلات بدل تكرارها.
 */

export interface VirtualNumberCredentials {
  baseUrl: string;
  apiKey: string;
}

/**
 * خطأ مزود الأرقام: يحمل علامة isTimeout كي يميّز المستهلك بين فشل قاطع
 * (يُرجع المبلغ فوراً) وانقطاع مهلة (قد يكون الرقم طُلب فعلاً فيُعلَّق للمتابعة).
 */
export class VirtualNumberProviderError extends Error {
  constructor(
    message: string,
    readonly isTimeout = false,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'VirtualNumberProviderError';
  }
}

export interface VirtualNumberProfile {
  balance: number;
  rating?: number;
  raw: any;
}

export interface VirtualNumberHandle {
  id: string;
  number: string; // بصيغة دولية قابلة للضغط: 62812xxxx (بلا +)
  raw: any;
}

export type VirtualNumberState = 'waiting' | 'received' | 'cancelled' | 'unknown';

export interface VirtualNumberStatusResult {
  state: VirtualNumberState;
  status?: string;
  smsText?: string;
  code?: string;
  raw: any;
}

export interface VirtualNumberCancelParams {
  id: string;
  service: string;
  country: string;
  operator?: string;
}

export interface VirtualNumberServiceEntry {
  code: string;
  name: string;
  nameAr?: string;
  nameEn?: string;
  icon?: string;
  herosmsCode?: string;
  fivesimCode?: string;
  smspoolCode?: string;
  countries: Array<{
    code: string;
    name: string;
    nameAr?: string;
    nameEn?: string;
    flag?: string;
    iso?: string;
    cost: number;
    count?: number;
    operators: Array<{ code: string; name: string }>;
  }>;
}

export interface VirtualNumberClient {
  getProfile(): Promise<VirtualNumberProfile>;
  getCatalog(): Promise<VirtualNumberServiceEntry[]>;
  requestNumber(params: {
    service: string;
    country: string;
    operator?: string;
  }): Promise<VirtualNumberHandle>;
  fetchStatus(id: string): Promise<VirtualNumberStatusResult>;
  markFinished(id: string): Promise<void>;
  cancelNumber(params: VirtualNumberCancelParams): Promise<void>;
}

// ---------------------------------------------------------------------------
// أدوات تحليل مشتركة
// ---------------------------------------------------------------------------

export function toNumberValue(value: any): number {
  const n = typeof value === 'number' ? value : parseFloat(String(value ?? ''));
  return Number.isFinite(n) ? n : 0;
}

/** أول حقل نصي (أو رقمي قابل للتحويل) من قائمة مفاتيح */
export function pickStringValue(payload: any, keys: string[]): string | null {
  if (!payload || typeof payload !== 'object') return null;
  for (const key of keys) {
    const value = payload[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
    if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  }
  return null;
}

export function digitsOnly(value: string): string {
  return (value || '').replace(/[^\d]/g, '');
}

/** نص الرسالة قد يكون في text/sms/message أو داخل مصفوفة sms */
export function readSmsText(payload: any): string | null {
  if (!payload || typeof payload !== 'object') return null;

  const direct = pickStringValue(payload, [
    'smsText',
    'text',
    'message',
    'sms',
    'msg',
  ]);
  if (direct && direct.trim()) return direct.trim();

  const list = payload.sms ?? payload.texts ?? payload.messages;
  if (Array.isArray(list) && list.length > 0) {
    const first = list[0];
    if (typeof first === 'string') return first.trim() || null;
    const fromItem = pickStringValue(first, ['text', 'sms', 'message', 'code']);
    if (fromItem && fromItem.trim()) return fromItem.trim();
  }
  return null;
}

/** يستخرج رمز التحقق: سلسلة أرقام 3–10 متصلة، مع تفضيل الأشكال «code: 1234» */
export function extractVerificationCode(text: string): string | null {
  const value = (text || '').trim();
  if (!value) return null;

  const labelled = value.match(
    /(?:code|pin|otp|رمز|الكود|كود)[^\d]{0,12}(\d{3,10})/i,
  );
  if (labelled) return labelled[1];

  const runs = value.match(/\d{3,10}/g);
  if (!runs || runs.length === 0) return null;
  // الرمز عادة أطول مجموعة أرقام متصلة في الرسالة
  return runs.reduce(
    (longest, run) => (run.length > longest.length ? run : longest),
    '',
  );
}

export function isTimeoutError(err: any): boolean {
  const code = err?.code || '';
  return (
    code === 'ECONNABORTED' ||
    code === 'ETIMEDOUT' ||
    code === 'ERR_CANCELED' ||
    /timeout/i.test(err?.message || '')
  );
}

/** رسالة خطأ قابلة للقراءة من استجابة axios أو خطأ عادي */
export function providerErrorMessage(err: any): string {
  return (
    err?.response?.data?.message ||
    err?.response?.data?.error ||
    err?.response?.data?.statusText ||
    err?.message ||
    'خطأ غير معروف'
  );
}

/** الأشكال المكدّسة: بعض المزودين يغلّفون الحمولة داخل data */
export function unwrapPayload(data: any): any {
  if (
    data &&
    typeof data === 'object' &&
    'data' in data &&
    !('balance' in data) &&
    !('number' in data)
  ) {
    return (data as any).data;
  }
  return data;
}

/** كائن مفهرس (id → قيمة) أو مصفوفة: يُعاد دائماً كقائمة مع مفتاحها */
export function toEntries(source: any): Array<{ key: string; value: any }> {
  if (!source) return [];
  if (Array.isArray(source)) {
    return source.map((value, index) => ({
      key: String(
        pickStringValue(value, ['id', 'code', 'key']) ?? index,
      ).trim(),
      value,
    }));
  }
  if (typeof source !== 'object') return [];
  return Object.entries(source).map(([key, value]) => ({ key, value }));
}

/** مقارنة الأسماء على طريقة المعجم: حروف وأرقام فقط، بلا مسافات ولا علامات */
function sameProviderName(left: string, right: string): boolean {
  const cut = (value: string): string =>
    (value || '').toLowerCase().replace(/[^a-z0-9\u0600-\u06ff]/g, '');
  const a = cut(left);
  const b = cut(right);
  return a.length > 1 && b.length > 1 && a === b;
}

/**
 * المعجم يربط رمز الدولة/الخدمة بصفّه عندما يكون الرمز نصاً دالاً (رموز
 * Hero-SMS و 5sim). أما المزودون الذين يرمّزون دولهم وخدماتهم بأرقام صريحة
 * (SMSPool مثلاً: 1 = الولايات المتحدة) فارقامهم تتصادم مع أكواد مزود آخر
 * داخل نفس المعجم، فيعود الاسم الخطأ. لذا لا يُقبل اسم المعجم إلا حين يؤكده
 * الاسم الذي أرسله المزود نفسه، وإلا بقي تسمية المزود وحدها.
 */
export function trustDictionaryName(
  providerName: string,
  resolve: () => { nameAr: string; nameEn: string },
): { nameAr: string; nameEn: string } {
  const wanted = (providerName || '').trim();
  if (!wanted) return { nameAr: '', nameEn: '' };
  const meta = resolve();
  if (
    sameProviderName(wanted, meta.nameEn) ||
    sameProviderName(wanted, meta.nameAr)
  ) {
    return { nameAr: meta.nameAr, nameEn: meta.nameEn };
  }
  return { nameAr: wanted, nameEn: wanted };
}

/** سنتات الدولار ← دولار (واجهة DogeSMS تعرض مبالغها بالسنت) */
export function centsToUnit(cents: any): number {
  return toNumberValue(cents) / 100;
}
