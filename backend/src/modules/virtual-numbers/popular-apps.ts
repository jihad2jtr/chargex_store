/**
 * قائمة التطبيقات المشهورة المعتمدة (Top-200 Popular Apps)
 *
 * كتالوجات مزودي الأرقام الوهمية تحوي مئات الخدمات (5sim وحدها تُرجع أكثر من
 * 500 خدمة)، وشاشات الإدارة والعميل تغرق حين تُعرض كلها. هذه القائمة تُثبّت
 * سقفًا واحدًا: 200 تطبيقاً فقط، هي الأشهر عالمياً والإقليميّة (مراعيةً
 * الجمهور العربي: تالباط وكيطة ونون ويالا وبوتايم ضمن المشهورات).
 *
 * صارت هذه القائمة بذراً أولياً لمعجم المتاح في قاعدة البيانات
 * (VirtualNumberDictionary / صفحة «معجم التطبيقات»): تُدرج مرة واحدة عند أول
 * قراءة، ثم يتولى المعجم في اللوحة بوابة «ما يظهر للمزودين والعميل» — لا هذه
 * القائمة الثابتة. يُستعمل isPopularApp هنا للبذر والاختبارات فقط.
 *
 * المفاتيح كلها مطابقة لـ `key` في VIRTUAL_NUMBER_APPS (قاموس المعجم)، فالتطابق
 * يتم بالمفتاح المنطقي الموحّد لا برمز المزود: نفس التطبيق يبقى واحداً ولو اختلف
 * رمزه لدى Hero-SMS و5sim. الترتيب هنا هو ترتيب الشهرة نفسه، ويُستعمل لتثبيت
 * ترتيب الشبكة بلا اعتماد على sortOrder المخزّن.
 */

import { resolveAppMeta } from './virtual-numbers-dictionary';

export const POPULAR_APP_KEYS: string[] = [
  // —— مراسلة وتواصل اجتماعي (28)
  'whatsapp',
  'whatsappbusiness',
  'telegram',
  'facebook',
  'instagramthreads',
  'tiktokdouyin',
  'twitterx',
  'snapchat',
  'discord',
  'imo',
  'viber',
  'signal',
  'linemessenger',
  'kakaotalk',
  'wechat',
  'zalo',
  'reddit',
  'nextdoor',
  'groupme',
  'botim',
  'truthsocial',
  'clubhouse',
  'warpcast',
  'redbook',
  'meta',
  'vkcom',
  'weibo',
  'yalla',
  // —— حسابات التقنيات الكبرى والبريد (8)
  'googleyoutubegmail',
  'yahoo',
  'microsoft',
  'apple',
  'protonmail',
  'gmx',
  'mailru',
  'yandex',
  // —— ذكاء اصطناعي وأدوات مطوّرين وإنتاجية (18)
  'openai',
  'claude',
  'kimi',
  'manus',
  'truecaller',
  'twilio',
  'vonage',
  'textfree',
  'keepcalling',
  'rebtel',
  'adobe',
  'autodesk',
  'docusign',
  'zoho',
  'shopify',
  'vercel',
  'firebase',
  'hostinger',
  // —— تعارف ومواعدة (12)
  'tinder',
  'badoo',
  'bumble',
  'hinge',
  'grindr',
  'happn',
  'lovoo',
  'pofcom',
  'okcupid',
  'muzz',
  'her',
  'chispa',
  // —— بث وموسيقى (6)
  'netflix',
  'spotify',
  'twitch',
  'disneyplus',
  'bilibili',
  'bigolive',
  // —— ألعاب ومنصات شحن (9)
  'roblox',
  'steam',
  'epicgames',
  'blizzard',
  'ubisoft',
  'supercell',
  'codashop',
  'funpay',
  'razer',
  // —— عملات رقمية وتداول (12)
  'binance',
  'coinbase',
  'bybit',
  'okx',
  'mexc',
  'bitso',
  'cryptocom',
  'gemini',
  'traderepublic',
  'etoro',
  'moonpay',
  'eneba',
  // —— دفع ومال (16)
  'paypal',
  'payoneer',
  'venmo',
  'wise',
  'revolut',
  'monzo',
  'chime',
  'bunq',
  'skrill',
  'neteller',
  'paysera',
  'paysafecard',
  'sumup',
  'square',
  'capitalone',
  'klarna',
  // —— محافظ إقليمية كبرى (12)
  'phonepe',
  'paytm',
  'bharatpe',
  'gcash',
  'dana',
  'ovo',
  'truemoney',
  'momo',
  'touchngotng',
  'fawry',
  'papara',
  'picpay',
  // —— تسوّق وأسواق (18)
  'amazon',
  'ebay',
  'aliexpress',
  'temu',
  'shein',
  'shopee',
  'lazada',
  'flipkart',
  'walmart',
  'mercado',
  'allegro',
  'ozon',
  'wildberries',
  'trendyol',
  'hepsiburadacom',
  'noon',
  'carrefour',
  'nike',
  // —— أزياء وإعادة بيع (10)
  'zara',
  'poshmark',
  'mercari',
  'vinted',
  'grailed',
  'depop',
  'offerup',
  'carousell',
  'letgo',
  'redbubble',
  // —— مبوبة وإعلانات مبوبة (8)
  'olx',
  'leboncoin',
  'kleinanzeigen',
  'gumtree',
  'craigslist',
  'marktplaats',
  'willhaben',
  'sahibinden',
  // —— طعام وتوصيل (16)
  'doordash',
  'deliveroo',
  'wolt',
  'talabat',
  'getir',
  'ifood',
  'glovo',
  'zomato',
  'swiggy',
  'justeat',
  'foodpanda',
  'hungerstation',
  'yemeksepeti',
  'keeta',
  'mcdonalds',
  'starbucks',
  // —— نقل وتطبيقات طريق (11)
  'uber',
  'lyft',
  'grab',
  'bolt',
  'careem',
  'freenow',
  'cabify',
  'didi',
  'indriver',
  'blablacar',
  'olacabs',
  // —— سفر وسياحة (3)
  'airbnb',
  'bookingcom',
  'trip',
  // —— عمل وخدمات مستقلة (6)
  'linkedin',
  'fiverr',
  'upwork',
  'freelancer',
  'indeed',
  'fastwork',
  // —— تطبيقات صينية كبرى (4)
  'tencentqq',
  'voovmeeting',
  'baidu',
  'naver',
  // —— جنوب شرق آسيا ودراجات مشاركة (3)
  'gojek',
  'lime',
  'whoosh',
];

/** مجموعة العضوية السريعة O(1) — تُبنى مرة واحدة عند التحميل */
export const POPULAR_APP_SET: ReadonlySet<string> = new Set(POPULAR_APP_KEYS);

/**
 * هل هذه الخدمة/هذا التطبيق من المشهورات المعتمدة؟
 * يُمرَّر رمز الخدمة كما أتى من المزود أو مفتاح المعجم، ويُطابق بالمفتاح
 * المنطقي الموحّد حتى يتطابق التطبيق ولو اختلف رمزه لدى المزود.
 */
export function isPopularApp(
  codeOrKey: string,
  providerType?: 'herosms' | 'fivesim' | string,
): boolean {
  if (!codeOrKey) return false;
  if (POPULAR_APP_SET.has(codeOrKey)) return true;
  return POPULAR_APP_SET.has(resolveAppMeta(codeOrKey, providerType).key);
}
