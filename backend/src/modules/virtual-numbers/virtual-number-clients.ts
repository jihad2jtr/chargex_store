import { ProviderType } from '../../database/schemas/provider.schema';
import { FiveSimClient } from './fivesim.client';
import { HeroSmsClient } from './herosms.client';
import { VirtualNumberClient } from './virtual-number-client';

/**
 * مصنع موصّلات الأرقام الوهمية: قاعدة واحدة تحدد أي موصّل يُستخدم لأي مزود،
 * فيتشاركها مسحُ الكتالوج مع فحصِ المزود في شاشة المزودين ولا تتفرّع القواعد.
 */

/** الأنواع التي تخدم صفحة «أرقام وهمية» */
export const VIRTUAL_NUMBER_PROVIDER_TYPES: ProviderType[] = [
  ProviderType.FIVESIM,
  ProviderType.HEROSMS,
];

type ProviderLike = {
  providerType?: ProviderType | string;
  baseUrl?: string;
  name?: string;
};

/**
 * نوع مزود الأرقام: الحقل الصريح أولاً (وهو المرجع إن ضبطته الإدارة)، ثم الاسم
 * أو الرابط كما تفعل بقية المزودين — كي يعمل الربط ولو أُنشئ السجل يدوياً.
 */
export function detectVirtualNumberType(
  provider: ProviderLike,
): ProviderType | null {
  if (
    provider.providerType === ProviderType.FIVESIM ||
    provider.providerType === ProviderType.HEROSMS
  ) {
    return provider.providerType;
  }

  const hint = `${provider.baseUrl ?? ''} ${provider.name ?? ''}`.toLowerCase();
  if (hint.includes('5sim') || hint.includes('fivesim')) {
    return ProviderType.FIVESIM;
  }
  if (hint.includes('hero-sms') || hint.includes('herosms')) {
    return ProviderType.HEROSMS;
  }
  return null;
}

export function isVirtualNumberProvider(provider: ProviderLike): boolean {
  return detectVirtualNumberType(provider) !== null;
}

export function createVirtualNumberClient(provider: {
  baseUrl: string;
  apiKey: string;
  providerType?: ProviderType | string;
  name?: string;
}): VirtualNumberClient {
  const creds = { baseUrl: provider.baseUrl, apiKey: provider.apiKey };
  return (
    detectVirtualNumberType(provider) === ProviderType.HEROSMS
      ? new HeroSmsClient(creds)
      : new FiveSimClient(creds)
  );
}
