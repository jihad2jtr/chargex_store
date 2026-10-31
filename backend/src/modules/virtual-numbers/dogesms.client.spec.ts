import {
  classifyDogeSmsOrder,
  dogeSmsApiRoot,
  normalizeDogeSmsCatalog,
  pickDogeSmsNumber,
} from './dogesms.client';

// ---------------------------------------------------------------------------
// واجهة DogeSMS (REST v1) تُفك على الورق بلا شبكة. الفرق الجوهري عن بقية
// الموصّلات أن الشراء لا يعيد الرقم: الطلب يولد pending ويصير active حين
// يُخصَّص الرقم. أي خطأ في قراءة الحالات هنا يعني إما رقماً لا يراه العميل
// وهو مدفوع، أو إرجاع مال لطلبٍ سُلّم رقمه فعلاً.
// ---------------------------------------------------------------------------

describe('dogeSmsApiRoot', () => {
  it('يشتق الجذر /v1 من أي صيغة تحفظها الإدارة', () => {
    expect(dogeSmsApiRoot('https://api.dogesms.com')).toBe('https://api.dogesms.com/v1');
    expect(dogeSmsApiRoot('https://api.dogesms.com/v1/')).toBe('https://api.dogesms.com/v1');
    expect(dogeSmsApiRoot('api.dogesms.com')).toBe('https://api.dogesms.com/v1');
    // رابط الموقع لا مسار الإصدار: الجذر يُضاف مرة واحدة فقط
    expect(dogeSmsApiRoot('https://www.dogesms.com/docs')).toBe(
      'https://www.dogesms.com/docs/v1',
    );
  });

  it('يسقط على الافتراضي حين لا رابط أو لا يُقرأ', () => {
    expect(dogeSmsApiRoot('')).toBe('https://api.dogesms.com');
    expect(dogeSmsApiRoot(undefined)).toBe('https://api.dogesms.com');
  });
});

describe('normalizeDogeSmsCatalog', () => {
  const services = [{ code: 'whatsapp', name: 'Whatsapp' }, { code: 'telegram', name: 'Telegram' }];
  const countries = [
    { code: 'US', name: 'United States', phone_prefix: '1', service_count: 40 },
    { code: 'GB', name: 'United Kingdom', phone_prefix: '44', service_count: 30 },
  ];

  const channelsByCountry = [
    {
      countryCode: 'US',
      rows: [
        // قناة أرخص بلا مخزون وأخرى أغلى بمخزون: يُعتمد الأرخص المخزّن
        { service_code: 'telegram', channel_id: 'ch-1', price_cents: 12, available_count: 0, quality: 'low', rank: 3 },
        { service_code: 'telegram', channel_id: 'ch-2', price_cents: 20, available_count: 50, quality: 'high', rank: 1 },
        { service_code: 'whatsapp', channel_id: 'ch-3', price_cents: 60, available_count: 10, quality: 'medium', rank: 1 },
        // سعر صفر = غير معروض، وقناة بلا معرّف لا تصلح للترتيب
        { service_code: 'whatsapp', channel_id: '', price_cents: 5, available_count: 9 },
        { service_code: 'whatsapp', channel_id: 'ch-4', price_cents: 0, available_count: 9 },
      ],
    },
    {
      countryCode: 'GB',
      rows: [
        { service_code: 'telegram', channel_id: 'ch-5', price_cents: 35, available_count: 5, quality: 'high', rank: 1 },
      ],
    },
  ];

  it('يقلب القنوات إلى خدمة ← دول بأسعار بالدولار وأسماء المزود', () => {
    const entries = normalizeDogeSmsCatalog({ services, countries, channelsByCountry });

    // telegram أرخص ($0.12 لا مخزون له → $0.20)، فيسبق whatsapp
    expect(entries.map((entry) => entry.code)).toEqual(['telegram', 'whatsapp']);

    const telegram = entries[0];
    expect(telegram.name).toBe('Telegram');
    expect(telegram.countries.map((country) => country.code)).toEqual(['US', 'GB']);
    expect(telegram.countries[0].name).toBe('United States');
    expect(telegram.countries[0].cost).toBeCloseTo(0.2);
    expect(telegram.countries[0].count).toBe(50);
    // لا يُعرض من القنوات إلا ما يملك مخزوناً، والمعرّف الصالح للترتيب هو الرمز
    expect(telegram.countries[0].operators.map((op) => op.code)).toEqual(['ch-2']);
    expect(telegram.countries[0].operators[0].name).toBe('high #1');
  });

  it('يعيد اسم الدولة العربي من المعجم لأن رموز DogeSMS نصية لا تتصادم', () => {
    const entries = normalizeDogeSmsCatalog({ services, countries, channelsByCountry });
    const usa = entries[0].countries[0];

    expect(usa.nameAr).toBe('الولايات المتحدة');
    expect(usa.iso).toBe('US');
  });

  it('يبقي أرخص قناة بلا مخزون حين لا مخزون لأحد، ويتجاهل الدول الفارغة', () => {
    const entries = normalizeDogeSmsCatalog({
      services,
      countries,
      channelsByCountry: [
        { countryCode: 'GB', rows: [{ service_code: 'telegram', channel_id: 'ch-9', price_cents: 30 }] },
      ],
    });

    expect(entries).toHaveLength(1);
    expect(entries[0].countries[0].cost).toBeCloseTo(0.3);
    expect(entries[0].countries[0].count).toBe(0);
  });

  it('استجابة ناقصة أو قنوات فارغة تعني كتالوجاً فارغاً بلا استثناء', () => {
    expect(normalizeDogeSmsCatalog({ services: null, countries: null, channelsByCountry: null as any })).toEqual([]);
    expect(normalizeDogeSmsCatalog({ services, countries, channelsByCountry: [] })).toEqual([]);
    expect(
      normalizeDogeSmsCatalog({
        services,
        countries,
        channelsByCountry: [{ countryCode: 'US', rows: [] }],
      }),
    ).toEqual([]);
  });

  it('يقبل غلافاً من نوع data كما تتغلّف بعض الاستجابات', () => {
    const entries = normalizeDogeSmsCatalog({
      services: { data: services },
      countries: { data: countries },
      channelsByCountry: [
        {
          countryCode: 'US',
          rows: { data: [{ service_code: 'telegram', channel_id: 'ch-7', price_cents: 25, available_count: 3 }] },
        },
      ],
    });

    expect(entries[0].code).toBe('telegram');
    expect(entries[0].countries[0].cost).toBeCloseTo(0.25);
  });
});

