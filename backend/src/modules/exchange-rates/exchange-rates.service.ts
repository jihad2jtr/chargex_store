import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import axios from 'axios';
import { ExchangeRate, ExchangeRateDocument } from '../../database/schemas/exchange-rate.schema';

// مصدر سعر الصرف: الدولار مقابل الليرة السورية
const SOURCE_URL = 'https://liranews.info/api/public/v1/price/usdsypd';
const PAIR = 'usdsypd';

// المصدر ينشر السعر بالليرة السورية الجديدة (حُذف منها آخر صفرين)،
// أي 1 دولار = 143.5 ل.س مباشرة — فلا حاجة لأي معامل تحويل.
const RATE_SCALE = 1;

// التحديث اليومي: فحص كل ساعة، وتحديث فعلي فقط إذا مرّت 24 ساعة على آخر جلب
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const CHECK_INTERVAL_MS = 60 * 60 * 1000;
const FETCH_TIMEOUT_MS = 12000;

@Injectable()
export class ExchangeRatesService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ExchangeRatesService.name);
  private isRefreshing = false;
  private timer?: ReturnType<typeof setInterval>;

  constructor(
    @InjectModel(ExchangeRate.name) private rateModel: Model<ExchangeRateDocument>,
  ) {}

  onModuleInit() {
    // أول جلب بعد إقلاع الخادم بقليل (حتى لا يعطّل البدء) ثم فحص دوري كل ساعة
    setTimeout(() => {
      void this.refreshIfStale().catch(() => undefined);
    }, 4000);
    this.timer = setInterval(() => {
      void this.refreshIfStale().catch(() => undefined);
    }, CHECK_INTERVAL_MS);
    // لا نُبقي عملية Node حيّة بسبب المؤقّت
    if (typeof (this.timer as unknown as { unref?: () => void })?.unref === 'function') {
      (this.timer as unknown as { unref: () => void }).unref();
    }
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  private isStale(doc: any): boolean {
    const last = doc?.fetchedAt ?? doc?.updatedAt;
    if (!last) return true;
    const time = new Date(last).getTime();
    return !Number.isFinite(time) || Date.now() - time > ONE_DAY_MS;
  }

  private toDto(doc: any) {
    const rate = Number(doc?.rate) || 0;
    const previousRate = Number(doc?.previousRate) || 0;
    const change = previousRate > 0 ? Number((rate - previousRate).toFixed(2)) : 0;
    const changePercent =
      previousRate > 0 ? Number(((change / previousRate) * 100).toFixed(2)) : 0;

    return {
      pair: doc?.pair ?? PAIR,
      rate,
      buy: Number(doc?.buy) || 0,
      sell: Number(doc?.sell) || 0,
      previousRate: previousRate > 0 ? previousRate : null,
      change,
      changePercent,
      source: doc?.source ?? 'liranews',
      sourceUrl: doc?.sourceUrl ?? SOURCE_URL,
      sourceUpdatedAt: doc?.sourceUpdatedAt ?? null,
      fetchedAt: doc?.fetchedAt ?? null,
      updatedAt: doc?.updatedAt ?? doc?.fetchedAt ?? null,
      stale: this.isStale(doc),
    };
  }

  /** آخر سعر محفوظ — ويُجلب من المصدر فوراً إن لم يوجد أي مستند بعد */
  async getCurrent() {
    const doc = await this.rateModel.findOne({ pair: PAIR }).sort({ updatedAt: -1 });

    if (!doc) {
      return this.refresh();
    }

    // السعر أقدم من 24 ساعة: نجلب في الخلفية ونعيد المحفوظ مباشرة
    if (this.isStale(doc)) {
      void this.refresh().catch(() => undefined);
    }
    return this.toDto(doc);
  }

  /** تحديث يومي: لا يلمس المصدر إلا إذا مرّت 24 ساعة على آخر جلب */
  async refreshIfStale() {
    const doc = await this.rateModel.findOne({ pair: PAIR }).sort({ updatedAt: -1 });
    if (doc && !this.isStale(doc)) return this.toDto(doc);
    return this.refresh();
  }

  /** جلب سعر الصرف من liranews وتخزينه في قاعدة البيانات */
  async refresh() {
    if (this.isRefreshing) return null;
    this.isRefreshing = true;

    try {
      const response = await axios.get(SOURCE_URL, {
        timeout: FETCH_TIMEOUT_MS,
        headers: { Accept: 'application/json' },
      });

      const payload = response?.data?.usdsypd ?? response?.data;
      const rawValue = Number(payload?.sell ?? payload?.value);
      if (!Number.isFinite(rawValue) || rawValue <= 0) {
        throw new Error('قيمة سعر الصرف غير صالحة في رد المصدر');
      }

      const rate = Number((rawValue * RATE_SCALE).toFixed(2));
      const previous = await this.rateModel
        .findOne({ pair: PAIR })
        .sort({ updatedAt: -1 });

      const doc = await this.rateModel.findOneAndUpdate(
        { pair: PAIR },
        {
          $set: {
            pair: PAIR,
            rate,
            rawRate: rawValue,
            buy: Number(payload?.buy) || 0,
            sell: Number(payload?.sell ?? payload?.value) || rawValue,
            previousRate: Number(previous?.rate) || 0,
            source: 'liranews',
            sourceUrl: SOURCE_URL,
            sourceUpdatedAt: payload?.price_updated_at
              ? new Date(payload.price_updated_at)
              : new Date(),
            fetchedAt: new Date(),
          },
        },
        { new: true, upsert: true, setDefaultsOnInsert: true },
      );

      this.logger.log(`تم تحديث سعر الصرف: 1 USD = ${rate} SYP`);
      return doc ? this.toDto(doc) : null;
    } catch (error) {
      this.logger.warn(`تعذر جلب سعر الصرف من المصدر: ${(error as Error).message}`);
      throw error;
    } finally {
      this.isRefreshing = false;
    }
  }
}
