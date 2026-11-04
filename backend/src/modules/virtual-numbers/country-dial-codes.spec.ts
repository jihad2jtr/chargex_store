import { describe, expect, it } from 'vitest';
import { COUNTRY_DIAL_CODES, dialCodeForIso } from './country-dial-codes';

describe('نداءات الدول (E.164)', () => {
  it('يحلّ النداء من رمز ISO بكبيره وصغيره', () => {
    expect(dialCodeForIso('SY')).toBe('963');
    expect(dialCodeForIso('sy')).toBe('963');
    expect(dialCodeForIso(' EG ')).toBe('20');
  });

  it('الرمز المجهول أو الفراغ بلا نداء — لا يُختَرع بادئة عشوائية', () => {
    expect(dialCodeForIso('')).toBeNull();
    expect(dialCodeForIso('ZZ')).toBeNull();
    expect(dialCodeForIso('سوريا')).toBeNull();
  });

  it('جدول النداءات أرقام صحية غير مبدوءة بصفر', () => {
    for (const [iso, dial] of Object.entries(COUNTRY_DIAL_CODES)) {
      expect(dial).toMatch(/^[1-9]\d{0,4}$/);
      expect(iso).toMatch(/^[A-Z]{2}$/);
    }
  });
});
