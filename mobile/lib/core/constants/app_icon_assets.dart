import 'card_assets.dart';

/// أيقونات مربعة إضافية في assets/icons/ لمنتجات ليست لها بطاقات في الكتالوج.
/// تُستعمل عندما يضيف الأدمن تطبيقًا باسم معروف (مثل «شاهد» أو «كاونتر سترايك 2»)
/// فيُحلّ شعاره الحقيقي من `assets/icons/<slug>.png` دون الحاجة لصورة بطاقة.
///
/// بطاقات الكتالوج الأصلية الأربعون تُحلّل عبر builtinIconAssetForCard()
/// في card_assets.dart، وهذا السجل يغطي ما عداها.
class BuiltinIconAsset {
  final String slug;
  final String nameEn;
  final String nameAr;

  /// نفس قيم بطاقات الكتالوج: 'game' | 'app' | 'service' (لتبويب لوحة الأدمن)
  final String category;

  /// أسماء شائعة أخرى يكتبها الأدمن بالعربية أو الإنكليزية
  final List<String> aliases;

  const BuiltinIconAsset({
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    required this.category,
    this.aliases = const [],
  });

  String get assetPath => 'assets/icons/$slug.png';
}

const List<BuiltinIconAsset> kBuiltinIconAssets = [
  // ==========================================
  // ألعاب
  // ==========================================
  BuiltinIconAsset(
    slug: 'zenless-zone-zero',
    nameEn: 'Zenless Zone Zero',
    nameAr: 'زينلس زون زيرو',
    category: 'game',
    aliases: ['ZZZ', 'Zenless'],
  ),
  BuiltinIconAsset(
    slug: 'wuthering-waves',
    nameEn: 'Wuthering Waves',
    nameAr: 'وثرينغ ويفز',
    category: 'game',
    aliases: ['WuWa', 'Wuthering'],
  ),
  BuiltinIconAsset(
    slug: 'standoff-2',
    nameEn: 'Standoff 2',
    nameAr: 'ستاندوف 2',
    category: 'game',
    aliases: ['Standoff'],
  ),
  BuiltinIconAsset(
    slug: 'honor-of-kings',
    nameEn: 'Honor of Kings',
    nameAr: 'أونر أوف كينغز',
    category: 'game',
    aliases: ['HoK'],
  ),
  BuiltinIconAsset(
    slug: 'delta-force',
    nameEn: 'Delta Force',
    nameAr: 'دلتا فورس',
    category: 'game',
    aliases: ['Delta Force Hawk Ops', 'Hawk Ops'],
  ),
  BuiltinIconAsset(
    slug: 'free-fire-max',
    nameEn: 'Free Fire MAX',
    nameAr: 'فري فاير ماكس',
    category: 'game',
    aliases: ['FF MAX'],
  ),
  BuiltinIconAsset(
    slug: 'arena-of-valor',
    nameEn: 'Arena of Valor',
    nameAr: 'أرينا أوف فالور',
    category: 'game',
    aliases: ['AoV'],
  ),
  BuiltinIconAsset(
    slug: 'arena-breakout',
    nameEn: 'Arena Breakout',
    nameAr: 'أرينا بريك أوت',
    category: 'game',
    aliases: ['Arena Breakout Infinite'],
  ),
  BuiltinIconAsset(
    slug: 'game-for-peace',
    nameEn: 'Game for Peace',
    nameAr: 'غيم فور بيس',
    category: 'game',
    aliases: ['Peace Elite'],
  ),
  BuiltinIconAsset(
    slug: 'crossfire',
    nameEn: 'CrossFire',
    nameAr: 'كروس فاير',
    category: 'game',
    aliases: ['CrossFire Legends', 'Cross Fire'],
  ),
  BuiltinIconAsset(
    slug: 'razer-gold',
    nameEn: 'Razer Gold',
    nameAr: 'رايزر غولد',
    category: 'game',
    aliases: ['Razer'],
  ),
  BuiltinIconAsset(
    slug: 'battle-net',
    nameEn: 'Battle.net',
    nameAr: 'باتل نت',
    category: 'game',
    aliases: ['Battlenet', 'Battle net', 'Blizzard'],
  ),
  BuiltinIconAsset(
    slug: 'epic-games',
    nameEn: 'Epic Games',
    nameAr: 'إبيك غيمز',
    category: 'game',
    aliases: ['Epic Games Wallet', 'Epic'],
  ),
  BuiltinIconAsset(
    slug: 'ea-app',
    nameEn: 'EA app',
    nameAr: 'تطبيق إي إيه',
    category: 'game',
    aliases: ['EA', 'Origin', 'Electronic Arts'],
  ),
  BuiltinIconAsset(
    slug: 'dota-2',
    nameEn: 'Dota 2',
    nameAr: 'دوتا 2',
    category: 'game',
    aliases: ['Dota2', 'Dota'],
  ),
  BuiltinIconAsset(
    slug: 'counter-strike-2',
    nameEn: 'Counter-Strike 2',
    nameAr: 'كاونتر سترايك 2',
    category: 'game',
    aliases: ['CS2', 'CS:GO', 'Counter Strike', 'Counter-Strike'],
  ),

  // ==========================================
  // اشتراكات الفيديو والموسيقى
  // ==========================================
  BuiltinIconAsset(
    slug: 'shahid',
    nameEn: 'Shahid',
    nameAr: 'شاهد',
    category: 'service',
    aliases: ['MBC Shahid', 'Shahid VIP', 'شاهد VIP'],
  ),
  BuiltinIconAsset(
    slug: 'osn-plus',
    nameEn: 'OSN+',
    nameAr: 'أو إس إن',
    category: 'service',
    aliases: ['OSN', 'Osn+', 'OSN Streaming'],
  ),
  BuiltinIconAsset(
    slug: 'anghami',
    nameEn: 'Anghami',
    nameAr: 'أنغامي',
    category: 'service',
    aliases: ['ANGHAMY', 'Anghami Gold'],
  ),
  BuiltinIconAsset(
    slug: 'deezer',
    nameEn: 'Deezer',
    nameAr: 'ديزر',
    category: 'service',
    aliases: ['Deezer Premium', 'Deezer Family'],
  ),
  BuiltinIconAsset(
    slug: 'apple-music',
    nameEn: 'Apple Music',
    nameAr: 'أبل ميوزك',
    category: 'service',
    aliases: ['Apple Music Individual', 'Apple Music Student'],
  ),
  BuiltinIconAsset(
    slug: 'apple-tv',
    nameEn: 'Apple TV',
    nameAr: 'أبل تي في',
    category: 'service',
    aliases: ['Apple TV+', 'AppleTv', 'Apple TV Plus'],
  ),
  BuiltinIconAsset(
    slug: 'disney-plus',
    nameEn: 'Disney+',
    nameAr: 'ديزني بلس',
    category: 'service',
    aliases: ['Disney Plus', 'Disney', 'Disney Hotstar'],
  ),
  BuiltinIconAsset(
    slug: 'hbo-max',
    nameEn: 'HBO Max',
    nameAr: 'إتش بي أو ماكس',
    category: 'service',
    aliases: ['Max', 'HBOMax', 'HBO'],
  ),
  BuiltinIconAsset(
    slug: 'prime-video',
    nameEn: 'Amazon Prime Video',
    nameAr: 'برايم فيديو',
    category: 'service',
    aliases: ['Prime Video', 'Amazon Video'],
  ),
  BuiltinIconAsset(
    slug: 'paramount-plus',
    nameEn: 'Paramount+',
    nameAr: 'باراماونت بلس',
    category: 'service',
    aliases: ['Paramount Plus', 'Paramount'],
  ),
  BuiltinIconAsset(
    slug: 'starzplay',
    nameEn: 'StarzPlay',
    nameAr: 'ستارز بلاي',
    category: 'service',
    aliases: ['STARZPLAY', 'Starz Play', 'Lionsgate+'],
  ),
  BuiltinIconAsset(
    slug: 'tod',
    nameEn: 'TOD',
    nameAr: 'تود',
    category: 'service',
    aliases: ['TOD by beIN', 'BeIN TOD', 'beIN TOD'],
  ),
  BuiltinIconAsset(
    slug: 'twitch',
    nameEn: 'Twitch',
    nameAr: 'تويتش',
    category: 'service',
    aliases: ['Twitch Turbo', 'Twitch Prime'],
  ),
  BuiltinIconAsset(
    slug: 'youtube-music',
    nameEn: 'YouTube Music',
    nameAr: 'يوتيوب ميوزك',
    category: 'service',
    aliases: ['Youtube Music', 'YouTube Music Premium'],
  ),

  // ==========================================
  // الذكاء الاصطناعي والخدمات
  // ==========================================
  BuiltinIconAsset(
    slug: 'claude',
    nameEn: 'Claude',
    nameAr: 'كلود',
    category: 'service',
    aliases: ['Anthropic', 'Claude Pro', 'Claude Max'],
  ),
  BuiltinIconAsset(
    slug: 'gemini',
    nameEn: 'Google Gemini',
    nameAr: 'جيميناي',
    category: 'service',
    aliases: ['Gemini', 'Gemini Advanced', 'Bard'],
  ),
  BuiltinIconAsset(
    slug: 'copilot',
    nameEn: 'Microsoft Copilot',
    nameAr: 'كوبايلوت',
    category: 'service',
    aliases: ['Copilot', 'Bing Chat', 'Microsoft 365 Copilot'],
  ),
  BuiltinIconAsset(
    slug: 'grok',
    nameEn: 'Grok',
    nameAr: 'غروك',
    category: 'service',
    aliases: ['xAI', 'Grok AI', 'SuperGrok'],
  ),
  BuiltinIconAsset(
    slug: 'adobe-cc',
    nameEn: 'Adobe Creative Cloud',
    nameAr: 'أدوبي كرياتيف كلاود',
    category: 'service',
    aliases: ['Creative Cloud', 'Adobe CC', 'Adobe'],
  ),
  BuiltinIconAsset(
    slug: 'photoshop',
    nameEn: 'Adobe Photoshop',
    nameAr: 'فوتوشوب',
    category: 'service',
    aliases: ['Photoshop', 'Photoshop Express', 'Photoshop on iPad'],
  ),
  BuiltinIconAsset(
    slug: 'lightroom',
    nameEn: 'Adobe Lightroom',
    nameAr: 'لايت روم',
    category: 'service',
    aliases: ['Lightroom', 'Lightroom Classic'],
  ),
  BuiltinIconAsset(
    slug: 'notion',
    nameEn: 'Notion',
    nameAr: 'نوشن',
    category: 'service',
    aliases: ['Notion Plus', 'Notion AI'],
  ),
  BuiltinIconAsset(
    slug: 'nordvpn',
    nameEn: 'NordVPN',
    nameAr: 'نورد في بي إن',
    category: 'service',
    aliases: ['Nord VPN', 'NordPass'],
  ),
  BuiltinIconAsset(
    slug: 'kaspersky',
    nameEn: 'Kaspersky',
    nameAr: 'كاسبرسكي',
    category: 'service',
    aliases: ['Kaspersky Premium', 'Kaspersky VPN', 'Kaspersky Total Security'],
  ),
  BuiltinIconAsset(
    slug: 'linkedin',
    nameEn: 'LinkedIn',
    nameAr: 'لينكد إن',
    category: 'app',
    aliases: ['Linked In', 'LinkedIn Premium'],
  ),
  BuiltinIconAsset(
    slug: 'careem',
    nameEn: 'Careem',
    nameAr: 'كريم',
    category: 'app',
    aliases: ['Careem Max', 'Careem Points'],
  ),
  BuiltinIconAsset(
    slug: 'talabat',
    nameEn: 'talabat',
    nameAr: 'طلبات',
    category: 'app',
    aliases: ['Talabat', 'Talabat Pro'],
  ),
  BuiltinIconAsset(
    slug: 'uber',
    nameEn: 'Uber',
    nameAr: 'أوبر',
    category: 'app',
    aliases: ['Uber One', 'Uber Eats', 'Ubar'],
  ),
  BuiltinIconAsset(
    slug: 'amazon',
    nameEn: 'Amazon',
    nameAr: 'أمازون',
    category: 'app',
    aliases: ['Amazon Shopping', 'Amazon Prime', 'Amazon Gift Card'],
  ),
];

