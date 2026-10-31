import {
  DEFAULT_FAIL_THRESHOLD,
  OUTCOME_COUNTER_FIELD,
  classifyOutcome,
  isCountedOutcome,
  resolveFailThreshold,
} from './virtual-number-quality';
import {
  VirtualNumberOutcome,
  VirtualNumberOutcomeSource,
} from '../../database/schemas/virtual-number-quality-event.schema';
import { VirtualNumberStatus } from '../../database/schemas/virtual-number-request.schema';

/**
 * مصفوفة التصنيف: هي العقد الذي تتفق عليه الخدمة والمسح والويب هوك.
 * القاعدة المحورية — رقم خُصِّص (`providerRef` موجود) وأُغلق بلا رمز = فشل محتسب،
 * وانتهت مهلة الانتظار أو لا: كلاهما أن المزود لم يوصِل ما دُفع مقابلَه. وما لا
 * رقم فيه، أو ما أغلقه قرار بشري (عميل/إدارة)، يسجَّل في السجل بلا احتساب.
 */

describe('classifyOutcome — الرمز وصل فهو نجاح', () => {
  it('رمز غير فارغ مع أي حالة وأي مصدر = SUCCESS محتسب', () => {
    for (const source of [
      'sweep',
      'webhook',
      'sync',
      'client',
      'admin',
    ] as VirtualNumberOutcomeSource[]) {
      expect(
        classifyOutcome(
          { smsCode: '12345', providerRef: '9001', status: VirtualNumberStatus.CANCELLED },
          source,
        ),
      ).toEqual({ outcome: VirtualNumberOutcome.SUCCESS, counted: true });
    }
  });

  it('حالة received/completed بلا رمز نصي تُعدّ نجاحاً (المزود أكّد التسليم)', () => {
    expect(
      classifyOutcome({ providerRef: '9001', status: VirtualNumberStatus.RECEIVED }, 'sync'),
    ).toEqual({ outcome: VirtualNumberOutcome.SUCCESS, counted: true });
    expect(
      classifyOutcome({ providerRef: '9001', status: VirtualNumberStatus.COMPLETED }, 'webhook'),
    ).toEqual({ outcome: VirtualNumberOutcome.SUCCESS, counted: true });
  });

  it('الرمز المسافات وحدها لا يصلح رمزاً: يبقى القرار بحسب المصدر', () => {
    expect(
      classifyOutcome({ smsCode: '   ', providerRef: '9001', status: VirtualNumberStatus.CANCELLED }, 'sweep'),
    ).toEqual({ outcome: VirtualNumberOutcome.FAILED, counted: true });
  });
});

describe('classifyOutcome — لم يُخصَّص رقم: لا يُحتسب على المزود', () => {
  it('بلا providerRef وبلا رمز = غير محتسب، pending حين لا سبب نفاد', () => {
    expect(
      classifyOutcome({ providerRef: '', status: VirtualNumberStatus.CANCELLED }, 'request', 'timeout'),
    ).toEqual({ outcome: VirtualNumberOutcome.PENDING, counted: false });
    // providerRef المسافات لا يُعدّ رقماً مخصَّصاً
    expect(
      classifyOutcome({ providerRef: '  ', status: VirtualNumberStatus.CANCELLED }, 'request'),
    ).toEqual({ outcome: VirtualNumberOutcome.PENDING, counted: false });
  });

  it('أنماط نفاد المخزون تُسمّى out_of_stock وتبقى غير محتسبة', () => {
    const patterns = [
      'NO_NUMBERS',
      'NO_INVENTORY',
      'OUT_OF_STOCK',
      'SERVICE_NOT_AVAILABLE',
      'PRICE_NOT_FOUND',
      'no free numbers',
      'не має номерів',
    ];
    for (const reason of patterns) {
      expect(
        classifyOutcome({ providerRef: '', status: VirtualNumberStatus.FAILED }, 'request', reason),
      ).toEqual({ outcome: VirtualNumberOutcome.OUT_OF_STOCK, counted: false });
    }
  });

  it('انقطاع الاتصال لحظة الشراء ليس نفاداً ولا فشلاً محتسباً', () => {
    expect(
      classifyOutcome(
        { providerRef: '', status: VirtualNumberStatus.FAILED },
        'request',
        'fetch failed: ECONNRESET',
      ),
    ).toEqual({ outcome: VirtualNumberOutcome.PENDING, counted: false });
  });
});

