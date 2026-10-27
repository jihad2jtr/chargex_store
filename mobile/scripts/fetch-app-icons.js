// يجلب الأيقونة الحقيقية لكل منتج في الكتالوج ويكتبها في ../assets/icons/<slug>.png
//
// المصادر بالترتيب:
//   1) كتالوج أبل العام (itunes.apple.com/search) -> أيقونة التطبيق الأصلية 512×512
//   2) Iconify (logos/*) للشعارات الملوّنة التي لا تطبيق iOS لها (جوجل بلاي / آب ستور)
//   3) simple-icons: رمز العلامة بلونها الرسمي (فالورانت، ليغ أوف ليجندز، آي كلاود…)
//
// التشغيل من مجلد حزم مؤقت (المشروع الأساسي لا يعتمد على Node):
//   mkdir .icons-tmp && cd .icons-tmp && npm i sharp simple-icons && cd ..
//   node mobile/scripts/fetch-app-icons.js            # يُولّد ما ينقص فقط
//   node mobile/scripts/fetch-app-icons.js --clean    # يعيد توليد كل الأيقونات
// ويمكن تحديد مكان الحزم: set ICON_DEPS=<مسار>/node_modules
//
// أسماء الملفات تحمل أحد معنيين:
//   - اسم بطاقة موجودة في assets/cards  -> تُشتق أيقونتها تلقائياً في card_assets.dart
//   - اسم بلا بطاقة                     -> يُسجَّل في lib/core/constants/app_icon_assets.dart
//     (slug + اسم إنكليزي + اسم عربي + مرادفات) ليُحلّ شعاره بالاسم دون قاعدة بيانات
const fs = require('fs');
const path = require('path');

const DEPS =
  process.env.ICON_DEPS ||
  path.join(__dirname, '..', '..', '.icons-tmp', 'node_modules');
const sharp = require(path.join(DEPS, 'sharp'));

const OUT_DIR = path.join(__dirname, '..', 'assets', 'icons');
const SI_DIR = path.join(DEPS, 'simple-icons');
const SIZE = 256;
const HEADERS = { 'user-agent': 'Mozilla/5.0 (compatible; jgo-catalog-icons/1.0)' };

