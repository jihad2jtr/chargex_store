import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_catalog_provider.dart';
import '../../widgets/digital_pass_card.dart';
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
      0; // 0 = التطبيقات, 1 = الألعاب, 2 = طلباتي, 3 = خدمات, 4 = المحفظة

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppCatalogProvider>(context, listen: false).fetchApps();
      Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
      Provider.of<AuthProvider>(context, listen: false).refreshProfile();
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
              _buildWalletTab(context), // 4: المحفظة
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
    final user = auth.currentUser;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await catalog.fetchApps();
          await auth.refreshProfile();
          await catalog.fetchMyOrders();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 115),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                _buildTactileHeader(context, user),
                const SizedBox(height: 10),
                _buildExchangeRateBar(),
                const SizedBox(height: 12),
                if (categoryType == 'games' || categoryType == 'apps') ...[
                  HeroTicketBanner(
                    onTap: () {
                      final pubg = catalog.apps.firstWhere(
                        (a) =>
                            a.name.toLowerCase().contains('pubg') ||
                            a.name.contains('ببجي'),
                        orElse: () => catalog.apps.isNotEmpty
                            ? catalog.apps.first
                            : AppItemModel(
                                id: 'pubg-promo',
                                name: 'ببجي موبايل',
                                iconUrl: '',
                              ),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AppProductsScreen(app: pubg),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
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
  // 4. DIGITAL FINANCIAL PASSPORT (سعر الصرف اليوم)
  // ---------------------------------------------------------------------------

  Widget _buildExchangeRateBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF082F49)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.airplane_ticket,
                  size: 17,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 8),
                Text(
                  "سعر الصرف اليوم 1 دولار  =  13800 ل.س",
                  style: AppTypography.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE2E8F0),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "VERIFIED",
                  style: AppTypography.technicalCode(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. SECTION TITLE: VOUCHER CATALOG
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(
    BuildContext context,
    AppCatalogProvider catalog, {
    String categoryType = 'apps',
  }) {
    String titleText = "تطبيقات الشحن والخدمات الرقمية";
    String badgeText = "APPS CATALOG";

    if (categoryType == 'games') {
      titleText = "شحن الألعاب والشدات والعملات";
      badgeText = "ROYALE GAMES";
    } else if (categoryType == 'services') {
      titleText = "البطاقات والاشتراكات والخدمات";
      badgeText = "DIGITAL SERVICES";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
            Text(
              titleText,
              style: AppTypography.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
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
      ],
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
    return 1.48;
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

    List<AppItemModel> filteredApps = catalog.apps;
    if (categoryType == 'games') {
      filteredApps = catalog.apps.where((a) {
        final n = a.name.toLowerCase();
        final c = (a.category ?? '').toLowerCase();
        return n.contains('pubg') ||
            n.contains('ببجي') ||
            n.contains('fire') ||
            n.contains('فاير') ||
            n.contains('game') ||
            n.contains('لعب') ||
            n.contains('steam') ||
            n.contains('roblox') ||
            n.contains('fortnite') ||
            n.contains('cod') ||
            c.contains('game') ||
            c.contains('لعب');
      }).toList();
      if (filteredApps.isEmpty) {
        final sampleGames = samplePasses
            .where(
              (p) =>
                  p.tktCode.contains('PUBG') ||
                  p.tktCode.contains('FF') ||
                  p.title.contains('ببجي') ||
                  p.title.contains('فاير'),
            )
            .toList();
        return _buildPassesListGrid(
          context,
          sampleGames.isNotEmpty ? sampleGames : samplePasses,
        );
      }
    } else if (categoryType == 'services') {
      filteredApps = catalog.apps.where((a) {
        final n = a.name.toLowerCase();
        final c = (a.category ?? '').toLowerCase();
        return n.contains('card') ||
            n.contains('بطاق') ||
            n.contains('itunes') ||
            n.contains('play') ||
            n.contains('net') ||
            n.contains('اشتراك') ||
            n.contains('خدم') ||
            c.contains('بطاق') ||
            c.contains('اشتراك') ||
            c.contains('خدم');
      }).toList();
      if (filteredApps.isEmpty) {
        final sampleServices = samplePasses
            .where(
              (p) =>
                  !p.tktCode.contains('PUBG') &&
                  !p.tktCode.contains('FF') &&
                  !p.title.contains('ببجي') &&
                  !p.title.contains('فاير'),
            )
            .toList();
        return _buildPassesListGrid(
          context,
          sampleServices.isNotEmpty ? sampleServices : samplePasses,
        );
      }
    } else if (categoryType == 'apps') {
      filteredApps = catalog.apps.where((a) {
        final n = a.name.toLowerCase();
        final c = (a.category ?? '').toLowerCase();
        final isGame =
            n.contains('pubg') ||
            n.contains('ببجي') ||
            n.contains('fire') ||
            n.contains('فاير') ||
            n.contains('steam') ||
            n.contains('roblox') ||
            c.contains('game') ||
            c.contains('لعب');
        return !isGame;
      }).toList();
      if (filteredApps.isEmpty) {
        filteredApps = catalog.apps;
      }
    }

    final int crossAxisCount = _getResponsiveCrossAxisCount(context);
    final double childAspectRatio = _getResponsiveChildAspectRatio(context);
    final double spacing = MediaQuery.of(context).size.width >= 900 ? 14 : 12;

    if (filteredApps.isNotEmpty) {
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

    return _buildPassesListGrid(context, samplePasses);
  }

  Widget _buildPassesListGrid(
    BuildContext context,
    List<DigitalPassItem> passes,
  ) {
    final int crossAxisCount = _getResponsiveCrossAxisCount(context);
    final double childAspectRatio = _getResponsiveChildAspectRatio(context);
    final double spacing = MediaQuery.of(context).size.width >= 900 ? 14 : 12;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: passes.length,
      itemBuilder: (context, index) {
        final passItem = passes[index];
        return DigitalPassCardWidget(
          item: passItem,
          imageOnly: true,
          onTapCharge: () {
            final catalog = Provider.of<AppCatalogProvider>(
              context,
              listen: false,
            );
            final app = catalog.apps.isNotEmpty
                ? catalog.apps.firstWhere(
                    (a) =>
                        a.name.toLowerCase() == passItem.title.toLowerCase() ||
                        a.name.contains(passItem.title),
                    orElse: () => catalog.apps.first,
                  )
                : AppItemModel(
                    id: passItem.id,
                    name: passItem.title,
                    iconUrl: passItem.imageUrl,
                  );
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppProductsScreen(app: app)),
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
            const SizedBox(height: 10),
            // Orders Header Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'طلباتي وتذاكر الشحن // MY ORDERS',
                        style: AppTypography.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 20),
                    tooltip: 'تحديث الطلبات',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Provider.of<AppCatalogProvider>(
                        context,
                        listen: false,
                      ).fetchMyOrders();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
  // 10. WALLET TAB VIEW (UNIFIED TOP HEADER)
  // ---------------------------------------------------------------------------

  Widget _buildWalletTab(BuildContext context) {
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
            const SizedBox(height: 10),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 90),
                child: TopupScreen(showAppBar: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 11. FLOATING TICKET COUNTER / DOCK (التطبيقات - الألعاب - في الوسط طلباتي - خدمات - المحفظة)
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
                      startPos = 2 * tabWidth + (centerWidth - currentPillWidth) / 2;
                      pillOpacity = 0.0; // Dissolves into center button!
                      break;
                    case 3: // خدمات
                      startPos = 2 * tabWidth + centerWidth + (tabWidth - pillWidth) / 2;
                      break;
                    case 4: // المحفظة (Left side in RTL)
                      startPos = 3 * tabWidth + centerWidth + (tabWidth - pillWidth) / 2;
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
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFFFBBF24),
                                ],
                                begin: Alignment.bottomLeft,
                                end: Alignment.topRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
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
                              iconInactive: Icons.miscellaneous_services_outlined,
                            ),
                          ),

                          // Tab 4: المحفظة (Left side in RTL)
                          Expanded(
                            child: _buildDockItem(
                              index: 4,
                              label: "المحفظة",
                              iconActive: Icons.account_balance_wallet_rounded,
                              iconInactive: Icons.account_balance_wallet_outlined,
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
                          color: (_currentIndex == 2
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
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
