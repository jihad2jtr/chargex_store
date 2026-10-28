import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_icon_assets.dart';
import '../../core/constants/card_assets.dart';
import '../../core/constants/product_kinds.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_asset_picker.dart';
import '../../widgets/app_thumb.dart';
import 'app_products_management_screen.dart';

class AppsAndProductsManagementScreen extends StatefulWidget {
  final String? initialAppId;

  const AppsAndProductsManagementScreen({super.key, this.initialAppId});

  @override
  State<AppsAndProductsManagementScreen> createState() =>
      _AppsAndProductsManagementScreenState();
}

class _AppsAndProductsManagementScreenState
    extends State<AppsAndProductsManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedCategory =
      'all'; // 'all' | 'game' | 'app' | 'service' | 'subscription' | 'inactive'

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
          final targetApp = admin.adminApps.firstWhere(
            (a) => a.id == widget.initialAppId,
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppProductsManagementScreen(app: targetApp),
            ),
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

    // لا يُسمح بتفعيل تطبيق/خدمة بلا منتج مفعّل واحد على الأقل
    if (!wasActive) {
      final activeProducts = admin.adminProducts
          .where((p) => p.appId == app.id && p.isActive)
          .length;
      if (activeProducts == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن تفعيل "${app.name}": أضف منتجاً مفعّلاً واحداً على الأقل أولاً ⚠️',
              style: AppTypography.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.ticketAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

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
            style: AppTypography.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: ok
              ? (!wasActive ? AppColors.accentGreen : AppColors.error)
              : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Add / Edit App Dialog with Neo-Bento UI & Asset Category Filters ---
  void _openAddEditAppDialog([AppItemModel? app]) {
    final nameCtrl = TextEditingController(text: app?.name ?? '');
    final iconCtrl = TextEditingController(text: app?.iconUrl ?? '');
    // الفئة التفصيلية للتطبيق: قائمة «باقات» / «عملات» (تُحفظ كعنوان عربي)
    String selectedKind = productKindFromText(
      app?.category,
      fallback: kBuiltinProductKinds.first.key,
    );
    final orderCtrl = TextEditingController(
      text: (app?.sortOrder ?? 0).toString(),
    );
    String selectedAppType = (app?.appType.isNotEmpty ?? false)
        ? app!.appType
        : 'game';
    bool isUploading = false; // رفع صورة من المعرض داخل النافذة

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final iconUrl = iconCtrl.text.trim();

            // رفع صورة من معرض الجهاز عبر منفذ الرفع العام في اللوحة
            Future<void> pickFromGallery() async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final image = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
                maxWidth: 1024,
              );
              if (image == null) return;

              setDialogState(() => isUploading = true);
              final url = await admin.uploadBannerImage(
                await image.readAsBytes(),
                image.name,
              );
              setDialogState(() {
                isUploading = false;
                if (url != null) iconCtrl.text = url;
              });
              if (url == null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      admin.errorMessage ?? 'تعذّر رفع الصورة',
                      style: AppTypography.cairo(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.darkNav,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              app == null
                                  ? Icons.add_to_photos_rounded
                                  : Icons.edit_rounded,
                              color: AppColors.ticketAmber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              app == null
                                  ? 'إضافة تطبيق / خدمة جديدة'
                                  : 'تعديل بيانات التطبيق',
                              style: AppTypography.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Dialog Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // App Name
                            Text(
                              'اسم التطبيق أو الخدمة *',
                              style: AppTypography.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: nameCtrl,
                              style: AppTypography.cairo(fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText:
                                    'مثال: ببجي موبايل، تيك توك، تيليغرام',
                                hintStyle: AppTypography.cairo(
                                  fontSize: 12.5,
                                  color: AppColors.slate400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.title_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.outline,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.outline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryBlue,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Type Selection (Game / App / Service / Subscription)
                            Text(
                              'النوع الرئيسي للتصنيف في المتجر',
                              style: AppTypography.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTypeSelectorChip(
                                  label: '🎮 لعبة',
                                  value: 'game',
                                  current: selectedAppType,
                                  onTap: () {
                                    setDialogState(
                                      () => selectedAppType = 'game',
                                    );
                                  },
                                ),
                                _buildTypeSelectorChip(
                                  label: '📱 تطبيق',
                                  value: 'app',
                                  current: selectedAppType,
                                  onTap: () {
                                    setDialogState(
                                      () => selectedAppType = 'app',
                                    );
                                  },
                                ),
                                _buildTypeSelectorChip(
                                  label: '🔧 خدمة',
                                  value: 'service',
                                  current: selectedAppType,
                                  onTap: () {
                                    setDialogState(
                                      () => selectedAppType = 'service',
                                    );
                                  },
                                ),
                                _buildTypeSelectorChip(
                                  label: '💎 اشتراك',
                                  value: 'subscription',
                                  current: selectedAppType,
                                  onTap: () {
                                    setDialogState(
                                      () => selectedAppType = 'subscription',
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              // يوضح للعميل أين ستظهر البطاقة
                              selectedAppType == 'game'
                                  ? 'ستظهر في صفحة الألعاب فقط'
                                  : selectedAppType == 'app'
                                  ? 'ستظهر في صفحة التطبيقات فقط'
                                  : selectedAppType == 'service'
                                  ? 'ستظهر في صفحة الخدمات والبطاقات فقط'
                                  : 'ستظهر في صفحة الاشتراكات فقط',
                              style: AppTypography.cairo(
                                fontSize: 11,
                                color: AppColors.slate500,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ===== صورة المنتج: أيقونة مربعة أو بطاقة أفقية =====
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الصورة التي ستظهر في المتجر',
                                    style: AppTypography.cairo(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'الأيقونة المربعة تظهر في شبكة التطبيقات، والبطاقة الأفقية تظهر في البطاقات العريضة للخدمات والاشتراكات.',
                                    style: AppTypography.cairo(
                                      fontSize: 10.5,
                                      color: AppColors.slate500,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildAssetPreviewRow(
                                    iconUrl: iconUrl,
                                    isUploading: isUploading,
                                    onClear: () => setDialogState(
                                      () => iconCtrl.text = '',
                                    ),
                                    onUpload: pickFromGallery,
                                  ),
                                  const SizedBox(height: 12),
                                  AppAssetPicker(
                                    selected: iconUrl,
                                    onSelected: (path, label, category) {
                                      setDialogState(() {
                                        iconCtrl.text = path;
                                        if (nameCtrl.text.trim().isEmpty) {
                                          nameCtrl.text = label;
                                        }
                                        // النوع يُشتق من تصنيف العنصر عند الإضافة فقط
                                        if (app == null) {
                                          selectedAppType = category;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Custom icon URL
                            TextField(
                              controller: iconCtrl,
                              style: AppTypography.cairo(fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'مسار أو رابط مخصص (اختياري)',
                                labelStyle: AppTypography.cairo(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                                prefixIcon: const Icon(
                                  Icons.link_rounded,
                                  color: AppColors.slate500,
                                  size: 18,
                                ),
                                hintText:
                                    'assets/icons/… أو assets/cards/… أو رابط https://',
                                hintStyle: AppTypography.cairo(
                                  fontSize: 11,
                                  color: AppColors.slate400,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.outline,
                                  ),
                                ),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'إن تُرك فارغاً وكان اسم المنتج معروفاً (مثل «شاهد» أو «PUBG Mobile») تُختار أيقونته الحقيقية تلقائياً.',
                              style: AppTypography.cairo(
                                fontSize: 10.5,
                                color: AppColors.slate500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Category & Sort Order in 2 Columns
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'الفئة التفصيلية',
                                        style: AppTypography.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: selectedKind,
                                        isExpanded: true,
                                        style: AppTypography.cairo(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.slate800,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            productKindIcon(selectedKind),
                                            color: AppColors.ticketAmber,
                                            size: 18,
                                          ),
                                          filled: true,
                                          fillColor: AppColors.background,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.outline,
                                            ),
                                          ),
                                        ),
                                        items: [
                                          for (final kind
                                              in kBuiltinProductKinds)
                                            DropdownMenuItem<String>(
                                              value: kind.key,
                                              child: Text(kind.label),
                                            ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setDialogState(
                                              () => selectedKind = val,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ترتيب الظهور',
                                        style: AppTypography.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: orderCtrl,
                                        keyboardType: TextInputType.number,
                                        style: AppTypography.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          prefixIcon: const Icon(
                                            Icons.sort_rounded,
                                            color: AppColors.slate500,
                                            size: 18,
                                          ),
                                          filled: true,
                                          fillColor: AppColors.background,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.outline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dialog Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(color: AppColors.outline),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.outline),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                'إلغاء',
                                style: AppTypography.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: Text(
                                app == null ? 'إضافة التطبيق' : 'حفظ التعديلات',
                                style: AppTypography.cairo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                final icon = iconCtrl.text.trim();
                                final order =
                                    int.tryParse(orderCtrl.text.trim()) ?? 0;

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'اسم التطبيق مطلوب',
                                        style: AppTypography.cairo(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                final admin = Provider.of<AdminProvider>(
                                  context,
                                  listen: false,
                                );

                                // منع تكرار التطبيقات: نفس الاسم (بعد التطبيع)
                                // لا يُسمح بإضافته مرة أخرى، ولا بإعادة تسمية
                                // تطبيق إلى اسم تطبيق آخر موجود
                                final normalizedName = _normalizeAppName(name);
                                final isDuplicate = admin.adminApps.any(
                                  (a) =>
                                      a.id != app?.id &&
                                      _normalizeAppName(a.name) ==
                                          normalizedName,
                                );
                                if (isDuplicate) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'يوجد تطبيق مسجّل بنفس الاسم "$name" بالفعل — لا يُسمح بالتكرار',
                                        style: AppTypography.cairo(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: AppColors.error,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                  return;
                                }

                                final data = {
                                  'name': name,
                                  // بلا اختيار: تُحلّ الأيقونة الحقيقية من الاسم إن كان معروفاً
                                  'iconUrl': icon.isNotEmpty
                                      ? icon
                                      : (builtinIconAssetForName(name) ??
                                            'https://placehold.co/150x150/png?text=$name'),
                                  'sortOrder': order,
                                  'category': productKindLabel(selectedKind),
                                  'appType': selectedAppType,
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
                                      content: Text(
                                        ok
                                            ? 'تم حفظ التطبيق بنجاح'
                                            : (admin.errorMessage ??
                                                  'حدث خطأ أثناء الحفظ'),
                                        style: AppTypography.cairo(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: ok
                                          ? AppColors.accentGreen
                                          : AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// تطبيع اسم التطبيق لمقارنة التكرار: يوحّد الهمزات والتاء المربوطة والألف
  /// المقصورة، ويحذف التشكيل والتطويل، ويجمع المسافات المتعددة.
  String _normalizeAppName(String value) {
    var text = value.toLowerCase().replaceAll(
      RegExp(r'[\u064B-\u0652\u0670\u0640]'),
      '',
    ); // تشكيل + تطويل
    text = text
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  /// معاينة الصورة المختارة + زر رفع صورة من معرض الجهاز
  Widget _buildAssetPreviewRow({
    required String iconUrl,
    required bool isUploading,
    required VoidCallback onClear,
    required Future<void> Function() onUpload,
  }) {
    final bool isCard = iconUrl.startsWith('assets/cards/');
    final bool isBuiltinIcon = iconUrl.startsWith('assets/icons/');
    final bool isRemote =
        iconUrl.startsWith('http://') || iconUrl.startsWith('https://');
    final String sourceLabel = iconUrl.isEmpty
        ? 'لم تُختَر صورة بعد'
        : isCard
        ? 'بطاقة أفقية من مكتبة المشروع'
        : isBuiltinIcon
        ? 'أيقونة مربعة من مكتبة المشروع'
        : isRemote
        ? 'رابط خارجي'
        : 'ملف مرفوع على السيرفر';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(isCard ? 10 : 15),
                child: iconUrl.isEmpty
                    ? Container(
                        width: 56,
                        height: 56,
                        color: AppColors.surfaceContainerHigh,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 22,
                          color: AppColors.slate400,
                        ),
                      )
                    : buildSmartAppImage(
                        iconUrl,
                        width: isCard ? 84 : 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceLabel,
                      style: AppTypography.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      iconUrl.isEmpty
                          ? 'اختَر من المكتبة بالأسفل أو ارفع صورة خاصة'
                          : iconUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 10,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (iconUrl.isNotEmpty)
                IconButton(
                  tooltip: 'مسح الاختيار',
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // الصور تُختار من المعرض فقط (مثل لوحة الإعلانات)
            onPressed: isUploading ? null : onUpload,
            icon: isUploading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined, size: 16),
            label: Text(
              isUploading ? 'جارٍ الرفع…' : 'رفع صورة من المعرض',
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryContainer),
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelectorChip({
    required String label,
    required String value,
    required String current,
    required VoidCallback onTap,
  }) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.cairo(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? AppColors.primaryBlue : AppColors.slate700,
          ),
        ),
      ),
    );
  }

  // --- Confirm Delete App Dialog ---
  void _confirmDeleteApp(AppItemModel app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.rose,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'تأكيد حذف التطبيق',
              style: AppTypography.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف التطبيق "${app.name}"؟\nسيتم حذف جميع الباقات التابعة له أيضاً بشكل نهائي.',
          style: AppTypography.cairo(
            fontSize: 13,
            color: AppColors.slate600,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                color: AppColors.slate600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final ok = await admin.deleteApp(app.id);
              if (ctx.mounted) Navigator.of(ctx).pop();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'تم حذف التطبيق بنجاح' : 'فشل حذف التطبيق',
                      style: AppTypography.cairo(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: ok
                        ? AppColors.accentGreen
                        : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'حذف نهائياً',
              style: AppTypography.cairo(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    // Compute Metrics
    final totalApps = admin.adminApps.length;
    final activeAppsCount = admin.adminApps.where((a) => a.isActive).length;
    final inactiveAppsCount = totalApps - activeAppsCount;
    final totalProductsCount = admin.adminProducts.length;

    // Filter apps by search & category
    final query = _searchCtrl.text.trim().toLowerCase();
    final apps = admin.adminApps.where((a) {
      // Search filter
      if (query.isNotEmpty) {
        final matchName = a.name.toLowerCase().contains(query);
        final matchCat = (a.category ?? '').toLowerCase().contains(query);
        if (!matchName && !matchCat) return false;
      }

      // Category filter — يعتمد على النوع الرئيسي فقط
      if (_selectedCategory == 'inactive') {
        return !a.isActive;
      } else if (_selectedCategory == 'game' ||
          _selectedCategory == 'app' ||
          _selectedCategory == 'service' ||
          _selectedCategory == 'subscription') {
        return a.appType == _selectedCategory;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.widgets_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة التطبيقات والمنتجات',
                    style: AppTypography.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      color: AppColors.slate900,
                    ),
                  ),
                  Text(
                    'APP & PRODUCT INVENTORY',
                    style: AppTypography.technicalCode(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate700),
            onPressed: () async {
              await admin.fetchAdminApps();
              await admin.fetchAdminProducts();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.add_rounded,
                size: 17,
                color: Colors.white,
              ),
              label: Text(
                'إضافة تطبيق',
                style: AppTypography.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openAddEditAppDialog(),
            ),
          ),
        ],
      ),
      body: admin.isLoading && admin.adminApps.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await admin.fetchAdminApps();
                await admin.fetchAdminProducts();
              },
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Executive Bento Stats Banner
                          _buildExecutiveBentoHeader(
                            totalApps: totalApps,
                            activeApps: activeAppsCount,
                            inactiveApps: inactiveAppsCount,
                            totalProducts: totalProductsCount,
                          ),
                          const SizedBox(height: 14),

                          // 2. Neo-Bento Search Box
                          _buildSearchField(),
                          const SizedBox(height: 12),

                          // 3. Category Filter Chips
                          _buildCategoryFiltersRow(
                            total: totalApps,
                            active: activeAppsCount,
                            inactive: inactiveAppsCount,
                          ),
                          const SizedBox(height: 12),

                          // 4. Section Subheader
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'التطبيقات المعروضة (${apps.length})',
                                    style: AppTypography.cairo(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                ],
                              ),
                              if (query.isNotEmpty ||
                                  _selectedCategory != 'all')
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _selectedCategory = 'all';
                                    });
                                  },
                                  child: Text(
                                    'إعادة ضبط الفلاتر',
                                    style: AppTypography.cairo(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.rose,
                                    ),
                                  ),
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
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.slate200.withValues(
                                    alpha: 0.6,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.apps_rounded,
                                  size: 48,
                                  color: AppColors.slate400,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'لا توجد تطبيقات مطابقة',
                                style: AppTypography.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'يمكنك إضافة تطبيق جديد أو تجربة تغيير فلاتر البحث',
                                style: AppTypography.cairo(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  'إضافة تطبيق الآن',
                                  style: AppTypography.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _openAddEditAppDialog(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                      sliver: SliverToBoxAdapter(child: _buildAppsList(apps)),
                    ),
                ],
              ),
            ),
    );
  }

  // --- Executive Bento Stats Header Banner ---
  Widget _buildExecutiveBentoHeader({
    required int totalApps,
    required int activeApps,
    required int inactiveApps,
    required int totalProducts,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkNav,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient gradient circle
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.ticketAmber.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.dashboard_customize_rounded,
                            color: AppColors.ticketAmber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أدارة المنتجات',
                              style: AppTypography.cairo(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'تعديل بيانات المنتجات',
                              style: AppTypography.cairo(
                                fontSize: 11,
                                color: AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065F46),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accentGreen.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        'LIVE SYSTEM',
                        style: AppTypography.technicalCode(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6EE7B7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4 Metric Bento Tiles
                Row(
                  children: [
                    _buildMetricBentoSlot(
                      title: 'إجمالي التطبيقات',
                      value: '$totalApps',
                      icon: Icons.apps_rounded,
                      accentColor: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricBentoSlot(
                      title: 'تطبيقات نشطة',
                      value: '$activeApps',
                      icon: Icons.check_circle_rounded,
                      accentColor: AppColors.accentGreen,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricBentoSlot(
                      title: 'معطلة ومخفية',
                      value: '$inactiveApps',
                      icon: Icons.visibility_off_rounded,
                      accentColor: AppColors.rose,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricBentoSlot(
                      title: 'باقات الشحن',
                      value: '$totalProducts',
                      icon: Icons.inventory_2_rounded,
                      accentColor: AppColors.ticketAmber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBentoSlot({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 14, color: accentColor),
                Text(
                  value,
                  style: AppTypography.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Neo-Bento Search Box ---
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AppTypography.cairo(fontSize: 13.5, color: AppColors.slate900),
        decoration: InputDecoration(
          hintText: 'ابحث عن اسم التطبيق أو الفئة...',
          hintStyle: AppTypography.cairo(
            fontSize: 12.5,
            color: AppColors.slate400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.primaryBlue,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // --- Category Filter Chips Row ---
  Widget _buildCategoryFiltersRow({
    required int total,
    required int active,
    required int inactive,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryFilterChip('الكل ($total)', 'all'),
          const SizedBox(width: 8),
          _buildCategoryFilterChip('🎮 ألعاب', 'game'),
          const SizedBox(width: 8),
          _buildCategoryFilterChip('📱 تطبيقات', 'app'),
          const SizedBox(width: 8),
          _buildCategoryFilterChip('🔧 خدمات وبطاقات', 'service'),
          const SizedBox(width: 8),
          _buildCategoryFilterChip('💎 اشتراكات', 'subscription'),
          const SizedBox(width: 8),
          _buildCategoryFilterChip('🚫 معطل ومخفي ($inactive)', 'inactive'),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label, String key) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkNav : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.darkNav : AppColors.outline,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.darkNav.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }

  // --- قائمة موحدة بدون فراغات بين الصفوف (نمط إدارة المستخدمين) ---
  Widget _buildAppsList(List<AppItemModel> apps) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < apps.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: AppColors.outline),
            _buildAppTile(apps[i]),
          ],
        ],
      ),
    );
  }

  Color _appTypeColor(String? type) {
    switch (type) {
      case 'game':
        return AppColors.ticketAmber;
      case 'service':
        return AppColors.tertiary;
      case 'subscription':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.primaryBlue;
    }
  }

  String _appTypeLabel(AppItemModel app) {
    switch (app.appType) {
      case 'game':
        return 'لعبة';
      case 'app':
        return 'تطبيق';
      case 'service':
        return 'خدمة / بطاقة';
      case 'subscription':
        return 'اشتراك';
      default:
        return 'غير محدد';
    }
  }

  // --- App Tile: صف مضغوط (أيقونة + اسم + شارات + عدد الباقات + إجراءات) ---
  Widget _buildAppTile(AppItemModel app) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final productCount = admin.adminProducts
        .where((p) => p.appId == app.id)
        .length;
    final typeColor = _appTypeColor(app.appType);
    final isActive = app.isActive;

    return Material(
      color: isActive ? Colors.white : AppColors.rose.withValues(alpha: 0.04),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppProductsManagementScreen(app: app),
            ),
          );
        },
        child: Stack(
          children: [
            // شريط لون نوع التطبيق على الحافة
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      typeColor,
                      Color.lerp(typeColor, Colors.white, 0.55)!,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  // أيقونة التطبيق + مؤشر الحالة
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.outline),
                        ),
                        // الأيقونة المربعة كما يراها العميل، لا فنّ البطاقة المقتطع
                        child: AppThumb(app: app, size: 44, radius: 12),
                      ),
                      Positioned(
                        top: 1,
                        right: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppColors.accentGreen
                                : AppColors.rose,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildAppTypeBadge(_appTypeLabel(app), typeColor),
                            const SizedBox(width: 6),
                            _buildAppStatusPill(isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // عدد الباقات (قيمة على الطرف)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$productCount',
                        style: AppTypography.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'باقة',
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  // قائمة الإجراءات
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.slate600,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'تعديل التطبيق',
                              style: AppTypography.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 16,
                              color: AppColors.ticketAmber,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isActive ? 'إخفاء عن العملاء' : 'عرض للعملاء',
                              style: AppTypography.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ticketAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_rounded,
                              size: 16,
                              color: AppColors.rose,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'حذف التطبيق',
                              style: AppTypography.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.rose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') _openAddEditAppDialog(app);
                      if (val == 'toggle') _handleToggleAppActive(app);
                      if (val == 'delete') _confirmDeleteApp(app);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTypeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: AppTypography.cairo(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAppStatusPill(bool isActive) {
    final color = isActive ? AppColors.tertiary : AppColors.rose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'معروض' : 'مخفي',
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
