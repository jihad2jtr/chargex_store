import {
  classifySmsPoolStatus,
  cleanSmsPoolMessage,
  decodeMsgPack,
  decodeSmsPoolResponse,
  normalizeSmsPoolCatalog,
  pickSmsPoolNumber,
  readSmsPoolSms,
  smsPoolApiRoot,
} from './smspool.client';

// ---------------------------------------------------------------------------
// SMSPool يردّ بأكواد MessagePack رغم أنه يعلن application/json، ودولةُه وخدمةُه
// أرقامٌ صريحة (1 = الولايات المتحدة) هي الأكواد التي يجب أن تعود في الشراء.
// هذا الملف يفك كل ذلك على الورق بلا شبكة: خطأ في المفكّ = كتالوج فارغ للعميل،
// وخطأ في أرقام الحالة = طلب عالق لا يُرجع مبلغه أو إرجاع مال لرسالة وصلت.
// ---------------------------------------------------------------------------

/** مُرمِّز MessagePack مضغوط يكفي لصفوف SMSPool (nil/bool/int/str/array/map) */
function msgPack(value: any): Uint8Array {
  const chunks: number[] = [];
  const push = (...bytes: number[]): void => {
    chunks.push(...bytes);
  };
  const u32 = (n: number): number[] => [(n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255];
  const u64 = (n: number): number[] => [...u32(Math.floor(n / 2 ** 32)), ...u32(n % 2 ** 32)];

  const writeString = (text: string): void => {
    const raw = [...Buffer.from(text, 'utf8')];
    const length = raw.length;
    if (length <= 31) push(0xa0 | length);
    else if (length <= 255) push(0xd9, length);
    else if (length <= 65535) push(0xda, (length >> 8) & 255, length & 255);
    else push(0xdb, ...u32(length));
    push(...raw);
  };

  const write = (node: any): void => {
    if (node === null || node === undefined) return push(0xc0);
    if (node === true) return push(0xc3);
    if (node === false) return push(0xc2);

    if (typeof node === 'number') {
      if (Number.isInteger(node) && node >= 0 && node <= 0xffffffff) {
        if (node <= 0x7f) return push(node);
        if (node <= 0xff) return push(0xcc, node);
        if (node <= 0xffff) return push(0xcd, (node >> 8) & 255, node & 255);
        return push(0xce, ...u32(node));
      }
      if (Number.isInteger(node) && node >= -32 && node < 0) return push(node & 0xff);
      if (Number.isInteger(node) && node >= -(2 ** 31) && node < 2 ** 31) {
        return push(0xd2, ...u32(node >>> 0));
      }
      if (Number.isInteger(node)) return push(0xd3, ...u64(node));
      const float = new Uint8Array(new DataView(new ArrayBuffer(8)).buffer);
      const view = new DataView(float.buffer);
      view.setFloat64(0, node);
      return push(0xcb, ...float);
    }

    if (typeof node === 'string') return writeString(node);

    if (Array.isArray(node)) {
      const length = node.length;
      if (length <= 15) push(0x90 | length);
      else if (length <= 65535) push(0xdc, (length >> 8) & 255, length & 255);
      else push(0xdd, ...u32(length));
      for (const item of node) write(item);
      return;
    }

    const keys = Object.keys(node);
    if (keys.length <= 15) push(0x80 | keys.length);
    else if (keys.length <= 65535) push(0xde, (keys.length >> 8) & 255, keys.length & 255);
    else push(0xdf, ...u32(keys.length));
    for (const key of keys) {
      writeString(key);
      write(node[key]);
    }
  };

  write(value);
  return new Uint8Array(chunks);
}

describe('decodeMsgPack', () => {
  it('يفك القيم الأولية بأحجامها المختلفة', () => {
    expect(decodeMsgPack(msgPack(null))).toBeNull();
    expect(decodeMsgPack(msgPack(true))).toBe(true);
    expect(decodeMsgPack(msgPack(0))).toBe(0);
    expect(decodeMsgPack(msgPack(127))).toBe(127);
    expect(decodeMsgPack(msgPack(-1))).toBe(-1);
    expect(decodeMsgPack(msgPack(200))).toBe(200);
    expect(decodeMsgPack(msgPack(60000))).toBe(60000);
    expect(decodeMsgPack(msgPack(70000))).toBe(70000);
    expect(decodeMsgPack(msgPack(-70000))).toBe(-70000);
    expect(decodeMsgPack(msgPack('latvia'))).toBe('latvia');
  });

  it('يفك صفوف SMSPool: قاموس كبير بمفاتيح نصية وقيم مختلطة', () => {
    const rows = [
      {
        country: 5,
        country_name: 'Latvia',
        service: 124,
        service_name: 'Bolt',
        pool: 3,
        pool_name: 'Charlie',
        stock: 750,
        price: '0.08',
        last_update: '2026-10-30 20:07:07',
      },
    ];

    expect(decodeMsgPack(msgPack(rows))).toEqual(rows);
  });

  it('يفك قواميس كبيرة (>15 مدخلاً) ومصفوفات أطول من 15 عنصراً', () => {
    const big: Record<string, number> = {};
    for (let index = 0; index < 40; index += 1) big[`k${index}`] = index;
    expect(decodeMsgPack(msgPack(big))['k39']).toBe(39);

    const list = Array.from({ length: 20 }, (_, index) => index);
    expect(decodeMsgPack(msgPack(list))).toEqual(list);
  });

  it('نص عربي بترميز UTF-8 يبقى كما هو', () => {
    expect(decodeMsgPack(msgPack('الولايات المتحدة'))).toBe('الولايات المتحدة');
  });

  it('حمولة مبتورة ترمي بدل أن تعطي نصف صف', () => {
    const bytes = msgPack({ a: 'hello world value' });
    expect(() => decodeMsgPack(bytes.subarray(0, 6))).toThrow();
  });
});

describe('decodeSmsPoolResponse', () => {
  it('يميّز msgpack عن JSON وعن الكائن الجاهز', () => {
    const packed = msgPack({ success: 1, order_id: 'ABCD' });
    expect(decodeSmsPoolResponse(packed)).toEqual({ success: 1, order_id: 'ABCD' });
    expect(decodeSmsPoolResponse(Buffer.from('{"success":1}'))).toEqual({ success: 1 });
    expect(decodeSmsPoolResponse('{"balance":"5.00"}')).toEqual({ balance: '5.00' });
    expect(decodeSmsPoolResponse({ balance: 5 })).toEqual({ balance: 5 });
    expect(decodeSmsPoolResponse(null)).toBeNull();
  });
});

describe('smsPoolApiRoot', () => {
  it('يقبل رابط الموقع أو المضيف بلا بادئة إصدار', () => {
    expect(smsPoolApiRoot('https://api.smspool.net')).toBe('https://api.smspool.net');
    expect(smsPoolApiRoot('https://api.smspool.net/')).toBe('https://api.smspool.net');
    expect(smsPoolApiRoot('api.smspool.net')).toBe('https://api.smspool.net');
    expect(smsPoolApiRoot('')).toBe('https://api.smspool.net');
    expect(smsPoolApiRoot(undefined)).toBe('https://api.smspool.net');
  });
});

describe('normalizeSmsPoolCatalog', () => {
  const stock = [
    {
      country: 5,
      country_name: 'Latvia',
      service: 124,
      service_name: 'Bolt',
      pool: 3,
      pool_name: 'Charlie',
      stock: 750,
      price: '0.08',
    },
    // نفس الدولة والخدمة في مجمّع آخر أرخص لكن بلا مخزون: السعر المعتمد المخزّن
    {
      country: 5,
      country_name: 'Latvia',
      service: 124,
      service_name: 'Bolt',
      pool: 2,
      pool_name: 'Bravo',
      stock: 0,
      price: '0.04',
    },
    {
      country: 1,
      country_name: 'United States',
      service: 124,
      service_name: 'Bolt',
      pool: 3,
      pool_name: 'Charlie',
      stock: 12,
      price: '0.30',
    },
    // خدمة بلا اسم من المزود: يبقى رمزها حتى يُسمّيها المعجم أو يفشل
    { country: 1, country_name: 'United States', service: 999, service_name: null, pool: 0, pool_name: 'Default', stock: 4, price: '0.10' },
    // سعر صفر = غير معروض
    { country: 1, service: 124, price: '0', stock: 9, pool: 0 },
  ];

  const services = [
    { ID: 124, name: 'Bolt' },
    { ID: 999, name: 'Unknown Co' },
  ];
  const countries = [
    { ID: 1, name: 'United States', short_name: 'US' },
    { ID: 5, name: 'Latvia', short_name: 'LV' },
  ];

  it('يطوي صفوف المخزون إلى خدمة ← دول بأسعار ومخزون مجمّع', () => {
    const entries = normalizeSmsPoolCatalog({ stock, services, countries });

    expect(entries.map((entry) => entry.code)).toEqual(['124', '999']);

    const bolt = entries[0];
    // Latvia أرخص ($0.08) فتسبق US، والرمزان معرّفا المزود لا أكواد غيره
    expect(bolt.countries.map((country) => country.code)).toEqual(['5', '1']);
    expect(bolt.countries[0].cost).toBeCloseTo(0.08);
    expect(bolt.countries[0].count).toBe(750);
    expect(bolt.countries[0].name).toBe('Latvia');
    // المجمّعات تُعرض بأسمائها برمز 'any': الشراء لا يمرّر معرّف المجمّع
    expect(bolt.countries[0].operators).toEqual([{ code: 'any', name: 'Charlie' }]);
  });

  it('يأخذ اسم الدولة من المعجم حين يؤكده اسم المزود فقط', () => {
    const entries = normalizeSmsPoolCatalog({ stock, services, countries });
    const latvia = entries[0].countries.find((country) => country.code === '5')!;
    const usa = entries[0].countries.find((country) => country.code === '1')!;

    expect(latvia.nameAr).toBe('لاتفيا');
    expect(latvia.iso).toBe('LV');
    expect(usa.nameAr).toBe('الولايات المتحدة');
  });

  it('لا يخلط دولة برمز مزود آخر: رقم المزودصادم يبقى باسم المزود', () => {
    // ID=7 قد يطابق كود دولة آخر في المعجم، والمزود يقول إنها «Test Land»
    const entries = normalizeSmsPoolCatalog({
      stock: [{ country: 7, country_name: 'Test Land', service: 42, service_name: 'Test App', pool: 0, stock: 5, price: '0.20' }],
      services: [],
      countries: [],
    });

    expect(entries[0].countries[0].name).toBe('Test Land');
    expect(entries[0].countries[0].nameAr).toBe('Test Land');
    expect(entries[0].name).toBe('Test App');
  });

  it('استجابة ناقصة تعني كتالوجاً فارغاً بلا استثناء', () => {
    expect(normalizeSmsPoolCatalog({ stock: null })).toEqual([]);
    expect(normalizeSmsPoolCatalog({ stock: [] })).toEqual([]);
    expect(normalizeSmsPoolCatalog({ stock: [{ country: 1, service: 2, price: '0' }] })).toEqual([]);
  });
});

describe('حالة طلب SMSPool', () => {
  it('1 انتظار و3 رسالة و6 إرجاع', () => {
    expect(classifySmsPoolStatus({ status: 1, time_left: 1173 })).toBe('waiting');
    expect(classifySmsPoolStatus({ status: 3, sms: '12345', full_sms: 'Full code: 12345' })).toBe('received');
    expect(classifySmsPoolStatus({ status: 6, message: 'This order has been refunded' })).toBe('cancelled');
  });

  it('نص الرسالة يحسم الوصول ولو تغيّر ترقيم الحالة', () => {
    expect(classifySmsPoolStatus({ status: 1, full_sms: 'Your code is 44821' })).toBe('received');
  });

  it('الحالة المجهولة تبقى انتظاراً كي تحسمها المهلة بالإرجاع', () => {
    expect(classifySmsPoolStatus({ status: 99 })).toBe('unknown');
    expect(classifySmsPoolStatus(null)).toBe('unknown');
  });
});

describe('قراءة رقم ورسالة وخطأ SMSPool', () => {
  it('يبني الرقم الدولي من cc + phonenumber', () => {
    expect(pickSmsPoolNumber({ cc: '1', phonenumber: '234567890', number: 1234567890 })).toBe('1234567890');
    expect(pickSmsPoolNumber({ cc: '967', phonenumber: '712345678' })).toBe('967712345678');
    expect(pickSmsPoolNumber({ number: '1234567890' })).toBe('1234567890');
    expect(pickSmsPoolNumber({ success: 0 })).toBeNull();
  });

  it('ينظف وسوم HTML والروابط من رسالة الخطأ', () => {
    const message = cleanSmsPoolMessage({
      success: 0,
      type: 'OUT_OF_STOCK',
      message: '<p>Pool <b>Foxtrot</b>: We couldn\'t find an available phone number for you</p>',
    });

    expect(message).toBe('Pool Foxtrot : We couldn\'t find an available phone number for you');
    expect(cleanSmsPoolMessage({ errors: [{ message: 'Invalid API key' }] })).toBe('Invalid API key');
    expect(cleanSmsPoolMessage(null)).toBeNull();
  });

  it('الرمز يُقرأ من sms وحده أو من full_sms بالاستخراج', () => {
    const short = readSmsPoolSms({ status: 3, sms: '12345' });
    expect(short).toEqual({ smsText: '12345', code: '12345' });

    const full = readSmsPoolSms({ status: 3, full_sms: 'Full code: 12345' });
    expect(full.code).toBe('12345');
    expect(full.smsText).toBe('Full code: 12345');

    expect(readSmsPoolSms({ status: 1 })).toEqual({});
  });
});
