import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/card_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../providers/admin_provider.dart';
import 'app_products_management_screen.dart';

class AppsAndProductsManagementScreen extends StatefulWidget {
  final String? initialAppId;

  const AppsAndProductsManagementScreen({super.key, this.initialAppId});

  @override
  State<AppsAndProductsManagementScreen> createState() => _AppsAndProductsManagementScreenState();
}

class _AppsAndProductsManagementScreenState extends State<AppsAndProductsManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      await admin.fetchAdminApps();
      await admin.fetchAdminProducts();

      // If initialAppId was passed, auto-navigate to its products page
      if (widget.initialAppId != null && mounted) {
        try {
          final targetApp = admin.adminApps.firstWhere((a) => a.id == widget.initialAppId);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AppProductsManagementScreen(app: targetApp)),
          );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- Toggle App Active (Show / Hide) ---
  Future<void> _handleToggleAppActive(AppItemModel app) async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final wasActive = app.isActive;

    final ok = await admin.toggleAppActive(app.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (!wasActive
                    ? 'تم تفعيل تطبيق "${app.name}" وإظهاره للعملاء ✅'
                    : 'تم تعطيل تطبيق "${app.name}" وإخفاؤه عن العملاء 🚫')
                : (admin.errorMessage ?? 'فشل تعديل حالة التطبيق'),
          ),
          backgroundColor: ok ? (!wasActive ? AppColors.tertiary : AppColors.error) : AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Add / Edit App Dialog ---
  void _openAddEditAppDialog([AppItemModel? app]) {
    final nameCtrl = TextEditingController(text: app?.name ?? '');
    final iconCtrl = TextEditingController(text: app?.iconUrl ?? '');
    final catCtrl = TextEditingController(text: app?.category ?? '');
    final orderCtrl = TextEditingController(text: (app?.sortOrder ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final iconUrl = iconCtrl.text.trim();

            return AlertDialog(
              backgroundColor: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(app == null ? Icons.add_to_photos : Icons.edit, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 8),
                  Text(app == null ? 'إضافة تطبيق جديد' : 'تعديل التطبيق'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(ctx).size.width.clamp(280.0, 480.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم التطبيق (مثال: ببجي موبايل، تيك توك)',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    // Card Image Picker & Mode Switch
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'صورة الكرت:',
                                style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800),
                              ),
                              if (iconUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: buildSmartAppImage(iconUrl, width: 28, height: 28),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Horizontal list of bundled card assets
                          SizedBox(
                            height: 64,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: kBuiltinCardAssets.length,
                              itemBuilder: (ctx, i) {
                                final card = kBuiltinCardAssets[i];
                                final isSelected = iconUrl == card.assetPath;
                                return GestureDetector(
                                  onTap: () => setDialogState(() {
                                    iconCtrl.text = card.assetPath;
                                    if (nameCtrl.text.isEmpty) nameCtrl.text = card.nameAr;
                                    if (catCtrl.text.isEmpty) catCtrl.text = card.category;
                                  }),
                                  child: Container(
                                    width: 54,
                                    margin: const EdgeInsets.only(left: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.asset(card.assetPath, fit: BoxFit.cover),
                                          if (isSelected)
                                            Container(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                              child: const Center(
                                                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: iconCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رابط صورة مخصص أو مسار الكرت',
                        prefixIcon: Icon(Icons.image_outlined),
                        hintText: 'assets/cards/... أو https://...',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الفئة (ألعاب، برامج، بطاقات، اشتراكات)',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب الظهور (0, 1, 2...)',
                        prefixIcon: Icon(Icons.sort),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final icon = iconCtrl.text.trim();
                    final order = int.tryParse(orderCtrl.text.trim()) ?? 0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('اسم التطبيق مطلوب')),
                      );
                      return;
                    }

                    final admin = Provider.of<AdminProvider>(context, listen: false);
                    final data = {
                      'name': name,
                      'iconUrl': icon.isNotEmpty ? icon : 'https://placehold.co/150x150/png?text=$name',
                      'sortOrder': order,
                      'category': catCtrl.text.trim(),
                    };

                    bool ok;
                    if (app == null) {
                      ok = await admin.createApp(data);
                    } else {
                      ok = await admin.updateApp(app.id, data);
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'تم حفظ التطبيق بنجاح' : (admin.errorMessage ?? 'حدث خطأ')),
                          backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('حفظ التطبيق'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirm Delete App Dialog ---
  void _confirmDeleteApp(AppItemModel app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد حذف التطبيق'),
        content: Text('هل أنت متأكد من حذف التطبيق "${app.name}"؟ سيتم حذف جميع الباقات التابعة له أيضاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final ok = await admin.deleteApp(app.id);
              if (ctx.mounted) Navigator.of(ctx).pop();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم حذف التطبيق بنجاح' : 'فشل حذف التطبيق'),
                    backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    // Filter apps by search
    final query = _searchCtrl.text.trim().toLowerCase();
    final apps = admin.adminApps.where((a) {
      if (query.isEmpty) return true;
      final matchName = a.name.toLowerCase().contains(query);
      final matchCat = (a.category ?? '').toLowerCase().contains(query);
      return matchName || matchCat;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'إدارة التطبيقات والمنتجات',
          style: AppTypography.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة تطبيق جديد',
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryBlue),
            onPressed: () => _openAddEditAppDialog(),
          ),
        ],
      ),
      body: admin.isLoading && admin.adminApps.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : RefreshIndicator(
              onRefresh: () async {
                await admin.fetchAdminApps();
                await admin.fetchAdminProducts();
              },
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                slivers: [
                  // Header description & Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.outline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.touch_app_outlined, color: AppColors.primaryBlue, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'اختر تطبيقاً لإدارة باقاته ومنتجاته',
                                        style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'انقر على أي تطبيق لعرض باقاته وتفعيلها أو إخفائها وتعديل الأسعار.',
                                        style: AppTypography.cairo(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Search field
                          TextField(
                            controller: _searchCtrl,
                            style: AppTypography.cairo(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن تطبيق أو فئة...',
                              hintStyle: AppTypography.cairo(fontSize: 13, color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryBlue),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'قائمة التطبيقات المتاحة (${apps.length})',
                                style: AppTypography.cairo(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text('إضافة تطبيق جديد', style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(foregroundColor: AppColors.secondaryBright),
                                onPressed: () => _openAddEditAppDialog(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Apps List
                  if (apps.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.apps_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text('لا توجد تطبيقات مطابقة', style: AppTypography.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('يمكنك إضافة تطبيق جديد ليبدأ بالظهور للعملاء',
                                  style: AppTypography.cairo(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_rounded),
                                label: Text('إضافة تطبيق الآن', style: AppTypography.arabicButton(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                onPressed: () => _openAddEditAppDialog(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final app = apps[index];
                            final productCount = admin.adminProducts.where((p) => p.appId == app.id).length;

                            return _buildAppListTile(
                              app: app,
                              productCount: productCount,
                              onTap: () {
                                // Navigate to dedicated products page for this app!
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AppProductsManagementScreen(app: app),
                                  ),
                                );
                              },
                              onToggleActive: () => _handleToggleAppActive(app),
                              onEdit: () => _openAddEditAppDialog(app),
                              onDelete: () => _confirmDeleteApp(app),
                            );
                          },
                          childCount: apps.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // Vertical App List Item Tile
  Widget _buildAppListTile({
    required AppItemModel app,
    required int productCount,
    required VoidCallback onTap,
    required VoidCallback onToggleActive,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // App Icon with Active Status Indicator
              Stack(
                children: [
                  buildSmartAppImage(
                    app.iconUrl,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: app.isActive ? AppColors.accentGreen : AppColors.error,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // App Name & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: app.isActive
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: app.isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            app.isActive ? 'نشط' : 'معطل ومخفي',
                            style: AppTypography.cairo(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: app.isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$productCount باقة شحن',
                            style: AppTypography.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        if (app.category != null && app.category!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${app.category}',
                            style: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Switch & Menu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: app.isActive,
                    activeThumbColor: AppColors.tertiary,
                    onChanged: (_) => onToggleActive(),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.onSurfaceVariant),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('تعديل التطبيق')]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('حذف التطبيق', style: TextStyle(color: AppColors.error)),
                        ]),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                    },
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.secondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
