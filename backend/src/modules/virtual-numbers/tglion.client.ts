/**
 * موصل TG-Lion (أرقام التحقق الوهمية لتطبيق تيليجرام حصراً) عبر واجهة REST.
 *
 *   GET /?action=get_balance&apiKey=...&YourID=...
 *       → { status: "success", balance: "15.50", currency: "USD" }
 *   GET /?action=available_countries&apiKey=...&YourID=...
 *       → { status: "ok", countries: [ { name: "Uzbekistan", code_Num: "40", code: "UZ", qty: 6450, price: "0.80" } ] }
 *   GET /?action=country_info&apiKey=...&YourID=...&country_code=uz
 *       → { name: "Uzbekistan", code_Num: "40", code: "UZ", qty: 6450, price: "0.80" }
 *   GET /?action=getNumber&apiKey=...&YourID=...&country_code=uz&service=tg
 *       → { status: "success", id: "198384920", phone: "998901234567", cost: "0.80" }
 *         أو بصيغة نصية: ACCESS_NUMBER:198384920:998901234567
 *   GET /?action=getCode&apiKey=...&YourID=...&id=198384920
 *       → { status: "STATUS_OK", code: "12345" }
 *         أو { status: "STATUS_WAIT_CODE" }
 *
 * الخصائص التشغيلية لهذا المزود:
 * 1. مختص فقط بأرقام التيليجرام: الكتالوج يُنتج دائماً خدمة واحدة (Telegram) لكافة الدول المتاحة.
 * 2. المصادقة تتطلب كلاً من apiKey و YourID. يقبل الموصل YourID من apiSecret أو مدمجاً في apiKey (`key:YourID`).
 * 3. ترويسة User-Agent ضرورية لتفادي حظر Cloudflare 403 Forbidden.
 */

import { BadRequestException, Logger } from '@nestjs/common';
import axios, { AxiosRequestConfig } from 'axios';
import {
  VirtualNumberCancelParams,
  VirtualNumberClient,
  VirtualNumberCredentials,
  VirtualNumberHandle,
  VirtualNumberProfile,
  VirtualNumberProviderError,
  VirtualNumberServiceEntry,
  VirtualNumberStatusResult,
  digitsOnly,
  extractVerificationCode,
  isTimeoutError,
  pickStringValue,
  providerErrorMessage,
  readSmsText,
  toEntries,
  toNumberValue,
  unwrapPayload,
} from './virtual-number-client';
import {
  resolveAppMeta,
  resolveCountryMeta,
} from './virtual-numbers-dictionary';

export const TGLION_DEFAULT_BASE = 'https://tg-lion.net';

const BROWSER_USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/**
 * جذر API لمزود TG-Lion: ينظف الرابط ويعيد المسار الأساسي.
 */
