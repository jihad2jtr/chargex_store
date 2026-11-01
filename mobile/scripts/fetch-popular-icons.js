// تولّد أيقونات تطبيقات الأرقام المشهورة الناقصة (قائمة الـ200 في الباك إند)
//
// لكل مفتاح بلا أيقونة في المعجم تُجرّب بالترتيب، ثم تُكتب النتائج:
//   1) ملف موجود مسبقاً في assets/icons باسم منسّم مطابق (epicgames ← epic-games.png)
//   2) simple-icons: رمز العلامة على خلفية بلونها الرسمي (نفس وصفة الأنبوب الأصلي)
//   3) iTunes Search بالاسم الإنكليزي (بديل ما لا slug له في simple-icons)
//
// التشغيل (من أي مكان؛ الحزم من .icons-tmp كما في fetch-app-icons.js):
//   node mobile/scripts/fetch-popular-icons.js              # توليد فقط
//   node mobile/scripts/fetch-popular-icons.js --write-dict # + تعبئة حقل icon في المعجم
const fs = require('fs');
const path = require('path');

const DEPS =
  process.env.ICON_DEPS ||
  path.join(__dirname, '..', '..', '.icons-tmp', 'node_modules');
const sharp = require(path.join(DEPS, 'sharp'));

const OUT_DIR = path.join(__dirname, '..', 'assets', 'icons');
const SI_DIR = path.join(DEPS, 'simple-icons');
const POPULAR_TS = path.join(
  __dirname, '..', '..', 'backend', 'src', 'modules', 'virtual-numbers', 'popular-apps.ts',
);
const DICT_TS = path.join(
  __dirname, '..', '..', 'backend', 'src', 'modules', 'virtual-numbers', 'virtual-numbers-dictionary.ts',
);
const SIZE = 256;
const HEADERS = { 'user-agent': 'Mozilla/5.0 (compatible; jgo-catalog-icons/1.0)' };

// معجم المفتاح -> slug في simple-icons حين لا يطابق الاسم آلياً
const OVERRIDES = {
  whatsappbusiness: 'whatsapp',
  instagramthreads: 'instagram',
  tiktokdouyin: 'tiktok',
  twitterx: 'x',
  googleyoutubegmail: 'google',
  linemessenger: 'line',
  vkcom: 'vk',
  pofcom: 'plentyoffish',
  disneyplus: 'disney',
  hepsiburadacom: 'hepsiburada',
  mercado: 'mercadolibre',
  cryptocom: 'cryptodotcom',
  bookingcom: 'bookingdotcom',
  tencentqq: 'qq',
  warpcast: 'warpcast',
  trip: 'tripdotcom',
};

// بحث أبل بصيغة أدق: [مصطلح البحث, متجر البلد] حين الاسم المعجمي لا يطابق
const APPLE_HINT = {
  hepsiburadacom: ['Hepsiburada', 'tr'],
  trendyol: ['Trendyol', 'tr'],
  getir: ['Getir', 'tr'],
  papara: ['Papara', 'tr'],
  truemoney: ['TrueMoney', 'th'],
  gcash: ['GCash', 'ph'],
  flipkart: ['Flipkart', 'in'],
  traderepublic: ['Trade Republic', 'de'],
  funpay: ['FunPay', 'us'],
  letgo: ['Letgo', 'us'],
  bharatpe: ['BharatPe', 'in'],
  indriver: ['inDrive', 'us'],
  olacabs: ['Ola', 'in'],
  touchngotng: ['Touch n Go eWallet', 'my'],
  wildberries: ['Wildberries', 'ru'],
  ozon: ['OZON', 'ru'],
  yandex: ['Yandex Go', 'ru'],
  bolt: ['Bolt', 'ee'],
};

// روابط رسمية أخيرة: تطبيقات ويب بلا متجر (favicon/touch-icon من موقعها الرسمي)
const FINAL_SITE = {
  funpay: 'https://funpay.com',
  codashop: 'https://www.codashop.com',
  bolt: 'https://bolt.eu',
};