/// الأيقونة المربعة لمنتج كما ستظهر في شبكة التطبيقات وفي قوائم لوحة الأدمن.
/// الأولوية:
///  1) صورة الأدمن المخصصة (رابط خارجي أو ملف مرفوع) -> null كي تُعرض صورته
///  2) أيقونة assets/icons مختارة صراحةً
///  3) الاسم: مطابق تام للسجل -> بطاقة كتالوج -> اسم قريب من السجل
String? iconAssetForApp({required String iconUrl, required String name}) {
  final String raw = iconUrl.trim();
  if (raw.startsWith('http://') || raw.startsWith('https://')) return null;
  if (raw.startsWith('assets/') &&
      !raw.startsWith('assets/cards/') &&
      !raw.startsWith('assets/icons/')) {
    return null;
  }
  if (raw.startsWith('assets/icons/')) return raw;

  final String key = raw.isNotEmpty ? raw : name;
  return builtinIconAssetForName(key) ?? builtinIconAssetForName(name);
}

/// الاسم الأجنبي (الإنكليزي) المعروف لمنتج من مكتبة المشروع: بطاقات الكتالوج
/// أوّلاً ثم سجل الأيقونات الإضافية. يُطابق بالاسم ثم بمسار الصورة.
/// يعيد null إن لم تُعرف هوية المنتج، وأما عرض السطر الثاني فيعود للواجهة.
String? englishNameForApp({required String iconUrl, required String name}) {
  for (final String query in <String>[name.trim(), iconUrl.trim()]) {
    if (query.isEmpty) continue;
    final BuiltinCardAsset? card = builtinCardEntryForQuery(query);
    if (card != null && card.nameEn.trim().isNotEmpty) {
      return card.nameEn.trim();
    }
    final BuiltinIconAsset? icon = builtinIconEntryForQuery(query);
    if (icon != null && icon.nameEn.trim().isNotEmpty) {
      return icon.nameEn.trim();
    }
  }
  return null;
}

