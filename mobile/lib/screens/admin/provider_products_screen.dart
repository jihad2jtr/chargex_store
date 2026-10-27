import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/card_assets.dart';
import '../../core/services/cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_thumb.dart';
import '../../widgets/status_pill.dart';

// ==========================================
class ProviderAppGroup {
  final String name;
  final String? code;
  final String? imageUrl;
  final List<dynamic> products;
  final double minPrice;
  final double maxPrice;
  final int importedCount;

  ProviderAppGroup({
    required this.name,
    this.code,
    this.imageUrl,
    required this.products,
    required this.minPrice,
    required this.maxPrice,
    required this.importedCount,
  });
}

class ProviderProductsScreen extends StatefulWidget {
  final ProviderModel provider;

  const ProviderProductsScreen({super.key, required this.provider});

  @override
  State<ProviderProductsScreen> createState() => _ProviderProductsScreenState();
}

class _ProviderProductsScreenState extends State<ProviderProductsScreen> {
  List<dynamic> _rawProducts = [];
  List<ProviderAppGroup> _appGroups = [];
  List<ProviderAppGroup> _filteredAppGroups = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSyncing = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 0ms instant display from cache on first frame if cached previously
    final cached = CacheService.instance.getRawList(
      'provider_products_${widget.provider.id}',
    );
    if (cached != null && cached.isNotEmpty) {
      _populateGroups(cached);
      _isLoading = false;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _populateGroups(List<dynamic> products) {
    _rawProducts = products;

    final Map<String, List<dynamic>> groupedMap = {};
    for (final p in products) {
      final category = (p['category']?.toString().trim().isNotEmpty == true)
          ? p['category'].toString().trim()
          : 'عام';
      groupedMap.putIfAbsent(category, () => []).add(p);
    }

    final List<ProviderAppGroup> groups = [];
    groupedMap.forEach((categoryName, items) {
      items.sort(
        (a, b) => ((a['costPrice'] ?? 0) as num).compareTo(
          (b['costPrice'] ?? 0) as num,
        ),
      );

      String? img;
      String? code;
      int importedCount = 0;
      double minP = double.infinity;
      double maxP = 0.0;

      for (final it in items) {
        if (img == null &&
            it['rawDetails'] != null &&
            it['rawDetails']['image_url'] != null) {
          img = it['rawDetails']['image_url']?.toString();
        }
        if (code == null &&
            it['rawDetails'] != null &&
            it['rawDetails']['game_code'] != null) {
          code = it['rawDetails']['game_code']?.toString();
        }
        if (it['isImported'] == true) importedCount++;
        final cost = (it['costPrice'] is num)
            ? (it['costPrice'] as num).toDouble()
            : 0.0;
        if (cost < minP) minP = cost;
        if (cost > maxP) maxP = cost;
      }

      if (minP == double.infinity) minP = 0.0;

      // If no image from provider, infer from bundled card assets
      if (img == null || img.isEmpty) {
        final query = categoryName.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
        for (final card in kBuiltinCardAssets) {
          final cardSlug = card.nameEn.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );
          final fileSlug = card.assetPath
              .split('/')
              .last
              .replaceAll('.png', '')
              .replaceAll('-', '');
          if (cardSlug.contains(query) ||
              query.contains(cardSlug) ||
              fileSlug.contains(query) ||
              query.contains(fileSlug)) {
            img = card.assetPath;
            break;
          }
        }
      }

      groups.add(
        ProviderAppGroup(
          name: categoryName,
          code: code,
          imageUrl: img,
          products: items,
          minPrice: minP,
          maxPrice: maxP,
          importedCount: importedCount,
        ),
      );
    });

    groups.sort((a, b) => b.products.length.compareTo(a.products.length));
    _appGroups = groups;
    _applySearch();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_appGroups.isEmpty) {
      setState(() => _isLoading = true);
    }
    final admin = Provider.of<AdminProvider>(context, listen: false);

    if (admin.adminApps.isEmpty) {
      admin.fetchAdminApps();
    }

