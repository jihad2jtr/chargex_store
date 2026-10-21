import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/card_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
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
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final admin = Provider.of<AdminProvider>(context, listen: false);

    if (admin.adminApps.isEmpty) {
      await admin.fetchAdminApps();
    }

    final products = await admin.fetchProviderProducts(widget.provider.id);
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
      items.sort((a, b) => ((a['costPrice'] ?? 0) as num).compareTo((b['costPrice'] ?? 0) as num));

      String? img;
      String? code;
      int importedCount = 0;
      double minP = double.infinity;
      double maxP = 0.0;

      for (final it in items) {
        if (img == null && it['rawDetails'] != null && it['rawDetails']['image_url'] != null) {
          img = it['rawDetails']['image_url']?.toString();
        }
        if (code == null && it['rawDetails'] != null && it['rawDetails']['game_code'] != null) {
          code = it['rawDetails']['game_code']?.toString();
        }
        if (it['isImported'] == true) importedCount++;
        final cost = (it['costPrice'] is num) ? (it['costPrice'] as num).toDouble() : 0.0;
        if (cost < minP) minP = cost;
        if (cost > maxP) maxP = cost;
      }

      if (minP == double.infinity) minP = 0.0;

      // If no image from provider, infer from bundled card assets
      if (img == null || img.isEmpty) {
        final query = categoryName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (final card in kBuiltinCardAssets) {
          final cardSlug = card.nameEn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final fileSlug = card.assetPath.split('/').last.replaceAll('.png', '').replaceAll('-', '');
          if (cardSlug.contains(query) || query.contains(cardSlug) || fileSlug.contains(query) || query.contains(fileSlug)) {
            img = card.assetPath;
            break;
          }
        }
      }

      groups.add(ProviderAppGroup(
        name: categoryName,
        code: code,
        imageUrl: img,
        products: items,
        minPrice: minP,
        maxPrice: maxP,
        importedCount: importedCount,
      ));
    });

    groups.sort((a, b) => b.products.length.compareTo(a.products.length));

    if (mounted) {
      setState(() {
        _appGroups = groups;
        _isLoading = false;
      });
      _applySearch();
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
        final pkgMatch = g.products.any((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(q) ||
            (p['providerProductCode'] ?? '').toString().toLowerCase().contains(q));
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
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('جاري مزامنة جميع التطبيقات والألعاب من المزود...')),
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
      final query = prefillNameEn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final card in kBuiltinCardAssets) {
        final cardSlug = card.nameEn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final fileSlug = card.assetPath.split('/').last.replaceAll('.png', '').replaceAll('-', '');
        if (cardSlug.contains(query) || query.contains(cardSlug) || fileSlug.contains(query) || query.contains(fileSlug)) {
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
              : kBuiltinCardAssets.where((c) => c.category == cardCategoryFilter).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                                colors: [AppColors.primaryBlue, AppColors.primary],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_box_rounded, color: Colors.white, size: 22),
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
                                  style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600),
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
                          prefixIcon: const Icon(Icons.translate_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          prefixIcon: const Icon(Icons.category_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.surfaceContainerHigh,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'game', child: Text('🎮 لعبة')),
                          DropdownMenuItem(value: 'app', child: Text('📱 تطبيق')),
                          DropdownMenuItem(value: 'service', child: Text('🔧 خدمة')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedType = val);
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
                                onTap: () => setDialogState(() => useExternalUrl = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !useExternalUrl ? AppColors.primaryBlue : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.collections_rounded,
                                          size: 16,
                                          color: !useExternalUrl ? Colors.white : AppColors.slate600),
                                      const SizedBox(width: 6),
                                      Text(
                                        'صور الكروت (${kBuiltinCardAssets.length})',
                                        style: AppTypography.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: !useExternalUrl ? Colors.white : AppColors.slate600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => useExternalUrl = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: useExternalUrl ? AppColors.primaryBlue : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.link_rounded,
                                          size: 16,
                                          color: useExternalUrl ? Colors.white : AppColors.slate600),
                                      const SizedBox(width: 6),
                                      Text(
                                        'رابط خارجي',
                                        style: AppTypography.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: useExternalUrl ? Colors.white : AppColors.slate600,
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
                            prefixIcon: const Icon(Icons.image_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              child: buildSmartAppImage(imageUrlCtrl.text.trim(), width: 120, height: 80),
                            ),
                          ),
                        ],
                      ] else ...[
                        // Filter pills (الكل, ألعاب, تطبيقات, خدمات)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('الكل', 'all', cardCategoryFilter, (val) => setDialogState(() => cardCategoryFilter = val)),
                              const SizedBox(width: 6),
                              _buildFilterChip('🎮 ألعاب', 'game', cardCategoryFilter, (val) => setDialogState(() => cardCategoryFilter = val)),
                              const SizedBox(width: 6),
                              _buildFilterChip('📱 تطبيقات', 'app', cardCategoryFilter, (val) => setDialogState(() => cardCategoryFilter = val)),
                              const SizedBox(width: 6),
                              _buildFilterChip('🔧 خدمات', 'service', cardCategoryFilter, (val) => setDialogState(() => cardCategoryFilter = val)),
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
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: filteredCards.length,
                            itemBuilder: (_, i) {
                              final card = filteredCards[i];
                              final isSelected = selectedCard?.assetPath == card.assetPath;

                              return GestureDetector(
                                onTap: () => setDialogState(() {
                                  selectedCard = card;
                                  if (nameArCtrl.text.isEmpty || kBuiltinCardAssets.any((c) => c.nameAr == nameArCtrl.text)) {
                                    nameArCtrl.text = card.nameAr;
                                  }
                                  if (nameEnCtrl.text.isEmpty || kBuiltinCardAssets.any((c) => c.nameEn == nameEnCtrl.text)) {
                                    nameEnCtrl.text = card.nameEn;
                                  }
                                  selectedType = card.category;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryBlue.withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primaryBlue : AppColors.outline,
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? AppColors.primaryBlue.withValues(alpha: 0.2)
                                            : Colors.black.withValues(alpha: 0.04),
                                        blurRadius: isSelected ? 8 : 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Card Image
                                        Expanded(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.asset(
                                                card.assetPath,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, st) => Container(
                                                  color: AppColors.surfaceContainerHigh,
                                                  child: const Icon(Icons.broken_image, size: 24),
                                                ),
                                              ),
                                              if (isSelected)
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: const BoxDecoration(
                                                      color: AppColors.primaryBlue,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Card Title
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                          color: isSelected
                                              ? AppColors.primaryBlue.withValues(alpha: 0.1)
                                              : Colors.white,
                                          child: Column(
                                            children: [
                                              Text(
                                                card.nameAr,
                                                style: AppTypography.cairo(
                                                  fontSize: 10,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                  color: isSelected ? AppColors.primaryBlue : AppColors.slate900,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                card.nameEn,
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: isSelected ? AppColors.primaryBlue : AppColors.slate500,
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
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(selectedCard!.assetPath, width: 36, height: 36, fit: BoxFit.cover),
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
                                      style: const TextStyle(fontSize: 9, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('إلغاء', style: AppTypography.cairo(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                'حفظ التطبيق',
                                style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: () async {
                                final nameAr = nameArCtrl.text.trim();
                                final nameEn = nameEnCtrl.text.trim();
                                if (nameAr.isEmpty || nameEn.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('يرجى إدخال الاسم بالعربية والإنجليزية')),
                                  );
                                  return;
                                }

                                String iconUrl;
                                if (useExternalUrl) {
                                  iconUrl = imageUrlCtrl.text.trim();
                                  if (iconUrl.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('يرجى إدخال رابط الصورة')),
                                    );
                                    return;
                                  }
                                } else {
                                  if (selectedCard == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('يرجى اختيار صورة كرت من القائمة')),
                                    );
                                    return;
                                  }
                                  iconUrl = selectedCard!.assetPath;
                                }

                                final displayName = '$nameAr - $nameEn';
                                final admin = Provider.of<AdminProvider>(ctx, listen: false);
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
                                    content: Text(ok ? 'تم إضافة "$displayName" بنجاح ✅' : 'فشل في إضافة التطبيق'),
                                    backgroundColor: ok ? AppColors.tertiary : AppColors.error,
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

  Widget _buildFilterChip(String label, String value, String current, ValueChanged<String> onSelected) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.surfaceContainerHigh,
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('تطبيقات مزود: ${widget.provider.name}'),
        actions: [
          // Add New App button
          IconButton(
            tooltip: 'إضافة تطبيق/لعبة جديدة للمتجر',
            icon: const Icon(Icons.add_box_rounded),
            onPressed: _openAddAppDialog,
          ),
          // Sync all
          IconButton(
            tooltip: 'مزامنة وتحديث جميع التطبيقات من المزود',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _isSyncing ? null : _syncProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProviderInfoHeader(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_outlined, color: AppColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.provider.name,
                    style: AppTypography.cairo(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_appGroups.length} تطبيق/لعبة • ${_rawProducts.length} باقة إجمالية',
                    style: AppTypography.plusJakartaSans(fontSize: 11, color: AppColors.slate600),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(status: widget.provider.status),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'رصيد: \$${widget.provider.balance.toStringAsFixed(2)}',
                  style: AppTypography.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald),
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
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTypography.cairo(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ابحث عن لعبة أو تطبيق (مثال: PUBG, Free Fire, Mobile Legends)...',
            hintStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate600),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate600),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.slate600),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _applySearch();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredAppGroups.length,
      itemBuilder: (context, index) {
        final group = _filteredAppGroups[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: group.importedCount > 0 ? AppColors.emerald.withValues(alpha: 0.4) : AppColors.outline,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openAppPackagesModal(group),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // App Image / Avatar (supports bundled card artwork & URL)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: buildSmartAppImage(
                          group.imageUrl,
                          width: 54,
                          height: 54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: AppTypography.arabicCardTitle(fontSize: 15, color: AppColors.slate900),
                                ),
                              ),
                              if (group.importedCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${group.importedCount} بالكتالوج',
                                    style: AppTypography.cairo(
                                        fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.products.length} باقة شحن متوفرة',
                            style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'الأسعار: من \$${group.minPrice.toStringAsFixed(2)} إلى \$${group.maxPrice.toStringAsFixed(2)}',
                            style: AppTypography.plusJakartaSans(
                                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'الباقات',
                            style: AppTypography.cairo(
                                fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primaryBlue),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 54, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد تطبيقات مطابقة لـ "$_searchQuery"'
                : 'لا توجد تطبيقات مسجلة\nاضغط على 🔄 للمزامنة مع المزود',
            style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  final TextEditingController _packageSearchController = TextEditingController();

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
          final code = (p['providerProductCode'] ?? '').toString().toLowerCase();
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

    final double costPrice = (item['costPrice'] is num) ? (item['costPrice'] as num).toDouble() : 0.0;
    String selectedAppId = admin.adminApps.first.id;

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('استيراد الباقة للكتالوج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'الكود: ${item['providerProductCode']} | ${widget.appGroup.name}',
                            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تكلفة المزود:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                              Text(
                                '\$${costPrice.toStringAsFixed(2)} USD',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'سعر البيع وهامش الربح يُحدَّد لاحقاً من لوحة إدارة المنتجات',
                              style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, height: 1.4),
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
                              prefixIcon: const Icon(Icons.apps_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: admin.adminApps.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Row(
                                  children: [
                                    buildSmartAppImage(a.iconUrl, width: 22, height: 22, borderRadius: BorderRadius.circular(4)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedAppId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'إضافة تطبيق/لعبة جديدة',
                          child: InkWell(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await widget.onAddNewApp(prefillNameEn: widget.appGroup.name);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.primaryBlue, size: 22),
                            ),
                          ),
                        ),
                      ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ok = await admin.importProviderProduct(
                      providerId: widget.provider.id,
                      providerProductId: item['_id'] ?? item['id'],
                      appId: selectedAppId,
                    );
                    if (mounted) {
                      setState(() => item['isImported'] = true);
                      widget.onProductImported();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'تم استيراد الباقة بنجاح ✅' : (admin.errorMessage ?? 'حدث خطأ')),
                          backgroundColor: ok ? AppColors.tertiary : AppColors.error,
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('لاحقاً')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.playlist_add_check, color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'استيراد جميع باقات ${widget.appGroup.name}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                        'سيتم استيراد جميع الـ ${widget.appGroup.products.length} باقة دفعة واحدة.\nسعر البيع وهامش الربح يُضبط لاحقاً من لوحة التحكم.',
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
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سعر البيع وهامش الربح يُحدَّد لاحقاً من لوحة إدارة المنتجات',
                              style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, height: 1.4),
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
                              prefixIcon: const Icon(Icons.apps_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: admin.adminApps.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Row(
                                  children: [
                                    buildSmartAppImage(a.iconUrl, width: 22, height: 22, borderRadius: BorderRadius.circular(4)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedAppId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'إضافة تطبيق/لعبة جديدة',
                          child: InkWell(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await widget.onAddNewApp(prefillNameEn: widget.appGroup.name);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.primaryBlue, size: 22),
                            ),
                          ),
                        ),
                      ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      SnackBar(content: Text('جاري استيراد ${ids.length} باقة...')),
                    );

                    final ok = await admin.batchImportProviderProducts(
                      providerId: widget.provider.id,
                      providerProductIds: ids,
                      appId: selectedAppId,
                    );

                    if (mounted) {
                      setState(() {
                        for (final it in _items) { it['isImported'] = true; }
                      });
                      widget.onProductImported();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'تم استيراد جميع باقات اللعبة بنجاح! ✅' : 'حدث خطأ أثناء الاستيراد'),
                          backgroundColor: ok ? AppColors.tertiary : AppColors.error,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
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
                      Text(widget.appGroup.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('${widget.appGroup.products.length} باقة شحن متاحة',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                // Add New App button
                Tooltip(
                  message: 'إضافة تطبيق/لعبة جديدة',
                  child: IconButton(
                    icon: const Icon(Icons.add_box_outlined, color: AppColors.primaryBlue),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.onAddNewApp(prefillNameEn: widget.appGroup.name);
                    },
                  ),
                ),
                // Batch Import All button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.playlist_add_check, size: 16),
                  label: const Text('استيراد الكل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _openBatchImportDialog,
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search inside packages
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: TextField(
                controller: _packageSearchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'ابحث في باقات ${widget.appGroup.name}...',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.onSurfaceVariant),
                  suffixIcon: _filterQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () {
                            _packageSearchController.clear();
                            _filterPackages('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onChanged: _filterPackages,
              ),
            ),
          ),

          const Divider(height: 16, color: AppColors.outline),

          // Packages List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      _filterQuery.isNotEmpty ? 'لا توجد باقات مطابقة لـ "$_filterQuery"' : 'لا توجد باقات',
                      style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, idx) {
                      final item = _filteredItems[idx];
                      final cost = (item['costPrice'] is num) ? (item['costPrice'] as num).toDouble() : 0.0;
                      final isImported = item['isImported'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isImported
                                ? AppColors.tertiary.withValues(alpha: 0.4)
                                : AppColors.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isImported
                                    ? AppColors.tertiaryContainer
                                    : AppColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isImported ? Icons.check_circle_outline : Icons.bolt_rounded,
                                size: 18,
                                color: isImported ? AppColors.tertiaryLight : AppColors.secondaryBright,
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
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      if (isImported) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'مضاف ✅',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.tertiaryLight),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'كود: ${item['providerProductCode']}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'التكلفة: \$${cost.toStringAsFixed(3)} USD',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            isImported
                                ? OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      side: BorderSide(color: AppColors.tertiary.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _openSingleImportDialog(item),
                                    child: const Text('نسخة +',
                                        style: TextStyle(fontSize: 11, color: AppColors.tertiaryLight)),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _openSingleImportDialog(item),
                                    child: const Text('استيراد',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
