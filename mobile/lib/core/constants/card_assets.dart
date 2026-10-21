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
  final fallbackWidget = fallback ??
      Container(
        width: width,
        height: height,
        color: AppColors.surfaceContainerHigh,
        child: const Icon(Icons.apps_rounded, size: 24, color: AppColors.primaryBlue),
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
  } else {
    // If it's a card name like "pubg-mobile.png" without "assets/cards/"
    final inferredAsset = 'assets/cards/$trimmed';
    imageWidget = Image.asset(
      inferredAsset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, stack) => fallbackWidget,
    );
  }

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: imageWidget);
  }
  return imageWidget;
}
