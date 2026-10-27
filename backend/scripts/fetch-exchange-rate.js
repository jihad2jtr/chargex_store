/**
 * سكريبت جلب سعر صرف الليرة السورية مقابل الدولار من liranews وتخزينه في MongoDB.
 *
 * التشغيل اليدوي:
 *   npm run fetch-rate
 *
 * الجدولة اليومية على السيرفر (cron — مثال الساعة 8 صباحاً):
 *   0 8 * * * cd /path/to/backend && npm run fetch-rate >> logs/exchange-rate.log 2>&1
 *
 * ملاحظة: خادم NestJS نفسه يجدّد السعر تلقائياً مرة كل 24 ساعة،
 * وهذا السكريبت للتشغيل اليدوي أو للجدولة الخارجية عبر cron.
 */

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const mongoose = require('mongoose');

const SOURCE_URL = 'https://liranews.info/api/public/v1/price/usdsypd';
const PAIR = 'usdsypd';
// المصدر ينشر السعر بالليرة السورية الجديدة (بعد حذف آخر صفرين): 143.5 ل.س
const RATE_SCALE = 1;
const DEFAULT_URI =
  'mongodb+srv://jihad2jus:l9GrLciVEUvvK8Fd@jihad.8dyvx.mongodb.net/jgo?retryWrites=true&w=majority&appName=jihad';

// قراءة .env يدوياً كي يعمل السكريبت بدون ts-node أو حزم إضافية
function readEnvFile() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) return {};
  const values = {};
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/);
    if (!match) continue;
    values[match[1]] = match[2].replace(/^['"]|['"]$/g, '').trim();
  }
  return values;
}

// نفس اسم الموديل => نفس اسم المجموعة (exchangerates) المستخدم في التطبيق
const rateSchema = new mongoose.Schema(
  {
    pair: { type: String, required: true, trim: true, unique: true, default: PAIR },
    rate: { type: Number, required: true },
    rawRate: { type: Number, default: 0 },
    buy: { type: Number, default: 0 },
    sell: { type: Number, default: 0 },
    previousRate: { type: Number, default: 0 },
    source: { type: String, trim: true, default: 'liranews' },
    sourceUrl: { type: String, trim: true, default: '' },
    sourceUpdatedAt: { type: Date },
    fetchedAt: { type: Date },
  },
  { timestamps: true },
);

const ExchangeRate =
  mongoose.models.ExchangeRate || mongoose.model('ExchangeRate', rateSchema);

async function main() {
  const env = { ...readEnvFile(), ...process.env };
  const uri = env.MONGODB_URI || DEFAULT_URI;

  console.log(`-> جلب سعر الصرف من ${SOURCE_URL}`);
  const { data } = await axios.get(SOURCE_URL, {
    timeout: 15000,
    headers: { Accept: 'application/json' },
  });

  const payload = (data && data.usdsypd) || data;
  const rawValue = Number(payload && (payload.sell !== undefined ? payload.sell : payload.value));
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    throw new Error('قيمة سعر الصرف غير صالحة في رد المصدر');
  }

  const rate = Number((rawValue * RATE_SCALE).toFixed(2));
  console.log(`   قيمة المصدر: ${rawValue} x${RATE_SCALE} = ${rate} ل.س`);

  await mongoose.connect(uri, { serverSelectionTimeoutMS: 10000 });

  const previous = await ExchangeRate.findOne({ pair: PAIR }).sort({ updatedAt: -1 });
  const doc = await ExchangeRate.findOneAndUpdate(
    { pair: PAIR },
    {
      $set: {
        pair: PAIR,
        rate,
        rawRate: rawValue,
        buy: Number(payload.buy) || 0,
        sell: Number(payload.sell !== undefined ? payload.sell : payload.value) || rawValue,
        previousRate: Number(previous && previous.rate) || 0,
        source: 'liranews',
        sourceUrl: SOURCE_URL,
        sourceUpdatedAt: payload.price_updated_at
          ? new Date(payload.price_updated_at)
          : new Date(),
        fetchedAt: new Date(),
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  console.log(`-> تم الحفظ في قاعدة البيانات: 1 USD = ${doc.rate} SYP`);
  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error(`!! فشل جلب سعر الصرف: ${error.message}`);
  try {
    await mongoose.disconnect();
  } catch (_) {
    /* تجاهل */
  }
  process.exit(1);
});