describe('حالة طلب DogeSMS', () => {
  it('pending و active انتظارٌ ما لم تصل الرسالة', () => {
    expect(classifyDogeSmsOrder({ status: 'pending' }).state).toBe('waiting');
    expect(classifyDogeSmsOrder({ status: 'active', phone_number: '15551234567' }).state).toBe('waiting');
  });

  it('sms_code مع completed يعني وصول الرمز', () => {
    expect(
      classifyDogeSmsOrder({
        status: 'completed',
        sms_code: '09363',
        sms_content: 'WhatsApp code: 09363',
      }),
    ).toMatchObject({ state: 'received', code: '09363' });
  });

  it('يستخرج الرمز من نص الرسالة حين لا حقل sms_code', () => {
    expect(
      classifyDogeSmsOrder({ status: 'completed', sms_content: 'Your code is 44821' }),
    ).toMatchObject({ state: 'received', code: '44821' });
  });

  it('completed بلا رمز في الحقول يبقى بغير code فيُترك للمهلة', () => {
    // الحالة النهائية تُقرأ received نظرياً، لكن بلا رمز لا شيء يُعرض للعميل
    const read = classifyDogeSmsOrder({ status: 'completed' });
    expect(read.state).toBe('received');
    expect(read.code).toBeUndefined();
  });

  it('failed و expired و cancelled إلغاءٌ يُرجع المبلغ', () => {
    expect(classifyDogeSmsOrder({ status: 'failed', error_code: 'NO_INVENTORY' }).state).toBe('cancelled');
    expect(classifyDogeSmsOrder({ status: 'expired' }).state).toBe('cancelled');
    expect(classifyDogeSmsOrder({ status: 'cancelled' }).state).toBe('cancelled');
  });

  it('حالة مجهولة أو حمولة فارغة لا ترمي حكماً', () => {
    expect(classifyDogeSmsOrder({ status: 'whatever' }).state).toBe('unknown');
    expect(classifyDogeSmsOrder(null).state).toBe('unknown');
  });

  it('رقم الطلب يُقرأ من أشكال الحقل المختلفة', () => {
    expect(pickDogeSmsNumber({ phone_number: '+1 (555) 123-4567' })).toBe('+1 (555) 123-4567');
    expect(pickDogeSmsNumber({ number: '447123456789' })).toBe('447123456789');
    expect(pickDogeSmsNumber({ status: 'pending' })).toBeNull();
  });
});
