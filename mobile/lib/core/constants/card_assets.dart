import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BuiltinCardAsset {
  final String assetPath;
  final String nameAr;
  final String nameEn;
  final String category; // 'game' | 'app' | 'service'

  const BuiltinCardAsset({
    required this.assetPath,
    required this.nameAr,
    required this.nameEn,
    required this.category,
  });
}

/// All bundled card artwork in assets/cards/ (40 card assets)
const List<BuiltinCardAsset> kBuiltinCardAssets = [
  // ==========================================
  // 1. الألعاب (Games)
  // ==========================================
  BuiltinCardAsset(
    assetPath: 'assets/cards/pubg-mobile.png',
    nameAr: 'ببجي موبايل',
    nameEn: 'PUBG Mobile',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/free-fire.png',
    nameAr: 'فري فاير',
    nameEn: 'Free Fire',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/call-of-duty-mobile.png',
    nameAr: 'كول أوف ديوتي',
    nameEn: 'Call of Duty Mobile',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/ea-sports-fc.png',
    nameAr: 'إي إيه سبورتس FC',
    nameEn: 'EA Sports FC Mobile',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/efootball.png',
    nameAr: 'إي فوتبول (بيس)',
    nameEn: 'eFootball PES',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/clash-of-clans.png',
    nameAr: 'كلاش أوف كلانس',
    nameEn: 'Clash of Clans',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/clash-royale.png',
    nameAr: 'كلاش رويال',
    nameEn: 'Clash Royale',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/brawl-stars.png',
    nameAr: 'براول ستارز',
    nameEn: 'Brawl Stars',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/roblox.png',
    nameAr: 'روبلوكس',
    nameEn: 'Roblox',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/minecraft.png',
    nameAr: 'ماينكرافت',
    nameEn: 'Minecraft',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/fortnite.png',
    nameAr: 'فورتنايت',
    nameEn: 'Fortnite',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/valorant.png',
    nameAr: 'فالورانت',
    nameEn: 'Valorant',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/league-of-legends.png',
    nameAr: 'ليغ أوف ليجندز',
    nameEn: 'League of Legends',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/mobile-legends.png',
    nameAr: 'موبايل ليجندز',
    nameEn: 'Mobile Legends',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/genshin-impact.png',
    nameAr: 'قنشن إمباكت',
    nameEn: 'Genshin Impact',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/honkai-star-rail.png',
    nameAr: 'هونكاي ستار ريل',
    nameEn: 'Honkai: Star Rail',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/asphalt-9.png',
    nameAr: 'أسفلت 9',
    nameEn: 'Asphalt 9 Legends',
    category: 'game',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/among-us.png',
    nameAr: 'أمونغ آس',
    nameEn: 'Among Us',
    category: 'game',
  ),

  // ==========================================
  // 2. التطبيقات وشبكات التواصل والذكاء الاصطناعي (Apps & AI)
  // ==========================================
  BuiltinCardAsset(
    assetPath: 'assets/cards/chatgpt.png',
    nameAr: 'شات جي بي تي',
    nameEn: 'ChatGPT Plus',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/tiktok.png',
    nameAr: 'تيك توك',
    nameEn: 'TikTok',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/snapchat.png',
    nameAr: 'سناب شات',
    nameEn: 'Snapchat+',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/instagram.png',
    nameAr: 'إنستغرام',
    nameEn: 'Instagram',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/facebook.png',
    nameAr: 'فيسبوك',
    nameEn: 'Facebook',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/whatsapp.png',
    nameAr: 'واتساب',
    nameEn: 'WhatsApp',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/telegram.png',
    nameAr: 'تيليجرام',
    nameEn: 'Telegram Premium',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/discord.png',
    nameAr: 'ديسكورد',
    nameEn: 'Discord Nitro',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/x.png',
    nameAr: 'إكس (تويتر)',
    nameEn: 'X (Twitter) Premium',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/canva.png',
    nameAr: 'كانفا برو',
    nameEn: 'Canva Pro',
    category: 'app',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/gmail.png',
    nameAr: 'بريد جيميل / جوجل',
    nameEn: 'Google / Gmail Workspace',
    category: 'app',
  ),

  // ==========================================
  // 3. الخدمات، المنصات، الاشتراكات والبطاقات (Services & Consoles)
  // ==========================================
  BuiltinCardAsset(
    assetPath: 'assets/cards/playstation.png',
    nameAr: 'بلايستيشن ستور',
    nameEn: 'PlayStation Network (PSN)',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/xbox.png',
    nameAr: 'إكس بوكس غيم باس',
    nameEn: 'Xbox Game Pass / Live',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/steam.png',
    nameAr: 'ستيم',
    nameEn: 'Steam Wallet',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/nintendo.png',
    nameAr: 'نينتندو إي شوب',
    nameEn: 'Nintendo eShop',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/google-play.png',
    nameAr: 'جوجل بلاي',
    nameEn: 'Google Play',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/app-store.png',
    nameAr: 'آب ستور / آبل',
    nameEn: 'Apple App Store / iTunes',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/icloud.png',
    nameAr: 'آي كلاود+',
    nameEn: 'Apple iCloud+',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/microsoft-365.png',
    nameAr: 'مايكروسوفت 365',
    nameEn: 'Microsoft 365 / Office',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/netflix.png',
    nameAr: 'نتفليكس',
    nameEn: 'Netflix',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/youtube-premium.png',
    nameAr: 'يوتيوب بريميوم',
    nameEn: 'YouTube Premium',
    category: 'service',
  ),
  BuiltinCardAsset(
    assetPath: 'assets/cards/spotify.png',
    nameAr: 'سبوتيفاي',
    nameEn: 'Spotify Premium',
    category: 'service',
  ),
];