    // قوالب الخدمة لاختيار نوع حقول الإدخال عند الاستيراد
    if (admin.serviceTemplates.isEmpty) {
      admin.fetchServiceTemplates();
    }

    final products = await admin.fetchProviderProducts(
      widget.provider.id,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _populateGroups(products);
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      setState(() => _filteredAppGroups = List.from(_appGroups));
      return;
    }
    final q = _searchQuery.trim().toLowerCase();
    setState(() {
      _filteredAppGroups = _appGroups.where((g) {
        final nameMatch = g.name.toLowerCase().contains(q);
        final codeMatch = (g.code ?? '').toLowerCase().contains(q);
        final pkgMatch = g.products.any(
          (p) =>
              (p['name'] ?? '').toString().toLowerCase().contains(q) ||
              (p['providerProductCode'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(q),
        );
        return nameMatch || codeMatch || pkgMatch;
      }).toList();
    });
  }

  Future<void> _syncProducts() async {
    setState(() => _isSyncing = true);
    final admin = Provider.of<AdminProvider>(context, listen: false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('جاري مزامنة جميع التطبيقات والألعاب من المزود...'),
            ),
          ],
        ),
        duration: Duration(seconds: 60),
      ),
    );

    final res = await admin.syncProviderProducts(widget.provider.id);
    await _loadData();

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res?['message'] ?? 'تمت المزامنة بنجاح'),
          backgroundColor: res != null ? AppColors.tertiary : AppColors.error,
        ),
      );
    }
  }

  void _openAppPackagesModal(ProviderAppGroup appGroup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _AppPackagesModalSheet(
          provider: widget.provider,
          appGroup: appGroup,
          onProductImported: () => _loadData(),
          onAddNewApp: _openAddAppDialog,
        );
      },
    );
  }

  // ---- "Add New App" Dialog ----
  Future<void> _openAddAppDialog({String? prefillNameEn}) async {
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController(text: prefillNameEn ?? '');
    final imageUrlCtrl = TextEditingController();
    String selectedType = 'game';
    BuiltinCardAsset? selectedCard;
    bool useExternalUrl = false;
    String cardCategoryFilter = 'all';

    // Try auto-matching card artwork by prefillNameEn
    if (prefillNameEn != null && prefillNameEn.trim().isNotEmpty) {
      final query = prefillNameEn.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      for (final card in kBuiltinCardAssets) {
        final cardSlug = card.nameEn.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
        final fileSlug = card.assetPath
            .split('/')
            .last
            .replaceAll('.png', '')
            .replaceAll('-', '');
        if (cardSlug.contains(query) ||
            query.contains(cardSlug) ||
            fileSlug.contains(query) ||
            query.contains(fileSlug)) {
          selectedCard = card;
          if (nameArCtrl.text.isEmpty) nameArCtrl.text = card.nameAr;
          selectedType = card.category;
          break;
        }
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final filteredCards = cardCategoryFilter == 'all'
              ? kBuiltinCardAssets
              : kBuiltinCardAssets
                    .where((c) => c.category == cardCategoryFilter)
                    .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: SizedBox(
              width: MediaQuery.of(dialogCtx).size.width.clamp(300.0, 480.0),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primaryBlue,
                                  AppColors.primary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_box_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إضافة تطبيق / لعبة جديدة',
                                  style: AppTypography.cairo(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.slate900,
                                  ),
                                ),
                                Text(
                                  'اختر صورة الكرت المحفوظة في التطبيق أو رابط خارجي',
                                  style: AppTypography.cairo(
                                    fontSize: 11,
                                    color: AppColors.slate600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // Arabic Name
                      TextFormField(
                        controller: nameArCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'الاسم بالعربية *',
                          hintText: 'مثال: ببجي موبايل',
                          prefixIcon: const Icon(
                            Icons.translate_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerHigh,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // English Name
                      TextFormField(
                        controller: nameEnCtrl,
                        decoration: InputDecoration(
                          labelText: 'الاسم بالإنجليزية *',
                          hintText: 'مثال: PUBG Mobile',
                          prefixIcon: const Icon(Icons.abc_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerHigh,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Type dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: InputDecoration(
                          labelText: 'النوع *',
                          prefixIcon: const Icon(
                            Icons.category_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerHigh,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'game',
                            child: Text('🎮 لعبة'),
                          ),
                          DropdownMenuItem(
                            value: 'app',
                            child: Text('📱 تطبيق'),
                          ),
                          DropdownMenuItem(
                            value: 'service',
                            child: Text('🔧 خدمة'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Image Source Mode Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => useExternalUrl = false,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !useExternalUrl
                                        ? AppColors.primaryBlue
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(11),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.collections_rounded,
                                        size: 16,
                                        color: !useExternalUrl
                                            ? Colors.white
                                            : AppColors.slate600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'صور الكروت (${kBuiltinCardAssets.length})',
                                        style: AppTypography.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: !useExternalUrl
                                              ? Colors.white
                                              : AppColors.slate600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => useExternalUrl = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: useExternalUrl
                                        ? AppColors.primaryBlue
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(11),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.link_rounded,
                                        size: 16,
                                        color: useExternalUrl
                                            ? Colors.white
                                            : AppColors.slate600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'رابط خارجي',
                                        style: AppTypography.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: useExternalUrl
                                              ? Colors.white
                                              : AppColors.slate600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (useExternalUrl) ...[
                        TextFormField(
                          controller: imageUrlCtrl,
                          decoration: InputDecoration(
                            labelText: 'رابط الصورة (URL)',
                            hintText: 'https://example.com/card.png',
                            prefixIcon: const Icon(
                              Icons.image_rounded,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainerHigh,
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: buildSmartAppImage(
                                imageUrlCtrl.text.trim(),
                                width: 120,
                                height: 80,
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        // Filter pills (الكل, ألعاب, تطبيقات, خدمات)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                'الكل',
                                'all',
                                cardCategoryFilter,
                                (val) => setDialogState(
                                  () => cardCategoryFilter = val,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                '🎮 ألعاب',
                                'game',
                                cardCategoryFilter,
                                (val) => setDialogState(
                                  () => cardCategoryFilter = val,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                '📱 تطبيقات',
                                'app',
                                cardCategoryFilter,
                                (val) => setDialogState(
                                  () => cardCategoryFilter = val,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                '🔧 خدمات',
                                'service',
                                cardCategoryFilter,
                                (val) => setDialogState(
                                  () => cardCategoryFilter = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Grid of Bundled Card Images
                        SizedBox(
                          height: 230,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.9,
                                ),
                            itemCount: filteredCards.length,
                            itemBuilder: (_, i) {
                              final card = filteredCards[i];
                              final isSelected =
                                  selectedCard?.assetPath == card.assetPath;

                              return GestureDetector(
                                onTap: () => setDialogState(() {
                                  selectedCard = card;
                                  if (nameArCtrl.text.isEmpty ||
                                      kBuiltinCardAssets.any(
                                        (c) => c.nameAr == nameArCtrl.text,
                                      )) {
                                    nameArCtrl.text = card.nameAr;
                                  }
                                  if (nameEnCtrl.text.isEmpty ||
                                      kBuiltinCardAssets.any(
                                        (c) => c.nameEn == nameEnCtrl.text,
                                      )) {
                                    nameEnCtrl.text = card.nameEn;
                                  }
                                  selectedType = card.category;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryBlue.withValues(
                                            alpha: 0.08,
                                          )
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.outline,
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? AppColors.primaryBlue.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                        blurRadius: isSelected ? 8 : 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Card Image
                                        Expanded(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.asset(
                                                card.assetPath,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, st) =>
                                                    Container(
                                                      color: AppColors
                                                          .surfaceContainerHigh,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        size: 24,
                                                      ),
                                                    ),
                                              ),
                                              if (isSelected)
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: AppColors
                                                              .primaryBlue,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Card Title
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                          color: isSelected
                                              ? AppColors.primaryBlue
                                                    .withValues(alpha: 0.1)
                                              : Colors.white,
                                          child: Column(
                                            children: [
                                              Text(
                                                card.nameAr,
                                                style: AppTypography.cairo(
                                                  fontSize: 10,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? AppColors.primaryBlue
                                                      : AppColors.slate900,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                card.nameEn,
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: isSelected
                                                      ? AppColors.primaryBlue
                                                      : AppColors.slate500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Selected Card Indicator Summary
                      if (selectedCard != null && !useExternalUrl) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  selectedCard!.assetPath,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الكرت المختار: ${selectedCard!.nameAr} (${selectedCard!.nameEn})',
                                      style: AppTypography.cairo(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    Text(
                                      selectedCard!.assetPath,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                'إلغاء',
                                style: AppTypography.cairo(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                'حفظ التطبيق',
                                style: AppTypography.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () async {
                                final nameAr = nameArCtrl.text.trim();
                                final nameEn = nameEnCtrl.text.trim();
                                if (nameAr.isEmpty || nameEn.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'يرجى إدخال الاسم بالعربية والإنجليزية',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                String iconUrl;
                                if (useExternalUrl) {
                                  iconUrl = imageUrlCtrl.text.trim();
                                  if (iconUrl.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('يرجى إدخال رابط الصورة'),
                                      ),
                                    );
                                    return;
                                  }
                                } else {
                                  if (selectedCard == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'يرجى اختيار صورة كرت من القائمة',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  iconUrl = selectedCard!.assetPath;
                                }

                                final displayName = '$nameAr - $nameEn';
                                final admin = Provider.of<AdminProvider>(
                                  ctx,
                                  listen: false,
                                );
                                final ok = await admin.createAdminApp({
                                  'name': displayName,
                                  'nameAr': nameAr,
                                  'nameEn': nameEn,
                                  'category': selectedType,
                                  'iconUrl': iconUrl,
                                  'isActive': true,
                                });

                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'تم إضافة "$displayName" بنجاح ✅'
                                          : 'فشل في إضافة التطبيق',
                                    ),
                                    backgroundColor: ok
                                        ? AppColors.tertiary
                                        : AppColors.error,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String current,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          ' ${widget.provider.name}',
          style: AppTypography.cairo(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          // Add New App button
          IconButton(
            tooltip: 'إضافة تطبيق/لعبة جديدة للمتجر',
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            onPressed: _openAddAppDialog,
          ),
          // Sync all
          IconButton(
            tooltip: 'مزامنة وتحديث جميع التطبيقات من المزود',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0284C7),
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: Color(0xFF0284C7)),
            onPressed: _isSyncing ? null : _syncProducts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildProviderInfoHeader(),
          _buildSearchBar(),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoading && _appGroups.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  )
                : _filteredAppGroups.isEmpty
                ? _buildEmptyState()
                : _buildAppGroupsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfoHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: Color(0xFFA5B4FC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.provider.name,
                        style: AppTypography.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_appGroups.length} تطبيق ولعبة • ${_rawProducts.length} باقة شحن',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              StatusPill(status: widget.provider.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'رصيدك لدى المزود: ',
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '\$${widget.provider.balance.toStringAsFixed(2)} USD',
                    style: AppTypography.technicalCode(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _isSyncing ? null : _syncProducts,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sync_rounded,
                        size: 13,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'مزامنة فورية',
                        style: AppTypography.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: AppTypography.cairo(fontSize: 13),
          decoration: InputDecoration(
            hintText:
                'ابحث عن لعبة أو تطبيق (PUBG, Free Fire, Mobile Legends)...',
            hintStyle: AppTypography.cairo(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF64748B),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filteredAppGroups.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_filteredAppGroups.length}',
                      style: AppTypography.technicalCode(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _applySearch();
                    },
                  ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val);
            _applySearch();
          },
        ),
      ),
    );
  }

  Widget _buildAppGroupsList() {
    return RefreshIndicator(
      color: const Color(0xFF0284C7),
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _filteredAppGroups.length,
        itemBuilder: (context, index) {
          final group = _filteredAppGroups[index];
          final isPartiallyImported = group.importedCount > 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPartiallyImported
                    ? const Color(0xFF10B981).withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openAppPackagesModal(group),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // App Image / Avatar with soft rounded border & shadow
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: buildSmartAppImage(
                          group.imageUrl,
                          width: 56,
                          height: 56,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title, Stats, Price Range
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: AppTypography.cairo(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPartiallyImported) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${group.importedCount} بالمتجر',
                                      style: AppTypography.cairo(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${group.products.length} باقة شحن متاحة من المزود',
                              style: AppTypography.cairo(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'الأسعار: ',
                                  style: AppTypography.cairo(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  '\$${group.minPrice.toStringAsFixed(2)} - \$${group.maxPrice.toStringAsFixed(2)}',
                                  style: AppTypography.technicalCode(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // "View Packages" Action Button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFF0284C7,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'الباقات',
                              style: AppTypography.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: Color(0xFF0284C7),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 54,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد تطبيقات مطابقة لـ "$_searchQuery"'
                : 'لا توجد تطبيقات مسجلة\nاضغط على 🔄 للمزامنة مع المزود',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _applySearch();
              },
              child: const Text('مسح البحث'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('مزامنة الآن'),
              onPressed: _isSyncing ? null : _syncProducts,
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// POPUP MODAL SHEET: Packages for selected App
// ==========================================
class _AppPackagesModalSheet extends StatefulWidget {
  final ProviderModel provider;
  final ProviderAppGroup appGroup;
  final VoidCallback onProductImported;
  final Future<void> Function({String? prefillNameEn}) onAddNewApp;

  const _AppPackagesModalSheet({
    required this.provider,
    required this.appGroup,
    required this.onProductImported,
    required this.onAddNewApp,
  });

  @override
  State<_AppPackagesModalSheet> createState() => _AppPackagesModalSheetState();
}

class _AppPackagesModalSheetState extends State<_AppPackagesModalSheet> {
  late List<dynamic> _items;
  late List<dynamic> _filteredItems;
  String _filterQuery = '';
  final TextEditingController _packageSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.appGroup.products);
    _filteredItems = List.from(_items);
  }

  @override
  void dispose() {
    _packageSearchController.dispose();
    super.dispose();
  }

  void _filterPackages(String query) {
    setState(() {
      _filterQuery = query;
      if (query.trim().isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final q = query.trim().toLowerCase();
        _filteredItems = _items.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final code = (p['providerProductCode'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(q) || code.contains(q);
        }).toList();
      }
    });
  }

  // ---- Single Import (no margin at import time) ----
  void _openSingleImportDialog(Map<String, dynamic> item) {
    final admin = Provider.of<AdminProvider>(context, listen: false);

    if (admin.adminApps.isEmpty) {
      // No apps yet → prompt to create one
      _promptCreateApp();
      return;
    }

    final double costPrice = (item['costPrice'] is num)
        ? (item['costPrice'] as num).toDouble()
        : 0.0;
    String selectedAppId = admin.adminApps.first.id;

    // خيارات الاستيراد: الاسم المخصص، نوع حقول الإدخال، وحجم الكمية
    final nameCtrl = TextEditingController(
      text: (item['name'] ?? '').toString(),
    );
    final quantityCtrl = TextEditingController();
    String? selectedTemplateId;

    // Auto-match by category name
    final catLower = widget.appGroup.name.toLowerCase();
    for (final app in admin.adminApps) {
      final appNameLower = app.name.toLowerCase();
      if (catLower.contains(appNameLower) || appNameLower.contains(catLower)) {
        selectedAppId = app.id;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'استيراد الباقة للكتالوج',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الكود: ${item['providerProductCode']} | ${widget.appGroup.name}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'تكلفة المزود:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '\$${costPrice.toStringAsFixed(2)} USD',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info note about margin
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'سعر البيع يُحسب تلقائياً من نسبة ربح المزود',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // App selector + "Add New App" button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedAppId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'التطبيق في متجرك',
                              prefixIcon: const Icon(
                                Icons.apps_rounded,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: admin.adminApps.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Row(
                                  children: [
                                    AppThumb(app: a, size: 22, radius: 4),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedAppId = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'إضافة تطبيق/لعبة جديدة',
                          child: InkWell(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await widget.onAddNewApp(
                                prefillNameEn: widget.appGroup.name,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: AppColors.primaryBlue,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // اسم المنتج المخصص (عربي)
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'اسم المنتج في متجرك (عربي)',
                        prefixIcon: const Icon(Icons.title_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // حجم الكمية (وصفي)
                    TextField(
                      controller: quantityCtrl,
                      decoration: InputDecoration(
                        labelText: 'حجم الكمية (مثال: 60 UC)',
                        prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // نوع حقول الإدخال (قالب الخدمة)
                    DropdownButtonFormField<String?>(
                      initialValue: selectedTemplateId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'نوع حقول الإدخال (قالب الخدمة)',
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'تلقائي (حسب المزود)',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ...admin.serviceTemplates.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} • ${t.fields.length} حقول',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedTemplateId = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ok = await admin.importProviderProduct(
                      providerId: widget.provider.id,
                      providerProductId: item['_id'] ?? item['id'],
                      appId: selectedAppId,
                      name: nameCtrl.text.trim(),
                      serviceTemplateId: selectedTemplateId,
                      quantityLabel: quantityCtrl.text.trim(),
                    );
                    if (mounted) {
                      setState(() => item['isImported'] = true);
                      widget.onProductImported();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'تم استيراد الباقة بنجاح ✅'
                                : (admin.errorMessage ?? 'حدث خطأ'),
                          ),
                          backgroundColor: ok
                              ? AppColors.tertiary
                              : AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('تأكيد الاستيراد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptCreateApp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('لا توجد تطبيقات بعد'),
        content: const Text(
          'يجب أولاً إضافة تطبيق أو لعبة لمتجرك لربط الباقات بها.\nهل تريد إضافة تطبيق الآن؟',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('إضافة تطبيق'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await widget.onAddNewApp(prefillNameEn: widget.appGroup.name);
            },
          ),
        ],
      ),
    );
  }

  // ---- Batch Import All Packages ----
  void _openBatchImportDialog() {
    final admin = Provider.of<AdminProvider>(context, listen: false);

    if (admin.adminApps.isEmpty) {
      _promptCreateApp();
      return;
    }

    String selectedAppId = admin.adminApps.first.id;
    final catLower = widget.appGroup.name.toLowerCase();
    for (final app in admin.adminApps) {
      final appNameLower = app.name.toLowerCase();
      if (catLower.contains(appNameLower) || appNameLower.contains(catLower)) {
        selectedAppId = app.id;
        break;
      }
    }

    // خيارات الاستيراد الجماعي: تُطبَّق على كل الباقات المستوردة
    final nameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    String? selectedTemplateId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'استيراد جميع باقات ${widget.appGroup.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Text(
                        'سيتم استيراد جميع الـ ${widget.appGroup.products.length} باقة دفعة واحدة.\nسعر البيع يُحسب تلقائياً من نسبة ربح المزود.',
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سعر البيع يُحسب تلقائياً من نسبة ربح المزود',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // App selection + add new
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedAppId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'التطبيق في متجرك',
                              prefixIcon: const Icon(
                                Icons.apps_rounded,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: admin.adminApps.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Row(
                                  children: [
                                    AppThumb(app: a, size: 22, radius: 4),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedAppId = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'إضافة تطبيق/لعبة جديدة',
                          child: InkWell(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await widget.onAddNewApp(
                                prefillNameEn: widget.appGroup.name,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: AppColors.primaryBlue,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // اسم المنتج المخصص (عربي) - اختياري للاستيراد الجماعي
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText:
                            'اسم المنتج في متجرك (اتركه فارغاً للاحتفاظ باسم المزود)',
                        prefixIcon: const Icon(Icons.title_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // حجم الكمية (وصفي) - يُطبَّق على كل الباقات
                    TextField(
                      controller: quantityCtrl,
                      decoration: InputDecoration(
                        labelText: 'حجم الكمية (مثال: 60 UC)',
                        prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // نوع حقول الإدخال (قالب الخدمة)
                    DropdownButtonFormField<String?>(
                      initialValue: selectedTemplateId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'نوع حقول الإدخال (قالب الخدمة)',
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'تلقائي (حسب المزود)',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ...admin.serviceTemplates.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} • ${t.fields.length} حقول',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedTemplateId = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check, size: 16),
                  label: const Text('بدء استيراد الكل'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ids = widget.appGroup.products
                        .map((p) => (p['_id'] ?? p['id'] ?? '').toString())
                        .where((id) => id.isNotEmpty)
                        .toList();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('جاري استيراد ${ids.length} باقة...'),
                      ),
                    );

                    final ok = await admin.batchImportProviderProducts(
                      providerId: widget.provider.id,
                      providerProductIds: ids,
                      appId: selectedAppId,
                      name: nameCtrl.text.trim(),
                      serviceTemplateId: selectedTemplateId,
                      quantityLabel: quantityCtrl.text.trim(),
                    );

                    if (mounted) {
                      setState(() {
                        for (final it in _items) {
                          it['isImported'] = true;
                        }
                      });
                      widget.onProductImported();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'تم استيراد جميع باقات اللعبة بنجاح! ✅'
                                : 'حدث خطأ أثناء الاستيراد',
                          ),
                          backgroundColor: ok
                              ? AppColors.tertiary
                              : AppColors.error,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header: Game Image & Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: buildSmartAppImage(
                      widget.appGroup.imageUrl,
                      width: 48,
                      height: 48,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.appGroup.name,
                        style: AppTypography.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.appGroup.products.length} باقة شحن متاحة من المزود',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Add New App button
                Tooltip(
                  message: 'إضافة تطبيق/لعبة جديدة',
                  child: IconButton(
                    icon: const Icon(
                      Icons.add_box_outlined,
                      color: Color(0xFF0284C7),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.onAddNewApp(
                        prefillNameEn: widget.appGroup.name,
                      );
                    },
                  ),
                ),
                // Batch Import All button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                  label: Text(
                    'استيراد الكل',
                    style: AppTypography.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _openBatchImportDialog,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search inside packages
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _packageSearchController,
                style: AppTypography.cairo(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'ابحث في باقات ${widget.appGroup.name}...',
                  hintStyle: AppTypography.cairo(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  suffixIcon: _filterQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () {
                            _packageSearchController.clear();
                            _filterPackages('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _filterPackages,
              ),
            ),
          ),

          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // Packages List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      _filterQuery.isNotEmpty
                          ? 'لا توجد باقات مطابقة لـ "$_filterQuery"'
                          : 'لا توجد باقات مسجلة',
                      style: AppTypography.cairo(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, idx) {
                      final item = _filteredItems[idx];
                      final cost = (item['costPrice'] is num)
                          ? (item['costPrice'] as num).toDouble()
                          : 0.0;
                      final isImported = item['isImported'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isImported
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.35)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isImported
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.12)
                                    : const Color(
                                        0xFF0284C7,
                                      ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isImported
                                    ? Icons.check_circle_rounded
                                    : Icons.bolt_rounded,
                                size: 18,
                                color: isImported
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['name'] ?? '',
                                          style: AppTypography.cairo(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isImported) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            'مضاف بالمتجر ✅',
                                            style: AppTypography.cairo(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'كود الباقة: ${item['providerProductCode']}',
                                    style: AppTypography.technicalCode(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        'سعر التكلفة: ',
                                        style: AppTypography.cairo(
                                          fontSize: 10.5,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      Text(
                                        '\$${cost.toStringAsFixed(3)} USD',
                                        style: AppTypography.technicalCode(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            isImported
                                ? OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF10B981),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _openSingleImportDialog(item),
                                    child: Text(
                                      'نسخة +',
                                      style: AppTypography.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _openSingleImportDialog(item),
                                    child: Text(
                                      'استيراد',
                                      style: AppTypography.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