// slug البطاقة -> بحث في أبل + bundleId المراد مطابقته + (اختياري) متجر البلد
const APPLE = [
  ['pubg-mobile', 'PUBG MOBILE', 'com.tencent.ig'],
  ['free-fire', 'Free Fire', 'com.dts.freefireth'],
  ['call-of-duty-mobile', 'Call of Duty Mobile', 'com.activision.callofduty.shooter'],
  ['ea-sports-fc', 'EA SPORTS FC Mobile', 'com.ea.ios.fifamobile'],
  ['efootball', 'eFootball', 'jp.konami.pesactionmobile'],
  ['clash-of-clans', 'Clash of Clans', 'com.supercell.magic'],
  ['clash-royale', 'Clash Royale', 'com.supercell.scroll'],
  ['brawl-stars', 'Brawl Stars', 'com.supercell.laser'],
  ['roblox', 'Roblox', 'com.roblox.robloxmobile'],
  ['minecraft', 'Minecraft', 'com.mojang.minecraftpe'],
  ['fortnite', 'Fortnite', 'com.epicgames.fortnite'],
  ['mobile-legends', 'Mobile Legends Bang Bang', 'com.mobile.legends'],
  ['genshin-impact', 'Genshin Impact', 'com.miHoYo.GenshinImpact'],
  ['honkai-star-rail', 'Honkai Star Rail', 'com.hoyoverse.hkrpgoversea'],
  ['asphalt-9', 'Asphalt 9 Legends', 'com.gameloft.asphalt9'],
  ['among-us', 'Among Us', 'com.innersloth.amongus'],
  ['chatgpt', 'ChatGPT', 'com.openai.chat'],
  ['tiktok', 'TikTok', 'com.buzzfeed.tiktok'],
  ['snapchat', 'Snapchat', 'com.tsslag.mobile-teacher'],
  ['instagram', 'Instagram', 'com.burbn.instagram'],
  ['facebook', 'Facebook', 'com.facebook.Facebook'],
  ['whatsapp', 'WhatsApp Messenger', 'net.whatsapp.WhatsApp'],
  ['telegram', 'Telegram Messenger', 'ph.telegra.Telegraph'],
  ['discord', 'Discord', 'com.hammerandchisel.discord'],
  ['x', 'X', 'com.atebits.Tweetie2'],
  ['canva', 'Canva', 'com.canva.canvaeditor'],
  ['gmail', 'Gmail', 'com.google.Gmail'],
  ['playstation', 'PlayStation App', 'com.playstation.eu.playstationadhoc'],
  ['xbox', 'Xbox', 'com.microsoft.smartglass'],
  ['steam', 'Steam', 'com.valvesoftware.steam'],
  ['nintendo', 'Nintendo Switch App', 'com.nintendo.znca'],
  ['netflix', 'Netflix', 'com.netflix.NFLX'],
  ['youtube-premium', 'YouTube', 'com.google.YouTube'],
  ['spotify', 'Spotify', 'com.spotify.client'],

  // ===== ألعاب إضافية =====
  ['zenless-zone-zero', 'Zenless Zone Zero', 'com.hoyoverse.mirza'],
  ['wuthering-waves', 'Wuthering Waves', 'com.kurogame.wutheringwaves.global'],
  ['standoff-2', 'Standoff 2', 'com.axlebolt.standoff2'],
  ['honor-of-kings', 'Honor of Kings', 'com.levelinfinite.sgameGlobal'],
  ['delta-force', 'Delta Force', 'com.proxima.dfm'],
  ['free-fire-max', 'Free Fire MAX', 'com.dts.freefiremax'],
  ['arena-of-valor', 'Arena of Valor', 'com.ngame.allstar.eu'],
  ['arena-breakout', 'Arena Breakout', 'com.proximabeta.mf.uamo'],
  ['game-for-peace', 'Game for Peace', 'com.tencent.tmgp.pubgmhd', 'cn'],
  ['crossfire', 'CrossFire Legends', 'com.vnggames.cfl.crossfirelegends', 'vn'],
  ['battle-net', 'Battle.net', 'com.blizzard.social'],
  ['epic-games', 'Epic Games', 'com.epicgames.ega'],

  // ===== اشتراكات فيديو وموسيقى =====
  ['shahid', 'Shahid', 'net.mbc.shahid-iphone', 'ae'],
  ['osn-plus', 'OSN+', 'com.osn.go', 'ae'],
  ['anghami', 'Anghami', 'com.anghami.anghami', 'eg'],
  ['deezer', 'Deezer', 'com.deezer.Deezer'],
  ['apple-music', 'Apple Music', 'com.apple.Music'],
  ['apple-tv', 'Apple TV', 'com.apple.tv'],
  ['disney-plus', 'Disney+', 'com.disney.disneyplus'],
  ['hbo-max', 'Max', 'com.wbd.stream'],
  ['prime-video', 'Amazon Prime Video', 'com.amazon.aiv.AIVApp'],
  ['paramount-plus', 'Paramount+', 'com.cbsvideo.app'],
  ['starzplay', 'StarzPlay', 'com.parsifal.Starz', 'ae'],
  ['tod', 'TOD', 'com.todtv.tod', 'eg'],
  ['twitch', 'Twitch', 'tv.twitch'],
  ['youtube-music', 'YouTube Music', 'com.google.ios.youtubemusic'],

  // ===== ذكاء اصطناعي وخدمات =====
  ['claude', 'Claude', 'com.anthropic.claude'],
  ['gemini', 'Google Gemini', 'com.google.Gemini'],
  ['copilot', 'Microsoft Copilot', 'com.microsoft.officemobile'],
  ['grok', 'Grok', 'ai.x.GrokApp'],
  ['photoshop', 'Adobe Photoshop', 'com.adobe.photoshop.ios'],
  ['lightroom', 'Adobe Lightroom', 'com.adobe.lrmobilephone'],
  ['notion', 'Notion', 'notion.id'],
  ['nordvpn', 'NordVPN', 'com.nordvpn.NordVPN'],
  ['linkedin', 'LinkedIn', 'com.linkedin.LinkedIn'],
  ['careem', 'Careem', 'com.careem.mobile.app.icma'],
  ['talabat', 'talabat', 'com.6alabat.cuisineApp'],
  ['uber', 'Uber', 'com.ubercab.UberClient'],
  ['amazon', 'Amazon Shopping', 'com.amazon.Amazon'],
];

