import {
  classifyFiveSimStatus,
  fiveSimApiRoot,
  normalizeFiveSimCatalog,
  pickFiveSimCode,
  readFiveSimOrder,
} from './fivesim.client';

// ---------------------------------------------------------------------------
// واجهة 5sim الحيّة (v2) تُفك على الورق بلا شبكة: الكتالوج يعود دولة ← خدمة ←
// مشغّل، والحالة نص صريح، والأخطاء نصوص («order not found»). خطأ في أيٍّ منها
// يعني إما كتالوجاً فارغاً للعميل أو طلباً عالقاً لا يُرجع مبلغه.
// ---------------------------------------------------------------------------

describe('fiveSimApiRoot', () => {
  it('يعيد المضيف القديم api.5sim.net إلى الجذر الحيّ', () => {
    // الرابط المحفوظ في سجلات اللوحة القديمة كان على مضيف أُزيل من المزوّد
    expect(fiveSimApiRoot('https://api.5sim.net/v1/user')).toBe(
      'https://5sim.net/v1',
    );
    expect(fiveSimApiRoot('https://api.5sim.net/v1')).toBe('https://5sim.net/v1');
  });

  it('يقبل روابط بأشكال مختلفة ويعيد جذر /v1 دائماً', () => {
    expect(fiveSimApiRoot('https://5sim.net/v1')).toBe('https://5sim.net/v1');
    expect(fiveSimApiRoot('https://5sim.net/v1/user/')).toBe(
      'https://5sim.net/v1',
    );
    expect(fiveSimApiRoot('5sim.net')).toBe('https://5sim.net/v1');
    expect(fiveSimApiRoot('5sim.net/ar')).toBe('https://5sim.net/ar/v1');
  });

  it('يسقط على الافتراضي حين لا رابط أو لا يُقرأ', () => {
    expect(fiveSimApiRoot('')).toBe('https://5sim.net/v1');
    expect(fiveSimApiRoot(undefined)).toBe('https://5sim.net/v1');
  });
});

describe('normalizeFiveSimCatalog', () => {
  const prices = {
    russia: {
      telegram: {
        virtual4: { cost: 0.3, count: 0 },
        virtual34: { cost: 0.15, count: 120 },
        virtual52: { cost: 0.12, count: 0 },
      },
      whatsapp: { virtual34: { cost: 0.4, count: 50 } },
    },
    egypt: {
      telegram: { virtual34: { cost: 0.2, count: 7 } },
      // سعر صفري يعني غير متاح ولا يُدرج
      instagram: { virtual34: { cost: 0, count: 10 } },
    },
  };

  const countries = {
    russia: { text_en: 'Russia', text_ru: 'Россия' },
    egypt: { text_en: 'Egypt', text_ru: 'Египет' },
  };

  it('يقلب الكتالوج إلى خدمة ← دول مع أسماء الدول', () => {
    const entries = normalizeFiveSimCatalog({ prices, countries });

    // الخدمات مرتبة بالأرخص: telegram ثم whatsapp (instagram سعره صفر)
    expect(entries.map((entry) => entry.code)).toEqual(['telegram', 'whatsapp']);

    const telegram = entries[0];
    expect(telegram.countries.map((country) => country.code)).toEqual([
      'russia',
      'egypt',
    ]);
    expect(telegram.countries[0].name).toBe('Russia');
    expect(telegram.countries[1].name).toBe('Egypt');
  });

  it('يجعل سعر الدولة أرخص مشغّل يملك مخزوناً لا أرخص سعر عموماً', () => {
    const telegram = normalizeFiveSimCatalog({ prices, countries })[0];
    const russia = telegram.countries[0];

    // virtual52 أرخص (0.12) لكن مخزونه صفر، فيُعتمد virtual34 (0.15)
    expect(russia.cost).toBeCloseTo(0.15);
    expect(russia.count).toBe(120);
    // المشغّلون المتاحون فقط، مرتبين بالأرخص
    expect(russia.operators.map((op) => op.code)).toEqual(['virtual34']);
  });

  it('يعود لأرخص مشغّل بلا مخزون حين لا مخزون لأي مشغّل', () => {
    const entries = normalizeFiveSimCatalog({
      prices: { spain: { telegram: { virtual4: { cost: 0.5, count: 0 }, virtual9: { cost: 0.3, count: 0 } } } },
    });

    expect(entries[0].countries[0].cost).toBeCloseTo(0.3);
    expect(entries[0].countries[0].count).toBe(0);
    expect(entries[0].countries[0].name).toBe('spain');
  });

  it('استجابة ناقصة أو فارغة تعني كتالوجاً فارغاً بلا استثناء', () => {
    expect(normalizeFiveSimCatalog({ prices: null })).toEqual([]);
    expect(normalizeFiveSimCatalog({ prices: {} })).toEqual([]);
    expect(normalizeFiveSimCatalog({ prices: { russia: {} } })).toEqual([]);
  });
});

describe('حالة طلب 5sim', () => {
  it('PENDING انتظار وRECEIVED بلا نص يبقى انتظاراً', () => {
    // الإعلان وحده لا يكفي: بلا رسالة لا يوجد رمز يُعرض للعميل
    expect(classifyFiveSimStatus({ status: 'PENDING' })).toBe('waiting');
    expect(classifyFiveSimStatus({ status: 'RECEIVED', sms: [] })).toBe(
      'waiting',
    );
  });

  it('وجود الرسالة أو رمزها يعني وصول الرمز مهما كانت الحالة', () => {
    const order = {
      status: 'RECEIVED',
      sms: [{ code: '09363', text: 'Facebook: 09363 - use this code' }],
    };

    expect(readFiveSimOrder(order)).toMatchObject({
      state: 'received',
      code: '09363',
      smsText: 'Facebook: 09363 - use this code',
    });
    // رمز في حقل code وحده يكفي
    expect(pickFiveSimCode(order)).toBe('09363');
  });

  it('يستخرج الرمز من نص الرسالة حين لا حقل code', () => {
    const order = { status: 'RECEIVED', sms: [{ text: 'Your code is 44821' }] };

    expect(readFiveSimOrder(order)).toMatchObject({
      state: 'received',
      code: '44821',
    });
  });

  it('الإلغاء والانتهاء والحظر والتخطي تُعامل كإلغاء يُرجع المبلغ', () => {
    expect(classifyFiveSimStatus({ status: 'CANCELED' })).toBe('cancelled');
    expect(classifyFiveSimStatus({ status: 'BANNED' })).toBe('cancelled');
    expect(classifyFiveSimStatus({ status: 'TIMEOUT' })).toBe('cancelled');
    // أُغلق لدى المزود بلا رمز: لا شيء سُلّم للعميل
    expect(classifyFiveSimStatus({ status: 'FINISHED' })).toBe('cancelled');
    // 5sim يرد بنص «order not found» لا بكائن، ويُعالج في مسار الخطأ كإلغاء
    expect(classifyFiveSimStatus({ status: 'NOT_FOUND' })).toBe('cancelled');
  });

  it('ترقيم الحالة القديم يبقى مفهوماً كي لا تسقط الطلبات القديمة', () => {
    expect(classifyFiveSimStatus({ status: 1 })).toBe('waiting');
    expect(classifyFiveSimStatus({ status: 3 })).toBe('received');
    expect(classifyFiveSimStatus({ status: 4 })).toBe('cancelled');
  });
});
