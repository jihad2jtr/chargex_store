import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/banner_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_catalog_provider.dart';

class BannersManagementScreen extends StatefulWidget {
  const BannersManagementScreen({super.key});

  @override
  State<BannersManagementScreen> createState() =>
      _BannersManagementScreenState();
}

class _BannersManagementScreenState extends State<BannersManagementScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAdminBanners();
    });
  }

  void _showAddOrEditBannerDialog({BannerModel? banner}) {
    final isEditing = banner != null;
    final titleController = TextEditingController(text: banner?.title ?? '');
    final descriptionController = TextEditingController(
      text: banner?.description ?? '',
    );
    final imageUrlController = TextEditingController(
      text: banner?.imageUrl ?? '',
    );
    final sortOrderController = TextEditingController(
      text: (banner?.sortOrder ?? 0).toString(),
    );

    String actionType = banner?.actionType ?? 'topup';
    bool isActive = banner?.isActive ?? true;
    bool isUploading = false;
    String previewImageUrl = banner?.imageUrl ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                final XFile? image = await _picker.pickImage(
                  source: source,
                  imageQuality: 80,
                  maxWidth: 1200,
                );

                if (image == null) return;

                final bytes = await image.readAsBytes();
                final mimeType = image.name.toLowerCase().endsWith('.png')
                    ? 'image/png'
                    : 'image/jpeg';

                // معاينة فورية محلية أثناء رفع الصورة إلى الخادم
                setDialogState(() {
                  previewImageUrl =
                      'data:$mimeType;base64,${base64Encode(bytes)}';
                  isUploading = true;
                });

                final url = await admin.uploadBannerImage(bytes, image.name);

                if (!dialogCtx.mounted) return;
                setDialogState(() {
                  isUploading = false;
                  if (url != null) {
                    imageUrlController.text = url;
                    previewImageUrl = url;
                  } else {
                    imageUrlController.clear();
                    previewImageUrl = '';
                  }
                });

                if (url == null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(admin.errorMessage ?? 'فشل رفع الصورة'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() => isUploading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل اختيار الصورة: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            }

            void showImageSourcePicker() {
              showModalBottomSheet(
                context: dialogCtx,
                backgroundColor: AppColors.surfaceContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (sheetCtx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'اختر مصدر صورة الإعلان',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(
                            Icons.photo_library_outlined,
                            color: AppColors.primaryContainer,
                          ),
                          title: const Text('اختيار من معرض الصور'),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.secondary,
                          ),
                          title: const Text('التقاط صورة بالكاميرا'),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickImage(ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_photo_alternate,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'تعديل الإعلان' : 'إضافة إعلان جديد',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Preview Box (Cropped to Billboard Card Size 2:1)
                      const Text(
                        'معاينة كرت الإعلان (مقصوص تلقائياً):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.outline),
                            gradient: AppColors.holographicCardGradient,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Cropped Background
                              if (previewImageUrl.isNotEmpty)
                                _buildPreviewImage(previewImageUrl)
                              else
                                const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 40,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'لم يتم اختيار صورة بعد',
                                        style: TextStyle(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Shading gradient for readable text
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.88),
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.65, 1.0],
                                  ),
                                ),
                              ),

                              // مؤشر الرفع
                              if (isUploading)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                                ),

                              // Preview Text Overlay
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      titleController.text.isNotEmpty
                                          ? titleController.text
                                          : 'عنوان الإعلان التجريبي',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      descriptionController.text.isNotEmpty
                                          ? descriptionController.text
                                          : 'هنا يظهر النص الوصفي للإعلان المقصوص بدقة داخل الكرت',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Image Pick Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isUploading
                                  ? null
                                  : showImageSourcePicker,
                              icon: const Icon(Icons.add_a_photo, size: 16),
                              label: const Text(
                                'اختيار / التقاط صورة',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primaryContainer,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          if (previewImageUrl.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'مسح الصورة',
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.error,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  previewImageUrl = '';
                                  imageUrlController.clear();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Direct URL input (alternative option)
                      TextField(
                        controller: imageUrlController,
                        enabled: !isUploading,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'أو رابط الصورة المباشر (URL)',
                          hintText: 'https://...',
                          prefixIcon: const Icon(Icons.link),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check, size: 18),
                            onPressed: () {
                              setDialogState(() {
                                previewImageUrl = imageUrlController.text
                                    .trim();
                              });
                            },
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            previewImageUrl = val.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // Title
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الإعلان *',
                          hintText: 'مثال: عرض خاص على شحن المحفظة',
                          prefixIcon: Icon(Icons.title),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Description (نص وصفي)
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'النص الوصفي للإعلان *',
                          hintText:
                              'اكتب نصاً وصفياً يوضح تفاصيل الإعلان أو العرض...',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Action Type selector
                      DropdownButtonFormField<String>(
                        initialValue: actionType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الإجراء عند الضغط',
                          prefixIcon: Icon(Icons.touch_app),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'topup',
                            child: Text('فتح صفحة شحن المحفظة'),
                          ),
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('بدون إجراء (عرض فقط)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => actionType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Sort Order
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ترتيب العرض (0 للأعلى أولوية)',
                          prefixIcon: Icon(Icons.sort),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Active Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'تفعيل الإعلان فوراً',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'الإعلانات المفعلة تظهر مباشرة للمستخدمين في لوحة الإعلانات',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: isActive,
                        onChanged: (val) {
                          setDialogState(() => isActive = val);
                        },
                        activeThumbColor: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final description = descriptionController.text.trim();
                          final imageUrl = previewImageUrl.trim();
                          final sortOrder =
                              int.tryParse(sortOrderController.text.trim()) ??
                              0;

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال عنوان الإعلان'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          if (imageUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'يرجى اختيار صورة للإعلان أو إدخال رابطها',
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
                          final catalog = Provider.of<AppCatalogProvider>(
                            context,
                            listen: false,
                          );

                          final data = {
                            'title': title,
                            'description': description,
                            'imageUrl': imageUrl,
                            'actionType': actionType,
                            'sortOrder': sortOrder,
                            'isActive': isActive,
                          };

                          bool success;
                          if (isEditing) {
                            success = await admin.updateBanner(banner.id, data);
                          } else {
                            success = await admin.createBanner(data);
                          }

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }

                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'تم تحديث الإعلان بنجاح'
                                        : 'تمت إضافة الإعلان بنجاح',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              // Refresh client catalog banners too
                              catalog.fetchBanners();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    admin.errorMessage ?? 'فشلت العملية',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الإعلان'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Content = url.split(',').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return const Center(
          child: Icon(Icons.broken_image, color: AppColors.error),
        );
      }
    } else {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: AppColors.error),
        ),
      );
    }
  }

  void _confirmDeleteBanner(BannerModel banner) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('حذف الإعلان', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الإعلان "${banner.title}"؟ لن يتم عرضه بعد ذلك في لوحة الإعلانات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final catalog = Provider.of<AppCatalogProvider>(
                context,
                listen: false,
              );

              final success = await admin.deleteBanner(banner.id);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الإعلان بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  catalog.fetchBanners();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(admin.errorMessage ?? 'فشل الحذف'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final banners = admin.adminBanners;
    final activeCount = banners.where((b) => b.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'إدارة لوحة الإعلانات',
          style: AppTypography.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh, color: AppColors.slate600),
            onPressed: () => admin.fetchAdminBanners(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditBannerDialog(),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
        label: Text(
          'إضافة إعلان',
          style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: admin.isLoading && banners.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : RefreshIndicator(
              onRefresh: () => admin.fetchAdminBanners(),
              color: AppColors.primaryBlue,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // Swiss Neo-Bento Executive Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.slate900,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.slate900.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.campaign_outlined,
                                    color: AppColors.ticketAmber,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'لوحة الإعلانات الترويجية',
                                      style: AppTypography.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'BILLBOARD & PROMO PASSES',
                                      style: AppTypography.technicalCode(
                                        fontSize: 10,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.emerald.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.emerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$activeCount نشط',
                                    style: AppTypography.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'إجمالي الإعلانات',
                              banners.length.toString(),
                              Icons.view_carousel_outlined,
                              Colors.white,
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            _buildStatItem(
                              'المعروضة بالرئيسية',
                              activeCount.toString(),
                              Icons.check_circle_outline,
                              AppColors.emerald,
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            _buildStatItem(
                              'التبديل التلقائي',
                              '5s',
                              Icons.timer_outlined,
                              AppColors.ticketAmber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإعلانات المسجلة (${banners.length})',
                        style: AppTypography.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        'مرتبة حسب الأولوية',
                        style: AppTypography.cairo(
                          fontSize: 12,
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (banners.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 56,
                            color: AppColors.slate600.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد إعلانات حالياً في لوحة الإعلانات',
                            style: AppTypography.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'عند عدم وجود إعلانات، يتم عرض بطاقة شحن المحفظة الافتراضية في الواجهة الرئيسية.',
                            textAlign: TextAlign.center,
                            style: AppTypography.cairo(
                              fontSize: 12,
                              color: AppColors.slate600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _showAddOrEditBannerDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              'إضافة أول إعلان الآن',
                              style: AppTypography.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...banners.map((banner) => _buildBannerAdminCard(banner)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              value,
              style: AppTypography.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.cairo(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildBannerAdminCard(BannerModel banner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: banner.isActive
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : AppColors.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aspect-ratio Cropped Card (Billboard)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreviewImage(banner.imageUrl),

                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),

                  // Top badges
                  Positioned(
                    top: 10,
                    right: 12,
                    left: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: banner.isActive
                                ? AppColors.emerald.withValues(alpha: 0.9)
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                banner.isActive
                                    ? Icons.check_circle
                                    : Icons.pause_circle_outline,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                banner.isActive ? 'نشط في اللوحة' : 'معطّل',
                                style: AppTypography.cairo(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            banner.actionType == 'topup'
                                ? 'إجراء: شحن المحفظة'
                                : 'بدون إجراء',
                            style: AppTypography.cairo(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom content (Title & Description)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (banner.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            banner.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Toolbar Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // Sort Order Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    'الترتيب: ${banner.sortOrder}',
                    style: AppTypography.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
                const Spacer(),

                // Toggle Active Switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      banner.isActive ? 'مفعّل' : 'معطّل',
                      style: AppTypography.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: banner.isActive
                            ? AppColors.emerald
                            : AppColors.slate600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: banner.isActive,
                      activeThumbColor: AppColors.emerald,
                      onChanged: (val) async {
                        final admin = Provider.of<AdminProvider>(
                          context,
                          listen: false,
                        );
                        final catalog = Provider.of<AppCatalogProvider>(
                          context,
                          listen: false,
                        );
                        await admin.toggleBannerActive(banner.id);
                        catalog.fetchBanners();
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 6),

                // Edit button
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.slate600,
                  ),
                  onPressed: () => _showAddOrEditBannerDialog(banner: banner),
                ),

                // Delete button
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.rose,
                  ),
                  onPressed: () => _confirmDeleteBanner(banner),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
