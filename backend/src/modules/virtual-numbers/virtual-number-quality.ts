import {
  VirtualNumberOutcome,
  VirtualNumberOutcomeSource,
} from '../../database/schemas/virtual-number-quality-event.schema';
import { VirtualNumberStatus } from '../../database/schemas/virtual-number-request.schema';

/**
 * تصنيف نتيجة طلب رقم وهمي إلى حالة جودة واحدة، وهل تُحتسب في نسبة وصول الأكواد.
 *
 * الوحدة هنا مصدر وحيد للحقيقة: تستعملها الخدمة والمسح الدوري والويب هوك، فيتفق
 * الجميع على أن انقطاع الاتصال ونفاد المخزون وإلغاء العميل ليسا دليلاً على أن
 * المزود لم يوصِل الرمز. دالة نقية: لا تمسّ قاعدة بيانات ولا حالة.
 */

// عتبة الفشل المتتالي المؤكد التي تُوقف المنتج تلقائياً
export const DEFAULT_FAIL_THRESHOLD = 3;

/**
 * أنماط رسائل المزود التي تعني «لا يوجد مخزون/الخدمة غير متاحة الآن» — نفاد مخزون
 * لا فشل توصيل، فتُسجَّل في السجل ولا تُقرَّب من عتبة الإيقاف التلقائي.
 */
const OUT_OF_STOCK_PATTERN =
  /NO_NUMBERS|NO_INVENTORY|OUT_OF_STOCK|SERVICE_NOT_AVAILABLE|PRICE_NOT_FOUND|не.?має.?номерів|no\s+free\s+numbers/i;

const CODE_BEARING_STATUSES: string[] = [
  VirtualNumberStatus.RECEIVED,
  VirtualNumberStatus.COMPLETED,
];

export interface OutcomeClassification {
  outcome: VirtualNumberOutcome;
  counted: boolean;
}

/**
 * @param request وثيقة الطلب (أو ما يطابق حقولها المستخدمة هنا)
 * @param source  من أين جاء القرار: client/admin = إلغاء بشري، ما عداها ملاحظة نظام
 * @param reason  نص خطأ المزود الخام إن وُجد — يُخزَّن في السجل لا في الطلب،
 *                وهو وحده ما يميّز نفاد المخزون عن غيره حين لا رقم في الطلب
 */
export function classifyOutcome(
  request: {
    smsCode?: string;
    providerRef?: string;
    status?: string;
  },
  source: VirtualNumberOutcomeSource,
  reason = '',
): OutcomeClassification {
  // ١) الرمز وصل: نجاح، بغض النظر عمّن أغلق الطلب بعده
  const hasCode = Boolean((request.smsCode ?? '').trim());
  if (hasCode || CODE_BEARING_STATUSES.includes(String(request.status))) {
    return { outcome: VirtualNumberOutcome.SUCCESS, counted: true };
  }

  // ٢) لم يُخصَّص رقم أصلاً (providerRef غائب): لم يفشل المزود في توصيل شيء،
  //    فنفاد المخزون أو تعذّر التجهيز يُسجَّل بلا احتساب
  if (!String(request.providerRef ?? '').trim()) {
    return OUT_OF_STOCK_PATTERN.test(reason)
      ? { outcome: VirtualNumberOutcome.OUT_OF_STOCK, counted: false }
      : { outcome: VirtualNumberOutcome.PENDING, counted: false };
  }

  // ٣) رقم خُصِّص وأُغلق بلا رمز — هنا يُحتسب الفشل، وإلا فلغته:
  //    إلغاء العميل أو إيقاف الإدارة قرار بشري لا علاقة له بجودة المزود.
  if (source === 'client' || source === 'admin') {
    return { outcome: VirtualNumberOutcome.CANCELLED, counted: false };
  }
  return { outcome: VirtualNumberOutcome.FAILED, counted: true };
}

/**
 * عتبة الإيقاف التلقائي من البيئة، مع حماية من قيم غير رقمية أو أقل من واحد
 * (عتبة صفر كانت لتُوقف المنتج عند أول نجاح).
 */
export function resolveFailThreshold(raw?: string | null): number {
  const parsed = Number.parseInt(String(raw ?? '').trim(), 10);
  if (!Number.isFinite(parsed) || parsed < 1) return DEFAULT_FAIL_THRESHOLD;
  return parsed;
}

/** هل هذه النتيجة تدخل في نسبة وصول الأكواد؟ نجاح أو فشل مؤكد فقط */
export function isCountedOutcome(outcome: VirtualNumberOutcome): boolean {
  return (
    outcome === VirtualNumberOutcome.SUCCESS ||
    outcome === VirtualNumberOutcome.FAILED
  );
}

/**
 * اسم العدّاد على وثيقة المنتج لكل نتيجة — الفشل اسمه `failure` لا `failed`،
 * والتسمية الخاطئة كانت ستزيد حقلاً مجهولاً بصمت بدل أن تُحدّث العدّاد.
 * REACTIVATED حدث إداري بلا عدّاد.
 */
export const OUTCOME_COUNTER_FIELD: Partial<Record<VirtualNumberOutcome, string>> =
  {
    [VirtualNumberOutcome.SUCCESS]: 'success',
    [VirtualNumberOutcome.FAILED]: 'failure',
    [VirtualNumberOutcome.CANCELLED]: 'cancelled',
    [VirtualNumberOutcome.OUT_OF_STOCK]: 'outOfStock',
    [VirtualNumberOutcome.PENDING]: 'pending',
  };
