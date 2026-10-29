import {
  HeroSmsClient,
  classifyHeroSmsStatus,
  decodeHeroSmsReply,
  heroSmsEndpoint,
  normalizeHeroSmsCatalog,
} from './herosms.client';
import { FiveSimClient } from './fivesim.client';
import {
  createVirtualNumberClient,
  detectVirtualNumberType,
  isVirtualNumberProvider,
} from './virtual-number-clients';
import { ProviderType } from '../../database/schemas/provider.schema';

// ---------------------------------------------------------------------------
// بروتوكول Hero-SMS (متوافق SMS-Activate) يُفك على الورق بلا شبكة: نقطة واحدة
// بصيغة handler_api.php ترجع JSON أو نصاً قديماً (TOKEN:جزء:بقية)، وأسماء
// الأعمال وأرقام الحالة تختلف بين الإصدارات، فالتسامح هنا هو ما يمنع ضياع المال.
// ---------------------------------------------------------------------------

describe('heroSmsEndpoint', () => {
  it('يشتق نقطة handler_api من أي رابط للموقع', () => {
    // الإدارة تلصق رابط الصفحة الذي تنسخه من المتصفح لا رابط الـ API
    expect(heroSmsEndpoint('https://hero-sms.io/ar')).toBe(
      'https://hero-sms.io/stubs/handler_api.php',
    );
    expect(heroSmsEndpoint('hero-sms.com')).toBe(
      'https://hero-sms.com/stubs/handler_api.php',
    );
    expect(heroSmsEndpoint('https://hero-sms.com/api/')).toBe(
      'https://hero-sms.com/stubs/handler_api.php',
    );
  });

  it('يترك الرابط الكامل كما هو ويكمل الناقص بالافتراضي', () => {
    expect(
      heroSmsEndpoint('https://api.hero-sms.com/stubs/handler_api.php'),
    ).toBe('https://api.hero-sms.com/stubs/handler_api.php');
    expect(heroSmsEndpoint('')).toBe(
      'https://hero-sms.com/stubs/handler_api.php',
    );
    expect(heroSmsEndpoint('ليس رابطاً')).toBe(
      'https://hero-sms.com/stubs/handler_api.php',
    );
  });
});

describe('decodeHeroSmsReply', () => {
  it('يقرأ JSON ويترك الحالة الرقمية بلا خطأ', () => {
    const balance = decodeHeroSmsReply({ balance: '12.34' });
    expect(balance.ok).toBe(true);
    expect(balance.object.balance).toBe('12.34');

    const waiting = decodeHeroSmsReply({ status: '3' });
    expect(waiting.ok).toBe(true);
    expect(waiting.legacy).toBe(false);
  });

  it('يفك البروتوكول النصي القديم إلى رمز ومعرّف وبقية', () => {
    const number = decodeHeroSmsReply('ACCESS_NUMBER:123456:628123456789');
    expect(number.ok).toBe(true);
    expect(number.legacy).toBe(true);
    expect(number.token).toBe('ACCESS_NUMBER');
    expect(number.first).toBe('123456');
    expect(number.rest).toBe('628123456789');

    // نص الرسالة قد يحوي علامات : فلا تُبتَر
    const coded = decodeHeroSmsReply('STATUS_OK:123456:Your code: 481920');
    expect(coded.first).toBe('123456');
    expect(coded.rest).toBe('Your code: 481920');
  });

  it('يميز رموز الخطأ ويحوّلها رسالة مقروءة', () => {
    const denied = decodeHeroSmsReply('ACCESS_DENIED');
    expect(denied.ok).toBe(false);
    expect(denied.message).toBe('ACCESS DENIED');

    expect(decodeHeroSmsReply('NO_NUMBERS').ok).toBe(false);
    expect(decodeHeroSmsReply({ error: 'ERROR_INCORRECT_ORDER_ID' }).ok).toBe(
      false,
    );

    // المصادقة ليست خطأ: هذه نجاحات بصيغة ACCESS_*
    expect(decodeHeroSmsReply('ACCESS_FINISHED').ok).toBe(true);
    expect(decodeHeroSmsReply('ACCESS_CANCEL').ok).toBe(true);
  });

  it('يرفض الاستجابة الفارغة بدل أن تُفسَّر حالةً مجهولة', () => {
    const empty = decodeHeroSmsReply(null);
    expect(empty.ok).toBe(false);
    expect(empty.object).toBeNull();
  });
});

describe('classifyHeroSmsStatus', () => {
  it('يحوّل أرقام الحالة المعروفة', () => {
    expect(classifyHeroSmsStatus({ status: '3' })).toBe('waiting');
    expect(classifyHeroSmsStatus({ status: '11' })).toBe('waiting');
    expect(classifyHeroSmsStatus({ status: '4' })).toBe('received');
    expect(classifyHeroSmsStatus({ status: '20' })).toBe('received');
    expect(classifyHeroSmsStatus({ status: '8' })).toBe('cancelled');
    // رقم غير مألوف: يبقى مجهولاً فلا يُتخذ قرار مالي على تخمين
    expect(classifyHeroSmsStatus({ status: '40' })).toBe('unknown');
    expect(classifyHeroSmsStatus({})).toBe('unknown');
  });

  it('ينصّف الحالات النصية وأسماء الأعمال القديمة', () => {
    expect(classifyHeroSmsStatus('STATUS_WAIT_3')).toBe('waiting');
    expect(classifyHeroSmsStatus('STATUS_CANCEL')).toBe('cancelled');
    expect(classifyHeroSmsStatus('STATUS_NOT_FOUND')).toBe('cancelled');
    expect(classifyHeroSmsStatus('STATUS_OK')).toBe('received');
  });

  it('نص الرسالة يقطع الشك: وصل الرمز مهما قالت الحالة', () => {
    expect(classifyHeroSmsStatus({ status: '3' }, 'Your code: 481920')).toBe(
      'received',
    );
  });
});