// شعار SVG رسمي مسطّل لتطبيقات لا أيقونة متجر لها إطلاقاً
const FINAL_SVG = {
  funpay: { url: 'https://funpay.com/img/layout/logo-funpay.svg', bg: '#FFFFFF' },
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) =>
  (s || '').toLowerCase().replace(/[^a-z0-9\u0600-\u06ff]/g, '');

// مفاتيح المشهورات الـ200 من مصدر القائمة في الباك إند
const popularKeys = [...fs.readFileSync(POPULAR_TS, 'utf8').matchAll(/^  '([a-z0-9_]+)',/gm)]
  .map((m) => m[1]);

// مدخلات المعجم: key -> { icon, nameEn } (كل مدخل في سطر واحد)
const dictSrc = fs.readFileSync(DICT_TS, 'utf8');
const appLines = dictSrc
  .slice(dictSrc.indexOf('VIRTUAL_NUMBER_APPS'), dictSrc.indexOf('export const VIRTUAL_NUMBER_COUNTRIES'))
  .match(/^[ \t]*\{ key: .*$/gm) || [];
const dict = new Map();
for (const line of appLines) {
  const key = (line.match(/key: '([^']*)'/) || [])[1];
  if (!key) continue;
  dict.set(key, {
    icon: (line.match(/icon: '([^']*)'/) || [])[1] || '',
    nameEn: (line.match(/nameEn: '([^']*)'/) || [])[1] || key,
  });
}

const files = fs.readdirSync(OUT_DIR).filter((f) => f.endsWith('.png'));
// الملفات المسماة على اسم العلامة: مطابقة منسّمة (dash-insensitive)
const fileByNorm = new Map(files.map((f) => [norm(f.replace(/\.png$/, '')), f]));

const siData = JSON.parse(
  fs.readFileSync(path.join(SI_DIR, 'data', 'simple-icons.json'), 'utf8'),
);
const siByNorm = new Map();
for (const rec of siData) {
  siByNorm.set(norm(rec.slug), rec.slug);
  siByNorm.set(norm(rec.title), rec.slug);
}

function simpleColorHex(slug) {
  const rec = siData.find((d) => d.slug === slug);
  return rec ? `#${rec.hex}` : '#0F172A';
}

async function fromSimpleIcons(slug, name) {
  const svg = fs.readFileSync(path.join(SI_DIR, 'icons', `${name}.svg`), 'utf8');
  const d = (svg.match(/\sd="([^"]+)"/) || [])[1];
  if (!d) throw new Error(`simple-icons: لا مسار في ${name}.svg`);
  const bg = simpleColorHex(name);
  const hex = bg.replace('#', '');
  const n = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex;
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255);
  const fg = 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.6 ? '#111827' : '#FFFFFF';
  const scale = 0.6;
  const offset = SIZE * (1 - scale) * 0.5;
  const tile = `<svg width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" xmlns="http://www.w3.org/2000/svg">
<rect width="${SIZE}" height="${SIZE}" fill="${bg}"/>
<svg x="${offset}" y="${offset}" width="${SIZE * scale}" height="${SIZE * scale}" viewBox="0 0 24 24">
<path d="${d}" fill="${fg}"/></svg></svg>`;
  await sharp(Buffer.from(tile)).png({ compressionLevel: 9 }).toFile(path.join(OUT_DIR, `${slug}.png`));
  return `simple-icons: ${name}.svg (${bg})`;
}