describe('classifyOutcome — رقم خُصِّص وأُغلق بلا رمز', () => {
  it('المسح الدوري حسم مهلة منتهية = فشل محتسب', () => {
    expect(
      classifyOutcome(
        { providerRef: '9001', status: VirtualNumberStatus.EXPIRED },
        'sweep',
        'انتهت مهلة الانتظار بلا رمز',
      ),
    ).toEqual({ outcome: VirtualNumberOutcome.FAILED, counted: true });
  });

  it('ويب هوك يخبر بإلغاء المزود = فشل محتسب', () => {
    expect(
      classifyOutcome({ providerRef: '9001', status: VirtualNumberStatus.CANCELLED }, 'webhook', 'canceled by provider'),
    ).toEqual({ outcome: VirtualNumberOutcome.FAILED, counted: true });
  });

  it('إلغاء العميل أو إيقاف الإدارة قرار بشري: ملغى غير محتسب', () => {
    expect(
      classifyOutcome({ providerRef: '9001', status: VirtualNumberStatus.CANCELLED }, 'client'),
    ).toEqual({ outcome: VirtualNumberOutcome.CANCELLED, counted: false });
    expect(
      classifyOutcome({ providerRef: '9001', status: VirtualNumberStatus.CANCELLED }, 'admin', 'إيقاف من الإدارة'),
    ).toEqual({ outcome: VirtualNumberOutcome.CANCELLED, counted: false });
  });

  it('مزامنة حالة طلب حيّ بلا رمز = فشل محتسب (المزود لم يوصِل)', () => {
    expect(
      classifyOutcome({ providerRef: '9001', status: VirtualNumberStatus.CANCELLED }, 'sync'),
    ).toEqual({ outcome: VirtualNumberOutcome.FAILED, counted: true });
  });
});

describe('عتبة الإيقاف وأسماء العدّادات', () => {
  it('resolveFailThreshold: الافتراضي 3، وحماية من الصفر والسالب وغير الرقمي', () => {
    expect(resolveFailThreshold(undefined)).toBe(DEFAULT_FAIL_THRESHOLD);
    expect(resolveFailThreshold(null)).toBe(DEFAULT_FAIL_THRESHOLD);
    expect(resolveFailThreshold('')).toBe(DEFAULT_FAIL_THRESHOLD);
    expect(resolveFailThreshold('abc')).toBe(DEFAULT_FAIL_THRESHOLD);
    expect(resolveFailThreshold('0')).toBe(DEFAULT_FAIL_THRESHOLD);
    expect(resolveFailThreshold('-2')).toBe(DEFAULT_FAIL_THRESHOLD);
    expect(resolveFailThreshold(' 5 ')).toBe(5);
  });

  it('المحتسب هو SUCCESS وFAILED وحدهما', () => {
    expect(isCountedOutcome(VirtualNumberOutcome.SUCCESS)).toBe(true);
    expect(isCountedOutcome(VirtualNumberOutcome.FAILED)).toBe(true);
    expect(isCountedOutcome(VirtualNumberOutcome.CANCELLED)).toBe(false);
    expect(isCountedOutcome(VirtualNumberOutcome.OUT_OF_STOCK)).toBe(false);
    expect(isCountedOutcome(VirtualNumberOutcome.PENDING)).toBe(false);
    expect(isCountedOutcome(VirtualNumberOutcome.AUTO_DISABLED)).toBe(false);
    expect(isCountedOutcome(VirtualNumberOutcome.REACTIVATED)).toBe(false);
  });

  it('أسماء العدّادات تطابق مخطط المنتج (الفشل failure لا failed)', () => {
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.SUCCESS]).toBe('success');
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.FAILED]).toBe('failure');
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.CANCELLED]).toBe('cancelled');
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.OUT_OF_STOCK]).toBe('outOfStock');
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.PENDING]).toBe('pending');
    // حدثان إداريان/نظاميان بلا عدّاد: زيادتهما كانت تخلق حقلاً مجهولاً بصمت
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.AUTO_DISABLED]).toBeUndefined();
    expect(OUTCOME_COUNTER_FIELD[VirtualNumberOutcome.REACTIVATED]).toBeUndefined();
  });

  it('كل نتيجة مُصنَّفة لها عدّاد أو صفة «غير محتسب» صريحة', () => {
    const classified = [
      VirtualNumberOutcome.SUCCESS,
      VirtualNumberOutcome.FAILED,
      VirtualNumberOutcome.CANCELLED,
      VirtualNumberOutcome.OUT_OF_STOCK,
      VirtualNumberOutcome.PENDING,
    ];
    for (const outcome of classified) {
      expect(OUTCOME_COUNTER_FIELD[outcome]).toBeTruthy();
    }
  });
});