/// عنصر السجل المطابق لاسم أو مسار حر (يُستعمل لقراءة الاسم الأجنبي والنوع).
BuiltinIconAsset? builtinIconEntryForQuery(String query) {
  final String q = _normalizeIconKey(query);
  if (q.length < 3) return null;

  for (final BuiltinIconAsset asset in kBuiltinIconAssets) {
    if (_iconKeysOf(asset).contains(q)) return asset;
  }
  for (final BuiltinIconAsset asset in kBuiltinIconAssets) {
    for (final String key in _iconKeysOf(asset)) {
      if (key.length < 4) continue;
      if (q.contains(key) || key.contains(q)) return asset;
    }
  }
  return null;
}

/// الأيقونة المربعة لمنتج يُعرف باسمه فقط (بلا بطاقة ولا اختيار من الأدمن).
/// الترتيب: مطابق تماماً للسجل -> بطاقة كتالوج بالاسم -> اسم قريب من السجل.
String? builtinIconAssetForName(String name) {
  final String? exact = builtinIconAssetExact(name);
  if (exact != null) return exact;
  final String? fromCard = builtinIconAssetForCard(
    builtinCardAssetForQuery(name),
  );
  if (fromCard != null) return fromCard;
  return builtinIconAssetForQuery(name);
}