async function fromApple(slug, term, country = 'us') {
  const url = `https://itunes.apple.com/search?term=${encodeURIComponent(term)}&media=software&limit=8&country=${country}`;
  // إعادة واحدة بعد 1.5 ثوانٍ: أبل ترمي 403/429 عابرة تحت التسلسل السريع
  let res;
  for (let attempt = 0; ; attempt++) {
    res = await fetch(url, { headers: HEADERS });
    if (res.ok || attempt >= 1) break;
    await sleep(1500);
  }
  if (!res.ok) throw new Error(`أبل HTTP ${res.status}`);
  const results = (await res.json()).results || [];
  // تطابق صارم: اسم النتيجة يجب أن يحمل المصطلح (أو العكس) — بلا أيقونة خاطئة
  const want = norm(term);
  const hit =
    results.find(
      (r) => norm(r.trackName).includes(want) || want.includes(norm(r.trackName)),
    ) || null;
  if (!hit || !hit.artworkUrl100) throw new Error('لا نتيجة مطابقة في أبل');
  const art = hit.artworkUrl100.replace(/\/\d+x\d+bb\./, '/512x512bb.');
  const img = await fetch(art, { headers: HEADERS });
  if (!img.ok) throw new Error(`أيقونة HTTP ${img.status}`);
  await sharp(Buffer.from(await img.arrayBuffer()), { failOn: 'none' })
    .resize(SIZE, SIZE, { fit: 'cover', position: 'centre' })
    .png({ compressionLevel: 9, effort: 8 })
    .toFile(path.join(OUT_DIR, `${slug}.png`));
  return `apple(${country}): ${hit.trackName}`;
}

// لقطة المصدر من موقع رسمي: يجرّب apple-touch-icon ثم /favicon.png ثم الشريط <link>
async function fromSite(slug, base) {
  const tries = [
    `${base.replace(/\/$/, '')}/apple-touch-icon.png`,
    `${base.replace(/\/$/, '')}/favicon.png`,
  ];
  let html = '';
  try {
    const page = await fetch(base, { headers: HEADERS });
    if (page.ok) html = await page.text();
  } catch {
    /* الموقع حالل دون إحباط */
  }
  const link = html.match(/<link[^>]+apple-touch-icon[^>]+href="([^"]+)"/i);
  const candidates = [
    ...(link ? [new URL(link[1], base).href] : []),
    ...tries,
  ];
  for (const url of candidates) {
    try {
      const img = await fetch(url, { headers: HEADERS });
      if (!img.ok) continue;
      const buf = Buffer.from(await img.arrayBuffer());
      if (buf.length < 512) continue; // أيقونات بالية صغيرة جداً
      await sharp(buf, { failOn: 'none' })
        .resize(SIZE, SIZE, { fit: 'contain', position: 'centre', background: '#0F172A' })
        .png({ compressionLevel: 9, effort: 8 })
        .toFile(path.join(OUT_DIR, `${slug}.png`));
      return `site: ${url}`;
    } catch {
      /* متابعة المصدر التالي */
    }
  }
  throw new Error('لا أيقونة في الموقع الرسمي');
}

// بلاط شعار SVG رسمي: viewBox الأصلي موسّط على خلفية معلّمة
async function fromSvgTile(slug, url, bg) {
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) throw new Error(`svg HTTP ${res.status}`);
  const raw = await res.text();
  const viewBox = (raw.match(/viewBox="([^"]+)"/) || [])[1];
  if (!viewBox) throw new Error('svg: لا viewBox');
  const [, , vw, vh] = viewBox.split(/[\s,]+/).map(Number);
  const inner = raw.replace(/^[\s\S]*?>/, '').replace(/<\/svg>\s*$/, '');
  const w = SIZE * 0.78;
  const h = (w * vh) / vw;
  const tile = `<svg width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" xmlns="http://www.w3.org/2000/svg">
<rect width="${SIZE}" height="${SIZE}" fill="${bg}"/>
<svg x="${(SIZE - w) / 2}" y="${(SIZE - h) / 2}" width="${w}" height="${h}" viewBox="${viewBox}">
${inner}</svg></svg>`;
  await sharp(Buffer.from(tile)).png({ compressionLevel: 9 }).toFile(path.join(OUT_DIR, `${slug}.png`));
  return `svg-tile: ${url}`;
}

