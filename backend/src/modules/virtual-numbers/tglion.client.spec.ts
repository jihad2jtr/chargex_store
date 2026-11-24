import {
  classifyTgLionStatus,
  normalizeTgLionCatalog,
  parseTgLionCredentials,
  parseTgLionNumberResponse,
  tgLionApiRoot,
} from './tglion.client';

describe('tgLionApiRoot', () => {
  it('يعيد الرابط الافتراضي عند تمرير قيمة فارغة', () => {
    expect(tgLionApiRoot('')).toBe('https://tg-lion.net');
    expect(tgLionApiRoot(undefined)).toBe('https://tg-lion.net');
  });

  it('ينظف الروابط المدخلة ويزيل الشرطات الزائدة', () => {
    expect(tgLionApiRoot('https://www.tg-lion.net/')).toBe('https://www.tg-lion.net');
    expect(tgLionApiRoot('tg-lion.net')).toBe('https://tg-lion.net');
  });
});

describe('parseTgLionCredentials', () => {
  it('يستخرج YourID من apiSecret المنفصل', () => {
    const creds = parseTgLionCredentials({
      baseUrl: 'https://tg-lion.net',
      apiKey: 'my_api_key_123',
      apiSecret: 'user_id_456',
    });
    expect(creds.apiKey).toBe('my_api_key_123');
    expect(creds.yourId).toBe('user_id_456');
  });

  it('يستخرج YourID المدمج بفاصل نقطتين داخل apiKey', () => {
    const creds = parseTgLionCredentials({
      baseUrl: 'https://tg-lion.net',
      apiKey: 'my_api_key_123:user_id_456',
    });
    expect(creds.apiKey).toBe('my_api_key_123');
    expect(creds.yourId).toBe('user_id_456');
  });

  it('يستخرج YourID المدمج بشريط عمودي', () => {
    const creds = parseTgLionCredentials({
      baseUrl: 'https://tg-lion.net',
      apiKey: 'my_api_key_123|user_id_456',
    });
    expect(creds.apiKey).toBe('my_api_key_123');
    expect(creds.yourId).toBe('user_id_456');
  });
});

describe('normalizeTgLionCatalog', () => {
  it('يحصر الكتالوج بخدمة التيليجرام حصراً لكافة الدول المتاحة', () => {
    const raw = {
      status: 'ok',
      countries: [
        {
          name: 'Uzbekistan',
          code_Num: '40',
          code: 'UZ',
          qty: 6450,
          price: '0.80',
        },
        {
          name: 'Russia',
          code_Num: '7',
          code: 'RU',
          qty: 120,
          price: '1.20',
        },
      ],
    };

    const entries = normalizeTgLionCatalog(raw);
    expect(entries).toHaveLength(1);

    const telegram = entries[0];
    expect(telegram.code).toBe('telegram');
    expect(telegram.nameEn).toBe('Telegram');
    expect(telegram.countries).toHaveLength(2);

    const uz = telegram.countries.find((c) => c.code === 'uz');
    expect(uz).toBeDefined();
    expect(uz!.cost).toBe(0.8);
    expect(uz!.count).toBe(6450);
    expect(uz!.operators[0].code).toBe('default');

    const ru = telegram.countries.find((c) => c.code === 'ru');
    expect(ru).toBeDefined();
    expect(ru!.cost).toBe(1.2);
    expect(ru!.count).toBe(120);
  });

  it('يتجاهل الدول ذات السعر غير الصالح أو الصفر', () => {
    const raw = [
      { name: 'Invalid', code: 'xx', price: 0, qty: 5 },
      { name: 'Uzbekistan', code: 'uz', price: 0.5, qty: 10 },
    ];
    const entries = normalizeTgLionCatalog(raw);
    expect(entries).toHaveLength(1);
    expect(entries[0].countries).toHaveLength(1);
    expect(entries[0].countries[0].code).toBe('uz');
  });

  it('يعيد قائمة فارغة عند غياب البيانات', () => {
    expect(normalizeTgLionCatalog(null)).toEqual([]);
    expect(normalizeTgLionCatalog([])).toEqual([]);
    expect(normalizeTgLionCatalog({ countries: [] })).toEqual([]);
  });
});

describe('parseTgLionNumberResponse', () => {
  it('يفك استجابة JSON الناجحة', () => {
    const res = parseTgLionNumberResponse({
      status: 'success',
      id: '198384920',
      phone: '+998901234567',
      cost: '0.80',
    });
    expect(res.id).toBe('198384920');
    expect(res.number).toBe('998901234567');
  });

  it('يفك استجابة النص ACCESS_NUMBER:id:number', () => {
    const res = parseTgLionNumberResponse('ACCESS_NUMBER:198384920:998901234567');
    expect(res.id).toBe('198384920');
    expect(res.number).toBe('998901234567');
  });

  it('يرمي خطأ صريح عند استجابة الخطأ', () => {
    expect(() =>
      parseTgLionNumberResponse({
        status: 'error',
        cod: 400,
        message: 'No numbers available',
      }),
    ).toThrow('No numbers available');
  });
});

describe('classifyTgLionStatus', () => {
  it('يصنف حالات الانتظار', () => {
    expect(classifyTgLionStatus('STATUS_WAIT_CODE').state).toBe('waiting');
    expect(classifyTgLionStatus({ status: 'STATUS_WAIT_CODE' }).state).toBe('waiting');
    expect(classifyTgLionStatus({ status: 'waiting' }).state).toBe('waiting');
    expect(classifyTgLionStatus({ status: 'STATUS_OK' }).state).toBe('waiting');
  });

  it('يصنف استلام الكود بنجاح من الحقول المختلفة', () => {
    const directCode = classifyTgLionStatus({ status: 'STATUS_OK', code: '54321' });
    expect(directCode.state).toBe('received');
    expect(directCode.code).toBe('54321');

    const smsCode = classifyTgLionStatus({ status: 'STATUS_OK', sms: 'Your Telegram code is 78901' });
    expect(smsCode.state).toBe('received');
    expect(smsCode.code).toBe('78901');

    const textProtocol = classifyTgLionStatus('STATUS_OK:99887');
    expect(textProtocol.state).toBe('received');
    expect(textProtocol.code).toBe('99887');
  });

  it('يصنف الإلغاء والاسترجاع', () => {
    expect(classifyTgLionStatus('STATUS_CANCEL').state).toBe('cancelled');
    expect(classifyTgLionStatus({ status: 'CANCELLED' }).state).toBe('cancelled');
    expect(classifyTgLionStatus({ status: 'REFUNDED' }).state).toBe('cancelled');
  });
});