// شعار ملوّن رسمي من Iconify: [اسم الأيقونة، لون الخلفية]
const ICONIFY = {
  'google-play': ['logos/google-play-icon'],
  'app-store': ['logos/apple-app-store'],
  // لا تطبيق iOS لـ Creative Cloud: رمز العلامة الأبيض على الأحمر الرسمي
  'adobe-cc': ['simple-icons/adobecreativecloud', '#FA0F00'],
};

// رسم خاص: شعار مايكروسوفت بأربع مربّعات بألوانها الرسمية
// (بحث أبل عن microsoft-365 يعيد أيقونة Copilot لا حزمة 365)
const CUSTOM = ['microsoft-365'];

// رمز العلامة من simple-icons على خلفية بلونها الرسمي (بديل إن فشل أبل)
const SIMPLE = {
  'valorant': 'valorant',
  'league-of-legends': 'leagueoflegends',
  'icloud': 'icloud',
  'battle-net': 'battledotnet',
  'epic-games': 'epicgames',
  'ea-app': 'ea',
  'dota-2': 'dota2',
  'counter-strike-2': 'counterstrike',
  'apple-music': 'applemusic',
  'apple-tv': 'appletv',
  'kaspersky': 'kaspersky',
  'notion': 'notion',
  'nordvpn': 'nordvpn',
  'uber': 'uber',
  'hbo-max': 'max',
  'paramount-plus': 'paramountplus',
  'twitch': 'twitch',
  'deezer': 'deezer',
  'claude': 'anthropic',
  'gemini': 'googlegemini',
  'razer-gold': 'razer',
  'starzplay': 'starz',
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function writePng(buffer, slug) {
  await sharp(buffer, { failOn: 'none' })
    .resize(SIZE, SIZE, { fit: 'cover', position: 'centre' })
    .png({ compressionLevel: 9, effort: 8 })
    .toFile(path.join(OUT_DIR, `${slug}.png`));
}

async function fromApple(slug, term, bundle, country = 'us') {
  const url = `https://itunes.apple.com/search?term=${encodeURIComponent(term)}&media=software&limit=5&country=${country}`;
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) throw new Error(`أبل HTTP ${res.status}`);
  const results = (await res.json()).results || [];
  const hit =
    results.find((r) => (r.bundleId || '').toLowerCase() === bundle.toLowerCase()) || results[0];
  if (!hit || !hit.artworkUrl100) throw new Error('لا نتيجة في أبل');
  const matched = (hit.bundleId || '').toLowerCase() === bundle.toLowerCase();
  const art = hit.artworkUrl100.replace(/\/\d+x\d+bb\./, '/512x512bb.');
  const img = await fetch(art, { headers: HEADERS });
  if (!img.ok) throw new Error(`أيقونة HTTP ${img.status}`);
  await writePng(Buffer.from(await img.arrayBuffer()), slug);
  return `apple${matched ? '' : ` !bundle=${hit.bundleId}`}: ${hit.trackName}`;
}

async function fromIconify(slug, name, bg = '#FFFFFF') {
  // الأيقونات أحادية اللون تحتاج صيغة اللون صراحةً؛ الشعارات الملوّنة تتجاهلها
  const query = bg.toUpperCase() === '#FFFFFF' ? '' : '?color=white';
  const res = await fetch(
    `https://api.iconify.design/${name}.svg${query}`,
    { headers: HEADERS },
  );
  if (!res.ok) throw new Error(`iconify HTTP ${res.status}`);
  const raw = await res.text();
  const viewBox = (raw.match(/viewBox="([^"]+)"/) || [])[1];
  if (!viewBox) throw new Error('iconify: لا viewBox');
  const inner = raw.replace(/^[\s\S]*?>/, '').replace(/<\/svg>\s*$/, '');
  const scale = 0.62;
  const offset = SIZE * (1 - scale) * 0.5;
  const svg = `<svg width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" xmlns="http://www.w3.org/2000/svg">
<rect width="${SIZE}" height="${SIZE}" fill="${bg}"/>
<svg x="${offset}" y="${offset}" width="${SIZE * scale}" height="${SIZE * scale}" viewBox="${viewBox}">
${inner}</svg></svg>`;
  await sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(path.join(OUT_DIR, `${slug}.png`));
  return `iconify: ${name}${bg === '#FFFFFF' ? '' : ` on ${bg}`}`;
}