(async () => {
  const writeDict = process.argv.includes('--write-dict');
  const reused = [];
  const generated = {}; // key -> 'assets/icons/<file>.png'
  const unmatched = [];
  const failed = [];

  for (const key of popularKeys) {
    const meta = dict.get(key);
    if (!meta) {
      failed.push(`${key}: لا مدخل في المعجم`);
      continue;
    }
    // أيقونة المعجم تشير لملف موجود أصلاً: لا عمل هنا
    if (
      meta.icon.startsWith('assets/icons/') &&
      fs.existsSync(path.join(__dirname, '..', '..', 'mobile', meta.icon))
    ) {
      reused.push(`${key}: ${meta.icon} (مثبّتة)`);
      continue;
    }
    // 1) ملف قائم باسم منسّم مطابق
    const existing = fileByNorm.get(norm(key));
    if (existing) {
      generated[key] = `assets/icons/${existing}`;
      continue;
    }
    // 2) simple-icons بالمطابقة الآلية أو بالتجاوز الصريح
    const si = OVERRIDES[key] ? siByNorm.get(norm(OVERRIDES[key])) || OVERRIDES[key]
      : siByNorm.get(norm(key));
    if (si && fs.existsSync(path.join(SI_DIR, 'icons', `${si}.svg`))) {
      try {
        generated[key] = `assets/icons/${key}.png (${await fromSimpleIcons(key, si)})`;
      } catch (e) {
        failed.push(`${key} (simple-icons): ${e.message}`);
      }
      await sleep(60);
      continue;
    }
    // 3) أبل بالاسم الإنكليزي المعجمي (أو بصيغة APPLE_HINT حين تدعو الحاجة)
    const [term, country] = APPLE_HINT[key] || [meta.nameEn || key, 'us'];
    try {
      generated[key] = `assets/icons/${key}.png (${await fromApple(key, term, country)})`;
    } catch (e) {
      // 4) موقع رسمي أخير لتطبيقات الويب بلا متجر (FINAL_SITE فقط)
      let done = false;
      if (FINAL_SITE[key]) {
        try {
          generated[key] = `assets/icons/${key}.png (${await fromSite(key, FINAL_SITE[key])})`;
          done = true;
        } catch (e2) {
          failed.push(`${key} (موقع رسمي): ${e2.message}`);
        }
      }
      // 5) بلاط شعار SVG رسمي (FINAL_SVG) كآخر ملاذ
      if (!done && FINAL_SVG[key]) {
        try {
          generated[key] = `assets/icons/${key}.png (${await fromSvgTile(key, FINAL_SVG[key].url, FINAL_SVG[key].bg)})`;
          done = true;
        } catch (e3) {
          failed.push(`${key} (شعار SVG): ${e3.message}`);
        }
      }
      if (!done) unmatched.push(`${key} (لا simple-icons ولا أبل: ${e.message})`);
    }
    await sleep(700);
  }

  console.log(`reused=${reused.length} generated=${Object.keys(generated).length} unmatched=${unmatched.length}`);
  for (const g of Object.entries(generated)) console.log(`  GEN ${g[0]} -> ${g[1]}`);
  if (unmatched.length) console.log('  UNMATCHED:\n    ' + unmatched.join('\n    '));
  if (failed.length) console.log('  FAILED:\n    ' + failed.join('\n    '));

  // --write-dict: تعبئة حقل icon في المعجم للمفاتيح التي صار لها ملف
  if (!writeDict) return;
  let src = fs.readFileSync(DICT_TS, 'utf8');
  let written = 0;
  for (const [key, desc] of Object.entries(generated)) {
    const file = desc.split(' ')[0]; // 'assets/icons/<key>.png'
    const lineRe = new RegExp(`^([ \\t]*\\{ key: '${key}'.*?)icon: ''`, 'm');
    if (lineRe.test(src)) {
      src = src.replace(lineRe, `$1icon: '${file}'`);
      written += 1;
    }
  }
  fs.writeFileSync(DICT_TS, src);
  console.log(`dict icons written: ${written}`);
})().catch((e) => {
  console.error('FATAL:', e.message);
  process.exit(1);
});