describe('normalizeHeroSmsCatalog', () => {
  const services = [
    { id: '1', code: 'telgr', name: 'Telegram' },
    { id: '2', code: 'whts', name: 'WhatsApp' },
  ];
  const countries = {
    '1': { id: '1', name: 'كندا' },
    '20': { id: '20', name: 'مصر' },
  };

  it('يقرأ الشكل المتداخل خدمة ← دولة ويقوّم الأسماء', () => {
    const entries = normalizeHeroSmsCatalog({
      prices: {
        USD: {
          telgr: {
            '20': { count: '3', price: '0.07' },
            '1': { count: '12', price: '0.05' },
          },
        },
        // عملة أخرى تُترك: البيع بالدولار
        EUR: { telgr: { '1': { count: '5', price: '0.04' } } },
      },
      services,
      countries,
    });

    expect(entries).toHaveLength(1);
    expect(entries[0].code).toBe('telgr');
    expect(entries[0].name).toBe('Telegram');
    // الأرخص أولاً لأن الصفحة تعرضه افتراضياً
    expect(entries[0].countries.map((c) => c.code)).toEqual(['1', '20']);
    expect(entries[0].countries[0]).toMatchObject({
      name: 'كندا',
      cost: 0.05,
      count: 12,
    });
  });

  it('يقرأ الاتجاه المعكوس دولة ← خدمة ويعطي النتيجة نفسها', () => {
    const reversed = normalizeHeroSmsCatalog({
      prices: { USD: { '1': { telgr: { count: '12', price: '0.05' } } } },
      services,
      countries,
    });
    const forward = normalizeHeroSmsCatalog({
      prices: { USD: { telgr: { '1': { count: '12', price: '0.05' } } } },
      services,
      countries,
    });

    expect(reversed).toEqual(forward);
  });

  it('يقرأ الصفوف المسطحة ويتجاوز ما بلا رمز خدمة', () => {
    const entries = normalizeHeroSmsCatalog({
      prices: [
        { service: 'telgr', country: '1', price: '0.05', count: '9' },
        { service: 'whts', country: '20', price: '0.11' },
        { country: '1', price: '0.05' }, // بلا خدمة: لا تُنسب لرمز مجهول
      ],
      services,
      countries,
    });

    expect(entries.map((e) => e.code)).toEqual(['telgr', 'whts']);
    expect(entries[1].name).toBe('WhatsApp');
  });

  it('يسقط المجاني والمقفَر ويُبقي الرمز اسماً بلا قائمة أسماء', () => {
    const entries = normalizeHeroSmsCatalog({
      prices: {
        USD: {
          telgr: { '1': { price: '0.05' } },
          whts: { '1': { price: '0' } },
          dmcr: {},
        },
      },
    });

    expect(entries).toHaveLength(1);
    expect(entries[0].code).toBe('telgr');
    expect(entries[0].name).toBe('telgr'); // بلا قائمة أسماء: الرمز نفسه اسم
    expect(entries[0].countries[0].name).toBe('1');
    expect(entries[0].countries[0].operators).toEqual([]);
  });

  it('يتخذ الأرخص حين تتكرر الدولة نفسها في الاستجابة', () => {
    const entries = normalizeHeroSmsCatalog({
      prices: [
        { service: 'telgr', country: '1', price: '0.05', count: '9' },
        { service: 'telgr', country: '1', price: '0.02', count: '4' },
      ],
    });

    expect(entries[0].countries).toHaveLength(1);
    expect(entries[0].countries[0].cost).toBe(0.02);
    expect(entries[0].countries[0].count).toBe(4);
  });
});

describe('مصنع الموصّلات', () => {
  it('يختار الموصّل من نوع المزود أولاً ثم من الاسم والرابط', () => {
    expect(
      detectVirtualNumberType({ providerType: ProviderType.HEROSMS }),
    ).toBe(ProviderType.HEROSMS);
    expect(detectVirtualNumberType({ name: '5sim' })).toBe(
      ProviderType.FIVESIM,
    );
    expect(
      detectVirtualNumberType({ baseUrl: 'https://hero-sms.io/ar' }),
    ).toBe(ProviderType.HEROSMS);
    // الحقل الصريح يحكم ولو خالف الرابط (الإدارة تعدّل الرابط وحده)
    expect(
      detectVirtualNumberType({
        providerType: ProviderType.HEROSMS,
        baseUrl: 'https://api.5sim.net/v1/user',
      }),
    ).toBe(ProviderType.HEROSMS);
    expect(detectVirtualNumberType({ baseUrl: 'https://bay2game.com/api' })).toBeNull();
  });

  it('يبني الموصّل المناسب لكل مزود أرقام', () => {
    const creds = { baseUrl: 'https://hero-sms.io/ar', apiKey: 'k' };
    expect(
      createVirtualNumberClient({ ...creds, providerType: ProviderType.HEROSMS }),
    ).toBeInstanceOf(HeroSmsClient);
    expect(
      createVirtualNumberClient({
        baseUrl: 'https://api.5sim.net/v1/user',
        apiKey: 'k',
        providerType: ProviderType.FIVESIM,
      }),
    ).toBeInstanceOf(FiveSimClient);

    // مزود غير مختص بالأرقام لا يُحسب عليها
    expect(isVirtualNumberProvider({ name: 'Bay2Game' })).toBe(false);
    expect(isVirtualNumberProvider({ name: 'Hero-SMS' })).toBe(true);
  });
});