// شعار مايكروسوفت: أربع مربّعات بألوانها الرسمية على خلفية بيضاء
async function fromMicrosoftTiles(slug) {
  const svg = `<svg width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" xmlns="http://www.w3.org/2000/svg">
<rect width="${SIZE}" height="${SIZE}" fill="#FFFFFF"/>
<g transform="translate(${SIZE * 0.22} ${SIZE * 0.22}) scale(${(SIZE * 0.56) / 24})">
<rect x="1" y="1" width="10.5" height="10.5" fill="#F25022"/>
<rect x="12.5" y="1" width="10.5" height="10.5" fill="#7FBA00"/>
<rect x="1" y="12.5" width="10.5" height="10.5" fill="#00A4EF"/>
<rect x="12.5" y="12.5" width="10.5" height="10.5" fill="#FFB900"/>
</g></svg>`;
  await sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(path.join(OUT_DIR, `${slug}.png`));
  return 'microsoft 4-square';
}

function simpleColor(slug) {
  const data = JSON.parse(fs.readFileSync(path.join(SI_DIR, 'data', 'simple-icons.json'), 'utf8'));
  const rec = data.find((d) => d.slug === slug);
  return rec ? `#${rec.hex}` : '#0F172A';
}

async function fromSimpleIcons(slug, name) {
  const svg = fs.readFileSync(path.join(SI_DIR, 'icons', `${name}.svg`), 'utf8');
  const d = (svg.match(/\sd="([^"]+)"/) || [])[1];
  if (!d) throw new Error(`simple-icons: لا مسار في ${name}.svg`);
  const bg = simpleColor(name);
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

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  // --clean: إعادة توليد كل شيء من الصفر (يمحو الملفات القديمة قبل الجلب)
  if (process.argv.includes('--clean')) {
    for (const f of fs.readdirSync(OUT_DIR)) {
      if (f.endsWith('.png')) fs.rmSync(path.join(OUT_DIR, f), { force: true });
    }
    console.log('CLEAN: تم محو ملفات assets/icons السابقة');
  }
  const done = [];
  const failed = [];

  for (const [slug, term, bundle, country] of APPLE) {
    try {
      done.push(`${slug.padEnd(22)} ${await fromApple(slug, term, bundle, country)}`);
    } catch (e) {
      failed.push(`${slug}: ${e.message}`);
    }
    await sleep(180);
  }

  for (const [slug, [name, bg]] of Object.entries(ICONIFY)) {
    try {
      done.push(`${slug.padEnd(22)} ${await fromIconify(slug, name, bg)}`);
    } catch (e) {
      failed.push(`${slug} (iconify): ${e.message}`);
    }
    await sleep(120);
  }

  for (const slug of CUSTOM) {
    try {
      done.push(`${slug.padEnd(22)} ${await fromMicrosoftTiles(slug)}`);
    } catch (e) {
      failed.push(`${slug} (custom): ${e.message}`);
    }
  }

  for (const [slug, name] of Object.entries(SIMPLE)) {
    if (fs.existsSync(path.join(OUT_DIR, `${slug}.png`))) continue;
    try {
      done.push(`${slug.padEnd(22)} ${await fromSimpleIcons(slug, name)}`);
    } catch (e) {
      failed.push(`${slug} (simple-icons): ${e.message}`);
    }
  }

  const files = fs.readdirSync(OUT_DIR).filter((f) => f.endsWith('.png'));
  const kb = Math.round(files.reduce((s, f) => s + fs.statSync(path.join(OUT_DIR, f)).size, 0) / 1024);
  console.log(done.join('\n'));
  console.log(`\nfiles=${files.length} totalKB=${kb}`);
  if (failed.length) console.log('--- FAILED ---\n' + failed.join('\n'));
})().catch((e) => {
  console.error('FATAL:', e.message);
  process.exit(1);
});
