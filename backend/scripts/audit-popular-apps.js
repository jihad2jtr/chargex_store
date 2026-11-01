/**
 * تدقيق قائمة المشهورات: لكل تطبيق من الـ200 — أيقونته موجودة في أصول الموبايل،
 * ورمزها متوفر لدى كل مزود ثابت الأكواد (Hero-SMS و5sim). SMSPool وDogeSMS
 * يُخزّنان رمزيهما الحيّين في لقطة الكتالوج، فلا حاجة لحقل معجمي لهما.
 *
 * التشغيل: node scripts/audit-popular-apps.js   (من مجلد backend)
 */
const fs = require('fs');
const path = require('path');

const dictSrc = fs.readFileSync(
  path.join(__dirname, '../src/modules/virtual-numbers/virtual-numbers-dictionary.ts'),
  'utf8',
);
const popularSrc = fs.readFileSync(
  path.join(__dirname, '../src/modules/virtual-numbers/popular-apps.ts'),
  'utf8',
);
const iconsDir = path.join(__dirname, '../../mobile/assets/icons');

// مفاتيح المشهورات الـ200 (سطر 'key', لكل مدخل)
const popularKeys = [...popularSrc.matchAll(/^  '([a-z0-9_]+)',/gm)].map((m) => m[1]);

// وثائق المعجم: سطر واحد لكل مدخل { key: ... }
const appLines = dictSrc
  .slice(
    dictSrc.indexOf('VIRTUAL_NUMBER_APPS'),
    dictSrc.indexOf('export const VIRTUAL_NUMBER_COUNTRIES'),
  )
  .match(/^[ \t]*\{ key: .*$/gm);
const byKey = new Map();
for (const line of appLines) {
  const key = (line.match(/key: '([^']*)'/) || [])[1];
  const icon = (line.match(/icon: '([^']*)'/) || [])[1];
  const herosmsCode = (line.match(/herosmsCode: '([^']*)'/) || [])[1];
  const fivesimCode = (line.match(/fivesimCode: '([^']*)'/) || [])[1];
  if (key) byKey.set(key, { icon: icon || '', herosmsCode: herosmsCode || '', fivesimCode: fivesimCode || '' });
}

const iconFiles = new Set(fs.readdirSync(iconsDir));

// تطبيقات المشهورات غير مقدَّمة من 5sim حيّاً (تحقّق بتاريخ 2026-10-31 عبر
// GET https://5sim.net/v1/guest/prices — قائمة الأكواد الحيّة كاملة).
// بأكوادها الحالية تبقى بلا خدمة 5sim حتى تُدرَج، وهذا مقصود لا انجراف.
const FIVESIM_NOT_OFFERED = new Set([
  'mailru', 'yandex', 'vonage', 'textfree', 'keepcalling', 'autodesk', 'docusign',
  'firebase', 'hostinger', 'disneyplus', 'funpay', 'binance', 'mexc', 'traderepublic',
  'etoro', 'monzo', 'chime', 'bunq', 'paysera', 'sumup', 'square', 'capitalone',
  'klarna', 'phonepe', 'bharatpe', 'ovo', 'truemoney', 'fawry', 'letgo',
  'kleinanzeigen', 'sahibinden', 'bookingcom', 'fastwork', 'whoosh',
]);

const noDictEntry = [];
const noIcon = []; // أيقونة فارغة أو الملف غير موجود
const noHerosms = [];
const noFivesim = []; // خارج قائمة غير المقدَّم — يستوجب رمزاً أو تبريراً
const fivesimNotOffered = [];

for (const key of popularKeys) {
  const meta = byKey.get(key);
  if (!meta) {
    noDictEntry.push(key);
    continue;
  }
  const iconFile = meta.icon ? path.basename(meta.icon) : '';
  if (!meta.icon || iconFile === 'other' || !iconFiles.has(iconFile)) {
    noIcon.push(`${key} (icon='${meta.icon || '<empty>'}')`);
  }
  if (!meta.herosmsCode) noHerosms.push(key);
  if (!meta.fivesimCode) {
    (FIVESIM_NOT_OFFERED.has(key) ? fivesimNotOffered : noFivesim).push(key);
  }
}

console.log(`popular keys: ${popularKeys.length}`);
console.log(`\n[1] بلا مدخل معجم (${noDictEntry.length}):\n  ${noDictEntry.join(', ') || '-'}`);
console.log(`\n[2] أيقونة مفقودة أو ملف غير موجودة (${noIcon.length}):\n  ${noIcon.join('\n  ') || '-'}`);
console.log(`\n[3] بلا رمز Hero-SMS (${noHerosms.length}):\n  ${noHerosms.join(', ') || '-'}`);
console.log(`\n[4] بلا رمز 5sim خارج القائمة الموثَّقة (${noFivesim.length}):\n  ${noFivesim.join(', ') || '-'}`);
console.log(`\n[4ب] غير مقدَّم من 5sim (موثَّق من الكتالوج الحيّ, ${fivesimNotOffered.length}):\n  ${fivesimNotOffered.join(', ') || '-'}`);

// ملفات الأيقونات المتاحة التي لا تُطابق اسماً في القائمة الناقصة: للمساعدة في الإكمال
console.log(`\n[5] أيقونات الموبايل المتاحة (${iconFiles.size}):`);
console.log(`  ${[...iconFiles].sort().join(', ')}`);