/// تطابق اسمًا أو مسارًا حرًا مع سجل الأيقونات الإضافية.
/// يقبل: «شاهد»، «Shahid VIP»، «assets/icons/shahid.png»، «shahid.png»، «builtin:shahid»
/// ويعيد مسار الأيقونة داخل الأصول، أو null إن لم يُعرف.
String? builtinIconAssetForQuery(String query) =>
    builtinIconEntryForQuery(query)?.assetPath;

/// مطابقة تامة فقط: اسم كامل أو slug كامل أو مرادف كامل.
/// تُستعمل قبل المطابقة الجزئية لئلا يخطئ الاختيار (مثل «فري فاير» و«فري فاير ماكس»).
String? builtinIconAssetExact(String query) {
  final String q = _normalizeIconKey(query);
  if (q.length < 3) return null;
  for (final BuiltinIconAsset asset in kBuiltinIconAssets) {
    if (_iconKeysOf(asset).contains(q)) return asset.assetPath;
  }
  return null;
}

/// كل الأسماء الصالحة للأيقونة الواحدة، كمفاتيح مُطبّعة
Set<String> _iconKeysOf(BuiltinIconAsset asset) => {
  asset.slug,
  _normalizeIconKey(asset.nameEn),
  _normalizeIconKey(asset.nameAr),
  for (final String alias in asset.aliases) _normalizeIconKey(alias),
};

/// تبسيط النص للمقارنة: حروف صغيرة، بلا مسار أو امتداد أو علامات ترقيم
String _normalizeIconKey(String value) {
  String v = value.trim().toLowerCase();
  if (v.startsWith('builtin:')) v = v.substring('builtin:'.length).trim();
  if (v.contains('/')) v = v.split('/').last;
  v = v.replaceAll(RegExp(r'\.(png|jpe?g|webp|svg)$'), '');
  return v
      .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06ff ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
