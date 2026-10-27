import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/exchange_rate_provider.dart';
import '../../widgets/billboard_ad_carousel.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/app_icon_tile.dart';
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/floating_role_dashboard_shield.dart';
import 'app_products_screen.dart';
import 'topup_screen.dart';
import 'orders_history_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _currentIndex =
      0; // 0 = التطبيقات, 1 = الألعاب, 2 = طلباتي, 3 = خدمات, 4 = الاشتراكات

  // طريقة عرض الكتالوج: أيقونات بنمط شاشة الهاتف (افتراضي) أو بطاقات التذاكر
  bool _catalogIconView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppCatalogProvider>(context, listen: false).fetchApps();
      Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
      Provider.of<AuthProvider>(context, listen: false).refreshProfile();
      // سعر الصرف يحدّثه الخادم يومياً — التطبيق يقرأه ويعرضه
      Provider.of<ExchangeRateProvider>(context, listen: false).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildCatalogTab(context, categoryType: 'apps'), // 0: التطبيقات
              _buildCatalogTab(context, categoryType: 'games'), // 1: الألعاب
              _buildOrdersTab(context), // 2: طلباتي (في الوسط)
              _buildCatalogTab(context, categoryType: 'services'), // 3: خدمات
              _buildCatalogTab(
                context,
                categoryType: 'subscriptions',
              ), // 4: الاشتراكات
            ],
          ),

          // Floating Ticket Dock Navigation Bar
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: _buildFloatingDockNavBar(context),
              ),
            ),
          ),

          // Floating Tactical Shield Button (زر التبديل للوحة التحكم للأدمن والمشرف والوكيل فقط)
          const FloatingRoleDashboardShield(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SWISS NEO-BENTO CATALOG VIEW (APPS / GAMES / SERVICES)
  // ---------------------------------------------------------------------------

  Widget _buildCatalogTab(
    BuildContext context, {
    required String categoryType,
  }) {
    final catalog = Provider.of<AppCatalogProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final rates = Provider.of<ExchangeRateProvider>(context);
    final user = auth.currentUser;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await catalog.fetchApps();
          await catalog.fetchBanners();
          await auth.refreshProfile();
          await catalog.fetchMyOrders();
          await rates.fetch(force: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 115),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 9),
                _buildTactileHeader(context, user),

                if (categoryType == 'games' || categoryType == 'apps') ...[
                  if (catalog.banners.isNotEmpty)
                    // الإعلان بعرض أقل من كامل الشاشة — يبقى داخل حشوة الصفحة (14px)
                    BillboardAdCarousel(banners: catalog.banners)
                  else
                    HeroTicketBanner(
                      onTap: () {
                        final pubgList = catalog.apps
                            .where(
                              (a) =>
                                  a.name.toLowerCase().contains('pubg') ||
                                  a.name.contains('ببجي'),
                            )
                            .toList();
                        if (pubgList.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AppProductsScreen(app: pubgList.first),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TopupScreen(),
                            ),
                          );
                        }
                      },
                    ),
                ],
                const SizedBox(height: 20),
                _buildSectionHeader(
                  context,
                  catalog,
                  categoryType: categoryType,
                ),
                const SizedBox(height: 12),
                _buildDigitalPassesGrid(
                  context,
                  catalog,
                  categoryType: categoryType,
                ),
                const SizedBox(height: 14),
                _buildSupportBox(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TACTILE PASSPORT CONTROL HEADER
  // ---------------------------------------------------------------------------

  Widget _buildTactileHeader(BuildContext context, UserModel? user) {
    return UnifiedTactileHeader(user: user, isDashboard: false);
  }

  // ---------------------------------------------------------------------------
  // 3. FLIGHT / SERVER TICKER STRIP
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 4. DIGITAL FINANCIAL PASSPORT (سعر الصرف اليوم — يُعرض الآن في شاشة الشحن)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 6. SECTION TITLE: VOUCHER CATALOG
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(
    BuildContext context,
    AppCatalogProvider catalog, {
    String categoryType = 'apps',
  }) {
    String titleText = "تطبيقات الشحن والخدمات";
    String badgeText = "APPS ";

    if (categoryType == 'games') {
      titleText = "شحن الألعاب والعملات";
      badgeText = " GAMES";
    } else if (categoryType == 'services') {
      titleText = "البطاقات والخدمات ";
      badgeText = "DIGITAL SERVICES";
    } else if (categoryType == 'subscriptions') {
      titleText = "اشتراكات المنصات";
      badgeText = "SUBSCRIPTIONS";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 5,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: AppTypography.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
        // صفحتا الخدمات والاشتراكات تُعرضان دائماً كبطاقات فقط
        if (!_isCardOnlyCategory(categoryType)) ...[
          const SizedBox(width: 8),
          _buildCatalogViewToggle(),
        ],
      ],
    );
  }

  // صفحات تُعرض كبطاقات تذاكر دائماً ولا تقبل نمط الأيقونات
  bool _isCardOnlyCategory(String categoryType) =>
      categoryType == 'services' || categoryType == 'subscriptions';

  // كلمات وماركات تدل على أن العنصر اشتراك رقمي متجدد
  static const List<String> _subscriptionHints = [
    'اشتراك',
    'اشتراكات',
    'subscription',
    'premium',
    'بريميوم',
    'netflix',
    'نتفليكس',
    'shahid',
    'شاهد',
    'osn',
    'spotify',
    'سبوتيفاي',
    'anghami',
    'أنغامي',
    'youtube',
    'يوتيوب',
    'icloud',
    'chatgpt',
    'openai',
    'canva',
    'microsoft 365',
    'مايكروسوفت',
    'أوفيس',
    'آي كلاود',
    'office 365',
    'disney',
    'prime video',
    'amazon prime',
    'apple music',
    'nitro',
    'workspace',
    'game pass',
    'ps plus',
    'playstation plus',
    'crunchyroll',
    'viu',
    'adobe',
  ];

  bool _isSubscriptionItem(AppItemModel app) {
    final haystack =
        '${app.name} ${app.nameAr ?? ''} ${app.nameEn ?? ''} ${app.category ?? ''}'
            .toLowerCase();
    return _subscriptionHints.any(haystack.contains);
  }

  /// نوع العنصر الفعلي: «النوع الرئيسي» القادم من لوحة الإدارة، وإن لم يكن
  /// محدداً (بيانات قديمة) نستنتجه من اسم العنصر حتى لا يختفي من كل الصفحات.
  String _effectiveAppType(AppItemModel app) {
    final type = app.appType.trim().toLowerCase();
    if (type == 'game' ||
        type == 'app' ||
        type == 'service' ||
        type == 'subscription') {
      return type;
    }
    if (_isSubscriptionItem(app)) return 'subscription';
    return 'service';
  }

  // ---------------------------------------------------------------------------
  // 6.b CATALOG VIEW MODE TOGGLE (أيقونات / بطاقات)
  // ---------------------------------------------------------------------------

  Widget _buildCatalogViewToggle() {
    final bool iconMode = _catalogIconView;

    return Tooltip(
      message: iconMode ? 'عرض كبطاقات' : 'عرض كأيقونات',
      child: Material(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _catalogIconView = !iconMode),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              iconMode ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
              size: 18,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. PERFORATED TICKET PRODUCT CARDS GRID (RESPONSIVE COLUMNS)
  // ---------------------------------------------------------------------------

  int _getResponsiveCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1600) return 6;
    if (width >= 1250) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  double _getResponsiveChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1250) return 1.65;
    if (width >= 900) return 1.60;
    if (width >= 600) return 1.55;
    return 1.50;
  }

  Widget _buildDigitalPassesGrid(
    BuildContext context,
    AppCatalogProvider catalog, {
    String categoryType = 'apps',
  }) {
    if (catalog.isLoading && catalog.apps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (catalog.apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 44,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                'لا توجد عناصر متاحة حالياً',
                style: AppTypography.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // الصفحة التي يظهر فيها العنصر يحددها «النوع الرئيسي» من لوحة الإدارة:
    // لعبة ← صفحة الألعاب، تطبيق ← صفحة التطبيقات، خدمة ← صفحة الخدمات،
    // اشتراك ← صفحة الاشتراكات. لا تظهر البطاقة إلا في صفحة نوعها.
    const typeByPage = {
      'apps': 'app',
      'games': 'game',
      'services': 'service',
      'subscriptions': 'subscription',
    };
    final pageType = typeByPage[categoryType];
    final filteredApps = pageType == null
        ? catalog.apps
        : catalog.apps.where((a) => _effectiveAppType(a) == pageType).toList();

    if (filteredApps.isEmpty) {
      String emptyMessage = 'لا توجد عناصر متاحة حالياً';
      IconData emptyIcon = Icons.inbox_outlined;
      if (categoryType == 'subscriptions') {
        emptyMessage = 'لا توجد اشتراكات متاحة حالياً';
        emptyIcon = Icons.card_membership_rounded;
      } else if (categoryType == 'services') {
        emptyMessage = 'لا توجد خدمات متاحة حالياً';
        emptyIcon = Icons.miscellaneous_services_rounded;
      } else if (categoryType == 'games') {
        emptyMessage = 'لا توجد ألعاب متاحة حالياً';
        emptyIcon = Icons.sports_esports_rounded;
      } else if (categoryType == 'apps') {
        emptyMessage = 'لا توجد تطبيقات متاحة حالياً';
        emptyIcon = Icons.apps_rounded;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 44, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: AppTypography.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // الخدمات والاشتراكات تُعرض كبطاقات دائماً
    if (_catalogIconView && !_isCardOnlyCategory(categoryType)) {
      return _buildAppIconsGrid(context, filteredApps);
    }

    final int crossAxisCount = _getResponsiveCrossAxisCount(context);
    final double childAspectRatio = _getResponsiveChildAspectRatio(context);
    final double spacing = MediaQuery.of(context).size.width >= 900
        ? 14
        : (MediaQuery.of(context).size.width >= 600 ? 12 : 9);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        final passItem = DigitalPassItem.fromApp(app);

        return DigitalPassCardWidget(
          item: passItem,
          imageOnly: true,
          onTapCharge: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppProductsScreen(app: app)),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7.b APP ICONS GRID (شبكة أيقونات بنمط شاشة الهاتف)
  // ---------------------------------------------------------------------------

  Widget _buildAppIconsGrid(BuildContext context, List<AppItemModel> apps) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double spacing = screenWidth >= 900
        ? 18
        : (screenWidth >= 600 ? 14 : 10);
    final double targetCell = screenWidth >= 900 ? 96 : 84;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final int crossAxisCount =
            ((availableWidth + spacing) / (targetCell + spacing))
                .round()
                .clamp(4, 14)
                .toInt();
        final double cellWidth =
            (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing + 6,
            mainAxisExtent: AppIconTile.tileHeightFor(cellWidth),
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return AppIconTile(
              app: app,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppProductsScreen(app: app),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 8. BOARDING PASS SUPPORT STRIP
  // ---------------------------------------------------------------------------

  Widget _buildSupportBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "دعم فني مباشر على مدار الساعة 24/7",
                    style: AppTypography.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "TG DISPATCH CHANNEL: @CHARGEX_SY",
                    style: AppTypography.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Icon(
            Icons.arrow_back_ios_new,
            size: 15,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 9. ORDERS TAB VIEW (UNIFIED TOP HEADER)
  // ---------------------------------------------------------------------------

  Widget _buildOrdersTab(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            _buildTactileHeader(context, user),
            const SizedBox(height: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 90),
                child: OrdersHistoryScreen(showAppBar: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 11. FLOATING TICKET COUNTER / DOCK (التطبيقات - الألعاب - في الوسط طلباتي - خدمات - الاشتراكات)
  // ---------------------------------------------------------------------------

  Widget _buildFloatingDockNavBar(BuildContext context) {
    final catalog = Provider.of<AppCatalogProvider>(context);
    final activeOrdersCount = catalog.myOrders
        .where((o) => o.status == 'pending' || o.status == 'processing')
        .length;

    return SizedBox(
      height: 76,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. TICKET PASS DOCK WITH LIQUID SLIDING DROPLET
          ClipPath(
            clipper: TicketPassClipper(
              notchRadius: 8.5,
              notchPositionFraction: 0.5,
            ),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  const centerWidth = 52.0;
                  final tabWidth = (totalWidth - centerWidth) / 4;
                  const pillHeight = 44.0;
                  final pillWidth = (tabWidth * 0.88).clamp(52.0, 68.0);

                  double startPos = 0.0;
                  double currentPillWidth = pillWidth;
                  double pillOpacity = 1.0;

                  switch (_currentIndex) {
                    case 0: // التطبيقات (Right side in RTL)
                      startPos = 0 * tabWidth + (tabWidth - pillWidth) / 2;
                      break;
                    case 1: // الألعاب
                      startPos = 1 * tabWidth + (tabWidth - pillWidth) / 2;
                      break;
                    case 2: // طلباتي (Center floating button)
                      currentPillWidth = 36.0;
                      startPos =
                          2 * tabWidth + (centerWidth - currentPillWidth) / 2;
                      pillOpacity = 0.0; // Dissolves into center button!
                      break;
                    case 3: // خدمات
                      startPos =
                          2 * tabWidth +
                          centerWidth +
                          (tabWidth - pillWidth) / 2;
                      break;
                    case 4: // الاشتراكات (Left side in RTL)
                      startPos =
                          3 * tabWidth +
                          centerWidth +
                          (tabWidth - pillWidth) / 2;
                      break;
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Liquid Yellow Droplet (قطرة ماء سائلة تنزلق بنعومة)
                      AnimatedPositionedDirectional(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        start: startPos,
                        top: (58.0 - pillHeight) / 2,
                        width: currentPillWidth,
                        height: pillHeight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: pillOpacity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                begin: Alignment.bottomLeft,
                                end: Alignment.topRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Surface water droplet reflection gloss (لمعة قطرة الماء السائلة)
                                Positioned(
                                  top: 2,
                                  left: 6,
                                  right: 6,
                                  child: Container(
                                    height: 1.8,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.75),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Dock Tabs Row
                      Row(
                        children: [
                          // Tab 0: التطبيقات (Right side in RTL)
                          Expanded(
                            child: _buildDockItem(
                              index: 0,
                              label: "التطبيقات",
                              iconActive: Icons.apps_rounded,
                              iconInactive: Icons.apps_outlined,
                            ),
                          ),

                          // Tab 1: الألعاب
                          Expanded(
                            child: _buildDockItem(
                              index: 1,
                              label: "الألعاب",
                              iconActive: Icons.sports_esports_rounded,
                              iconInactive: Icons.sports_esports_outlined,
                            ),
                          ),

                          // Center space for "طلباتي"
                          const SizedBox(width: centerWidth),

                          // Tab 3: خدمات
                          Expanded(
                            child: _buildDockItem(
                              index: 3,
                              label: "خدمات",
                              iconActive: Icons.miscellaneous_services_rounded,
                              iconInactive:
                                  Icons.miscellaneous_services_outlined,
                            ),
                          ),

                          // Tab 4: الاشتراكات (Left side in RTL)
                          Expanded(
                            child: _buildDockItem(
                              index: 4,
                              label: "الاشتراكات",
                              iconActive: Icons.subscriptions_rounded,
                              iconInactive: Icons.subscriptions_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // TAB 2: CENTER FLOATING BUTTON: طلباتي (في الوسط)
          Positioned(
            bottom: 14,
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _currentIndex == 2
                          ? const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _currentIndex == 2
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFBAE6FD),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_currentIndex == 2
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF0284C7))
                                  .withValues(alpha: 0.55),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: _currentIndex == 2
                              ? const Color(0xFF020617)
                              : Colors.white,
                          size: 24,
                        ),
                        if (activeOrdersCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                '$activeOrdersCount',
                                style: AppTypography.plusJakartaSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "طلباتي",
                    style: AppTypography.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: _currentIndex == 2
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF7DD3FC),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockItem({
    required int index,
    required String label,
    required IconData iconActive,
    required IconData iconInactive,
  }) {
    final isSelected = _currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? iconActive : iconInactive,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFF020617)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTypography.cairo(
                  fontSize: isSelected ? 10.0 : 9.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF020617)
                      : const Color(0xFF94A3B8),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