/// الأيقونة المربعة المرفقة المطابقة لبطاقة الكتالوج.
/// كل منتج له صورتان بنفس الاسم: بطاقة أفقية في assets/cards/ وأيقونة
/// مربعة 256×256 في assets/icons/، لذا يُشتق مسار الأيقونة من مسار البطاقة.
/// مثال: 'assets/cards/pubg-mobile.png' -> 'assets/icons/pubg-mobile.png'
String? builtinIconAssetForCard(String? cardAssetPath) {
  final String path = cardAssetPath?.trim() ?? '';
  if (!path.startsWith('assets/cards/')) return null;
  final String file = path.split('/').last;
  if (file.isEmpty || !file.endsWith('.png')) return null;
  return 'assets/icons/$file';
}

/// بطاقة الكتالوج المقابلة لمسار أيقونة مربعة، أو null إن لم توجد بطاقة.
/// مثال: 'assets/icons/pubg-mobile.png' -> 'assets/cards/pubg-mobile.png'
/// تُستعمل كي تعرض البطاقة العريضة فنّها الأفقي حتى لو اختار الأدمن الأيقونة.
String? builtinCardAssetForIcon(String? iconAssetPath) {
  final String path = iconAssetPath?.trim() ?? '';
  if (!path.startsWith('assets/icons/')) return null;
  final String file = path.split('/').last;
  if (file.isEmpty || !file.endsWith('.png')) return null;
  final String candidate = 'assets/cards/$file';
  return kBuiltinCardAssets.any((c) => c.assetPath == candidate)
      ? candidate
      : null;
}

/// بطاقة الكتالوج المطابقة لاسم منتج أو slug ملف، مطابقة تامة ثم جزئية.
/// يقبل: 'ببجي موبايل'، 'PUBG Mobile'، 'pubg-mobile'، 'assets/cards/pubg-mobile.png'
BuiltinCardAsset? builtinCardEntryForQuery(String query) {
  final String q = query.trim().toLowerCase();
  if (q.length < 4) return null;

  for (final asset in kBuiltinCardAssets) {
    if (q == cardSlugOf(asset) ||
        q == asset.nameEn.toLowerCase() ||
        q == asset.nameAr.toLowerCase()) {
      return asset;
    }
  }

  for (final asset in kBuiltinCardAssets) {
    final String file = cardSlugOf(asset);
    final String en = asset.nameEn.toLowerCase();
    final String ar = asset.nameAr.toLowerCase();
    if (q.contains(file) ||
        q.contains(en) ||
        en.contains(q) ||
        q.contains(ar)) {
      return asset;
    }
  }
  return null;
}

/// slug اسم الملف بدون مسار أو امتداد: 'assets/cards/pubg-mobile.png' -> 'pubg-mobile'
String cardSlugOf(BuiltinCardAsset asset) => asset.assetPath
    .split('/')
    .last
    .replaceAll(RegExp(r'\.(png|jpe?g|webp)$'), '');

/// المسار من الدالة أعلاه (استعمال القوائم والاختبارات)
String? builtinCardAssetForQuery(String query) =>
    builtinCardEntryForQuery(query)?.assetPath;

/// Smart image loader that supports both local asset paths (assets/cards/...)
/// and remote URLs (https://...).
Widget buildSmartAppImage(
  String? urlOrAsset, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget? fallback,
}) {
  final fallbackWidget =
      fallback ??
      Container(
        width: width,
        height: height,
        color: AppColors.surfaceContainerHigh,
        child: const Icon(
          Icons.apps_rounded,
          size: 24,
          color: AppColors.primaryBlue,
        ),
      );

  if (urlOrAsset == null || urlOrAsset.trim().isEmpty) {
    return borderRadius != null
        ? ClipRRect(borderRadius: borderRadius, child: fallbackWidget)
        : fallbackWidget;
  }

  final trimmed = urlOrAsset.trim();
  Widget imageWidget;

  if (trimmed.startsWith('assets/')) {
    imageWidget = Image.asset(
      trimmed,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, stack) => fallbackWidget,
    );
  } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    imageWidget = Image.network(
      trimmed,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, stack) => fallbackWidget,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: AppColors.surfaceContainerHigh,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  } else if (!trimmed.contains('/')) {
    // اسم ملف بطاقة مجرّد مثل "pubg-mobile.png" بدون مجلد
    final inferredAsset = 'assets/cards/$trimmed';
    imageWidget = Image.asset(
      inferredAsset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, stack) => fallbackWidget,
    );
  } else {
    // مسار لا يمكن تحميله (مثل /uploads/... دون رابط كامل): يُترك البديل
    return borderRadius != null
        ? ClipRRect(borderRadius: borderRadius, child: fallbackWidget)
        : fallbackWidget;
  }

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: imageWidget);
  }
  return imageWidget;
}
