import { ProviderType } from '../../database/schemas/provider.schema';
import { DogeSmsClient } from './dogesms.client';
import { FiveSimClient } from './fivesim.client';
import { HeroSmsClient } from './herosms.client';
import { SmsPoolClient } from './smspool.client';
import {
  VIRTUAL_NUMBER_PROVIDER_TYPES,
  createVirtualNumberClient,
  detectVirtualNumberType,
  isVirtualNumberProvider,
} from './virtual-number-clients';

// ---------------------------------------------------------------------------
// مصنع الموصّلات هو القاعدة الوحيدة التي تقرر بروتوكول كل مزود أرقام: إن أخطأ
// الاختيار قُرئ كتالوج مزود ببروتوكول غيره، ففسدت الأسعار والأرقام معاً. كما أن
// إضافة مزود جديد لا تكتمل إلا إذا دخل قائمته، لأن مسح المزودين وشاشة «أرقام
// وهمية» يبنيان تصفيتهما على هذه القائمة وحدها.
// ---------------------------------------------------------------------------

describe('detectVirtualNumberType', () => {
  it('يحترم الحقل الصريح لكل مزود أرقام ولو خالف الرابط', () => {
    for (const type of [
      ProviderType.FIVESIM,
      ProviderType.HEROSMS,
      ProviderType.DOGESMS,
      ProviderType.SMSPOOL,
    ]) {
      expect(detectVirtualNumberType({ providerType: type, baseUrl: 'https://example.com' })).toBe(type);
    }
  });

  it('يستدل على المزود من اسمه أو رابطه في السجل القديم', () => {
    expect(detectVirtualNumberType({ baseUrl: 'https://api.dogesms.com' })).toBe(ProviderType.DOGESMS);
    expect(detectVirtualNumberType({ name: 'DogeSMS' })).toBe(ProviderType.DOGESMS);
    expect(detectVirtualNumberType({ baseUrl: 'https://api.smspool.net' })).toBe(ProviderType.SMSPOOL);
    expect(detectVirtualNumberType({ name: 'SMSPool' })).toBe(ProviderType.SMSPOOL);
    expect(detectVirtualNumberType({ baseUrl: 'https://5sim.net/v1' })).toBe(ProviderType.FIVESIM);
    expect(detectVirtualNumberType({ baseUrl: 'https://hero-sms.com/stubs/handler_api.php' })).toBe(
      ProviderType.HEROSMS,
    );
  });

  it('مزود المتاجر لا يُحسب على الأرقام', () => {
    expect(detectVirtualNumberType({ baseUrl: 'https://bay2game.com/api' })).toBeNull();
    expect(isVirtualNumberProvider({ name: 'Fox Reload' })).toBe(false);
    expect(isVirtualNumberProvider({ name: 'SMSPool' })).toBe(true);
  });
});

describe('createVirtualNumberClient', () => {
  const creds = { apiKey: 'k' };

  it('يبني الموصّل المناسب لكل مزود أرقام', () => {
    expect(
      createVirtualNumberClient({
        ...creds,
        baseUrl: 'https://api.dogesms.com',
        providerType: ProviderType.DOGESMS,
      }),
    ).toBeInstanceOf(DogeSmsClient);
    expect(
      createVirtualNumberClient({
        ...creds,
        baseUrl: 'https://api.smspool.net',
        providerType: ProviderType.SMSPOOL,
      }),
    ).toBeInstanceOf(SmsPoolClient);
    expect(
      createVirtualNumberClient({ ...creds, baseUrl: 'https://hero-sms.com', providerType: ProviderType.HEROSMS }),
    ).toBeInstanceOf(HeroSmsClient);
    expect(
      createVirtualNumberClient({ ...creds, baseUrl: 'https://5sim.net/v1', providerType: ProviderType.FIVESIM }),
    ).toBeInstanceOf(FiveSimClient);
  });

  it('يبقي 5sim افتراضياً للسجل القديم بلا نوع ولا اسم دال', () => {
    expect(createVirtualNumberClient({ ...creds, baseUrl: 'https://numbers.example.com' })).toBeInstanceOf(
      FiveSimClient,
    );
  });

  it('كل أنواع الأرقام في قائمة المسح كي تُزامَن وتُفحص', () => {
    expect([...VIRTUAL_NUMBER_PROVIDER_TYPES].sort()).toEqual(
      [ProviderType.DOGESMS, ProviderType.FIVESIM, ProviderType.HEROSMS, ProviderType.SMSPOOL].sort(),
    );
  });
});