export function tgLionApiRoot(baseUrl?: string): string {
  let raw = (baseUrl || '').trim().replace(/\/+$/, '');
  if (!raw) return TGLION_DEFAULT_BASE;
  if (!/^https?:\/\//i.test(raw)) raw = `https://${raw}`;

  try {
    const url = new URL(raw);
    return `${url.origin}${url.pathname.replace(/\/+$/, '')}`;
  } catch {
    return TGLION_DEFAULT_BASE;
  }
}

/**
 * استخراج apiKey و YourID من بيانات الاعتماد:
 * - YourID من apiSecret (الطريقة المفضلة في لوحة التحكم)
 * - أو مفصولين بفاصل نقطتين `apiKey:YourID` أو شريط عمودي `apiKey|YourID`
 */
export function parseTgLionCredentials(creds: VirtualNumberCredentials): {
  apiKey: string;
  yourId: string;
} {
  let apiKey = (creds.apiKey || '').trim();
  let yourId = (creds.apiSecret || '').trim();

  if (!yourId && apiKey.includes(':')) {
    const parts = apiKey.split(':');
    apiKey = parts[0].trim();
    yourId = parts.slice(1).join(':').trim();
  } else if (!yourId && apiKey.includes('|')) {
    const parts = apiKey.split('|');
    apiKey = parts[0].trim();
    yourId = parts.slice(1).join('|').trim();
  }

  return { apiKey, yourId };
}

/**
 * معالجة وتوحيد كتالوج TG-Lion:
 * نظراً لأن المزود مختص فقط بالتيليجرام، تُجمع كل الدول تحت خدمة تيليجرام.
 */
export function normalizeTgLionCatalog(raw: any): VirtualNumberServiceEntry[] {
  const payload = unwrapPayload(raw);
  if (!payload) return [];

  let list: any[] = [];
  if (Array.isArray(payload)) {
    list = payload;
  } else if (Array.isArray(payload.countries)) {
    list = payload.countries;
  } else if (Array.isArray(payload.data)) {
    list = payload.data;
  } else if (typeof payload === 'object') {
    list = toEntries(payload).map((e) => (typeof e.value === 'object' ? { ...e.value, code: e.key } : null)).filter(Boolean);
  }

  const countriesList: VirtualNumberServiceEntry['countries'] = [];

  for (const item of list) {
    if (!item || typeof item !== 'object') continue;

    const rawCode = pickStringValue(item, ['code', 'country_code', 'iso', 'code_Num']) ?? '';
    const rawName = pickStringValue(item, ['name', 'country', 'country_name']) ?? '';
    const cost = toNumberValue(item.price ?? item.cost ?? item.rate);
    const count = toNumberValue(item.qty ?? item.count ?? item.stock ?? 0);

    // نتجاهل الصفوف ذات السعر غير الصالح
    if (cost <= 0) continue;

    const meta = resolveCountryMeta(rawCode || rawName);
    const code = (meta.iso || rawCode || rawName).toLowerCase();
    if (!code) continue;

    countriesList.push({
      code,
      name: meta.nameEn || rawName || code,
      nameAr: meta.nameAr || rawName,
      nameEn: meta.nameEn || rawName,
      flag: meta.flag,
      iso: meta.iso || (rawCode.length === 2 ? rawCode.toUpperCase() : undefined),
      cost,
      count,
      operators: [
        {
          code: 'default',
          name: 'Default',
          price: cost,
          count,
        },
      ],
    });
  }

  if (countriesList.length === 0) return [];

  const tgMeta = resolveAppMeta('telegram');

  return [
    {
      code: 'telegram',
      name: tgMeta.nameEn || 'Telegram',
      nameAr: tgMeta.nameAr || 'تيليجرام',
      nameEn: tgMeta.nameEn || 'Telegram',
      icon: tgMeta.icon || 'assets/icons/telegram.png',
      countries: countriesList,
    },
  ];
}

/**
 * تحليل استجابة طلب الرقم: تدعم كلاً من JSON والشكل النصي (ACCESS_NUMBER:id:number)
 */
export function parseTgLionNumberResponse(data: any): { id: string; number: string } {
  if (typeof data === 'string') {
    const text = data.trim();
    if (text.startsWith('ACCESS_NUMBER:')) {
      const parts = text.split(':');
      if (parts.length >= 3) {
        const id = parts[1].trim();
        const number = digitsOnly(parts.slice(2).join(''));
        if (id && number) return { id, number };
      }
    }
    try {
      data = JSON.parse(text);
    } catch {
      // ليس JSON صالحاً
    }
  }

  if (data && typeof data === 'object') {
    if (data.status === 'error' || data.cod === 400 || data.cod === 401 || data.cod === 500) {
      throw new VirtualNumberProviderError(data.message || 'فشل طلب الرقم من TG-Lion');
    }

    const id = pickStringValue(data, ['id', 'order_id', 'orderId', 'activationId', 'code_id']);
    const rawNumber = pickStringValue(data, ['phone', 'number', 'phoneNumber', 'phone_number', 'phoneNum']);

    if (id && rawNumber) {
      return { id, number: digitsOnly(rawNumber) };
    }
  }

  throw new VirtualNumberProviderError('استجابة غير صالحة من TG-Lion عند طلب الرقم');
}

/**
 * تصنيف حالة طلب الرقم واستخراج الكود أو نص الرسالة
 */
export function classifyTgLionStatus(data: any): VirtualNumberStatusResult {
  if (typeof data === 'string') {
    const text = data.trim();
    if (text === 'STATUS_WAIT_CODE' || text === 'WAIT_CODE' || text.includes('STATUS_WAIT')) {
      return { state: 'waiting', status: text, raw: data };
    }
    if (text.startsWith('STATUS_OK:') || text.startsWith('ACCESS_CODE:')) {
      const code = text.split(':')[1]?.trim() || '';
      return { state: 'received', code, smsText: text, status: text, raw: data };
    }
    if (text === 'STATUS_CANCEL' || text === 'ACCESS_CANCEL' || text.includes('CANCEL')) {
      return { state: 'cancelled', status: text, raw: data };
    }
    try {
      data = JSON.parse(text);
    } catch {
      // نص عادي
      const extracted = extractVerificationCode(text);
      if (extracted) {
        return { state: 'received', code: extracted, smsText: text, raw: data };
      }
    }
  }

  if (data && typeof data === 'object') {
    const statusStr = String(data.status || data.state || '').toUpperCase();
    const sms = readSmsText(data);
    const directCode = pickStringValue(data, ['code', 'sms_code', 'verificationCode', 'otp']);

    if (directCode) {
      return {
        state: 'received',
        code: directCode,
        smsText: sms || directCode,
        status: statusStr,
        raw: data,
      };
    }

    if (sms) {
      const code = extractVerificationCode(sms);
      return {
        state: code ? 'received' : 'waiting',
        code: code || undefined,
        smsText: sms,
        status: statusStr,
        raw: data,
      };
    }

    if (
      statusStr === 'STATUS_WAIT_CODE' ||
      statusStr === 'WAIT_CODE' ||
      statusStr === 'WAITING' ||
      statusStr === 'PENDING' ||
      statusStr === 'ACTIVE'
    ) {
      return { state: 'waiting', status: statusStr, raw: data };
    }

    if (
      statusStr === 'STATUS_CANCEL' ||
      statusStr === 'CANCELLED' ||
      statusStr === 'CANCELED' ||
      statusStr === 'REFUNDED' ||
      statusStr === 'EXPIRED' ||
      statusStr === 'NO_CODE'
    ) {
      return { state: 'cancelled', status: statusStr, raw: data };
    }

    if (statusStr === 'STATUS_OK' || statusStr === 'SUCCESS' || statusStr === 'OK') {
      const code = extractVerificationCode(String(data.message || data.msg || ''));
      if (code) {
        return { state: 'received', code, status: statusStr, raw: data };
      }
      return { state: 'waiting', status: statusStr, raw: data };
    }
  }

  return { state: 'unknown', raw: data };
}

export class TgLionClient implements VirtualNumberClient {
  private readonly logger = new Logger(TgLionClient.name);
  private readonly apiRoot: string;
  private readonly apiKey: string;
  private readonly yourId: string;

  constructor(creds: VirtualNumberCredentials) {
    this.apiRoot = tgLionApiRoot(creds.baseUrl);
    const parsed = parseTgLionCredentials(creds);
    this.apiKey = parsed.apiKey;
    this.yourId = parsed.yourId;
  }

  private requestConfig(extra?: AxiosRequestConfig): AxiosRequestConfig {
    return {
      headers: {
        'User-Agent': BROWSER_USER_AGENT,
        Accept: 'application/json, text/plain, */*',
        ...(extra?.headers || {}),
      },
      timeout: 15_000,
      ...extra,
    };
  }

  /**
   * جلب الرصيد ومعلومات الحساب:
   * GET /?action=get_balance&apiKey=...&YourID=...
   */
  async getProfile(): Promise<VirtualNumberProfile> {
    try {
      const url = `${this.apiRoot}/?action=get_balance&apiKey=${encodeURIComponent(this.apiKey)}&YourID=${encodeURIComponent(this.yourId)}`;
      const res = await axios.get(url, this.requestConfig());
      const data = res.data;

      if (data && typeof data === 'object' && (data.status === 'error' || data.cod === 401 || data.cod === 400)) {
        throw new VirtualNumberProviderError(data.message || 'خطأ في المصادقة مع TG-Lion');
      }

      const balance = toNumberValue(data?.balance ?? data?.data?.balance ?? data);
      return {
        balance,
        raw: data,
      };
    } catch (err: any) {
      if (err instanceof VirtualNumberProviderError) throw err;
      throw new VirtualNumberProviderError(
        `فشل الاتصال بـ TG-Lion: ${providerErrorMessage(err)}`,
        isTimeoutError(err),
        err?.response?.status,
      );
    }
  }

  /**
   * جلب كتالوج الأرقام (مختص فقط بتيليجرام):
   * يستعلم الدول المتاحة وأسعارها ويعيد خدمة تيليجرام لكافة الدول.
   */
  async getCatalog(): Promise<VirtualNumberServiceEntry[]> {
    try {
      const url = `${this.apiRoot}/?action=available_countries&apiKey=${encodeURIComponent(this.apiKey)}&YourID=${encodeURIComponent(this.yourId)}`;
      let res: any;
      try {
        res = await axios.get(url, this.requestConfig());
      } catch (err: any) {
        // إذا لم يدعم available_countries نجرب country_info
        const fallbackUrl = `${this.apiRoot}/?action=country_info&apiKey=${encodeURIComponent(this.apiKey)}&YourID=${encodeURIComponent(this.yourId)}`;
        res = await axios.get(fallbackUrl, this.requestConfig());
      }

      return normalizeTgLionCatalog(res.data);
    } catch (err: any) {
      this.logger.error(`فشل جلب كتالوج TG-Lion: ${providerErrorMessage(err)}`);
      return [];
    }
  }

  /**
   * شراء رقم تيليجرام من دولة محددة:
   * GET /?action=getNumber&apiKey=...&YourID=...&country_code=...&service=tg
   */
  async requestNumber(params: {
    service: string;
    country: string;
    operator?: string;
  }): Promise<VirtualNumberHandle> {
    const countryCode = (params.country || '').trim().toLowerCase();
    try {
      const url =
        `${this.apiRoot}/?action=getNumber` +
        `&apiKey=${encodeURIComponent(this.apiKey)}` +
        `&YourID=${encodeURIComponent(this.yourId)}` +
        `&country_code=${encodeURIComponent(countryCode)}` +
        `&country=${encodeURIComponent(countryCode)}` +
        `&service=tg`;

      const res = await axios.get(url, this.requestConfig());
      const parsed = parseTgLionNumberResponse(res.data);

      return {
        id: parsed.id,
        number: parsed.number,
        raw: res.data,
      };
    } catch (err: any) {
      if (err instanceof VirtualNumberProviderError) throw err;
      const isTimeout = isTimeoutError(err);
      throw new VirtualNumberProviderError(
        `فشل طلب رقم تيليجرام من TG-Lion: ${providerErrorMessage(err)}`,
        isTimeout,
        err?.response?.status,
      );
    }
  }

  /**
   * فحص كود التفعيل المستلم:
   * GET /?action=getCode&apiKey=...&YourID=...&id=...
   */
  async fetchStatus(id: string): Promise<VirtualNumberStatusResult> {
    try {
      const url =
        `${this.apiRoot}/?action=getCode` +
        `&apiKey=${encodeURIComponent(this.apiKey)}` +
        `&YourID=${encodeURIComponent(this.yourId)}` +
        `&id=${encodeURIComponent(id)}` +
        `&order_id=${encodeURIComponent(id)}`;

      const res = await axios.get(url, this.requestConfig());
      return classifyTgLionStatus(res.data);
    } catch (err: any) {
      return {
        state: 'unknown',
        raw: err?.response?.data || err?.message,
      };
    }
  }

  /**
   * إنهاء الطلب بعد وصول الكود بنجاح:
   */
  async markFinished(id: string): Promise<void> {
    try {
      const url =
        `${this.apiRoot}/?action=finish` +
        `&apiKey=${encodeURIComponent(this.apiKey)}` +
        `&YourID=${encodeURIComponent(this.yourId)}` +
        `&id=${encodeURIComponent(id)}` +
        `&order_id=${encodeURIComponent(id)}`;
      await axios.get(url, this.requestConfig());
    } catch {
      // إنهاء الطلب نجاحه غير حرِج لأن المزود يغلق بعد وصول الكود
    }
  }

  /**
   * إلغاء الرقم واسترداد الرصيد تلقائياً:
   */
  async cancelNumber(params: VirtualNumberCancelParams): Promise<void> {
    try {
      const url =
        `${this.apiRoot}/?action=cancel` +
        `&apiKey=${encodeURIComponent(this.apiKey)}` +
        `&YourID=${encodeURIComponent(this.yourId)}` +
        `&id=${encodeURIComponent(params.id)}` +
        `&order_id=${encodeURIComponent(params.id)}`;
      await axios.get(url, this.requestConfig());
    } catch (err: any) {
      this.logger.warn(`فشل إلغاء رقم TG-Lion #${params.id}: ${providerErrorMessage(err)}`);
    }
  }
}
