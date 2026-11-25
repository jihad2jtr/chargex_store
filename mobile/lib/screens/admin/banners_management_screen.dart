import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/banner_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_catalog_provider.dart';
import '../../widgets/top_notice.dart';

class BannersManagementScreen extends StatefulWidget {
  const BannersManagementScreen({super.key});

  @override
  State<BannersManagementScreen> createState() =>
      _BannersManagementScreenState();
}

class _BannersManagementScreenState extends State<BannersManagementScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all | active | inactive

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAdminBanners();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BannerModel> _filteredBanners(List<BannerModel> banners) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return banners.where((b) {
      if (_statusFilter == 'active' && !b.isActive) return false;
      if (_statusFilter == 'inactive' && b.isActive) return false;
      if (q.isEmpty) return true;
      return '${b.title} ${b.description} ${b.actionValue ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _adjustSortOrder(BannerModel banner, int delta) async {
    final nextOrder = (banner.sortOrder + delta).clamp(0, 9999);
    if (nextOrder == banner.sortOrder) return;
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final catalog = Provider.of<AppCatalogProvider>(context, listen: false);
    final ok = await admin.updateBanner(banner.id, {'sortOrder': nextOrder});
    if (!mounted) return;
    if (ok) {
      catalog.fetchBanners();
    } else {
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(admin.errorMessage ?? 'تعذر تحديث الترتيب'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  InputDecoration _sheetInputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 19, color: AppColors.slate500),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.slate50,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
      ),
    );
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
    final linkController = TextEditingController(
      text: banner?.actionValue ?? '',
    );
    final sortOrderController = TextEditingController(
      text: (banner?.sortOrder ?? 0).toString(),
    );

    // الإعلان إما له رابط يُفتح عند الضغط عليه، أو "بدون رابط" (عرض فقط)
    bool noLink = (banner?.actionType ?? 'none') != 'url';
    bool isActive = banner?.isActive ?? true;
    bool isUploading = false;
    bool isSaving = false;
    String previewImageUrl = banner?.imageUrl ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // صورة الإعلان من معرض الصور فقط
            Future<void> pickImage() async {
              try {
                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 1200,
                );

                if (image == null) return;

                final bytes = await image.readAsBytes();
                final mimeType = image.name.toLowerCase().endsWith('.png')
                    ? 'image/png'
                    : 'image/jpeg';

                // معاينة فورية محلية أثناء رفع الصورة إلى الخادم
                setSheetState(() {
                  previewImageUrl =
                      'data:$mimeType;base64,${base64Encode(bytes)}';
                  isUploading = true;
                });

                final url = await admin.uploadBannerImage(bytes, image.name);

                if (!sheetCtx.mounted) return;
                setSheetState(() {
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
                  ScaffoldMessenger.of(context).showTopSnackBar(
                    SnackBar(
                      content: Text(admin.errorMessage ?? 'فشل رفع الصورة'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (sheetCtx.mounted) {
                  setSheetState(() => isUploading = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showTopSnackBar(
                    SnackBar(
                      content: Text('فشل اختيار الصورة: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                minChildSize: 0.55,
                maxChildSize: 0.95,
                builder: (_, scrollCtrl) => Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_rounded
                                  : Icons.add_photo_alternate_rounded,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEditing ? 'تعديل الإعلان' : 'إضافة إعلان جديد',
                              style: AppTypography.cairo(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.slate900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(sheetCtx).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.outline),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        children: [
                          Text(
                            'معاينة كرت الإعلان المباشرة',
                            style: AppTypography.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate700,
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
                                  if (isUploading)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          titleController.text.isNotEmpty
                                              ? titleController.text
                                              : 'عنوان الإعلان التجريبي',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.cairo(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
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
                                          style: AppTypography.cairo(
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
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploading ? null : pickImage,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    'اختيار صورة من المعرض',
                                    style: AppTypography.cairo(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryBlue,
                                    side: const BorderSide(
                                      color: AppColors.primaryBlue,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                  ),
                                ),
                              ),
                              if (previewImageUrl.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'مسح الصورة',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.roseWash,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_sweep_outlined,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () {
                                    setSheetState(() {
                                      previewImageUrl = '';
                                      imageUrlController.clear();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: imageUrlController,
                            enabled: !isUploading,
                            textDirection: TextDirection.ltr,
                            decoration: _sheetInputDecoration(
                              label: 'أو رابط الصورة المباشر (URL)',
                              hint: 'https://...',
                              icon: Icons.image_search_outlined,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.check_rounded, size: 18),
                                onPressed: () {
                                  setSheetState(() {
                                    previewImageUrl = imageUrlController.text
                                        .trim();
                                  });
                                },
                              ),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                previewImageUrl = val.trim();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: titleController,
                            decoration: _sheetInputDecoration(
                              label: 'عنوان الإعلان *',
                              hint: 'مثال: عرض خاص على شحن المحفظة',
                              icon: Icons.title_rounded,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionController,
                            maxLines: 2,
                            decoration: _sheetInputDecoration(
                              label: 'النص الوصفي للإعلان *',
                              hint:
                                  'اكتب نصاً وصفياً يوضح تفاصيل الإعلان أو العرض...',
                              icon: Icons.description_outlined,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'نوع التفاعل عند الضغط على الإعلان',
                            style: AppTypography.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('بدون رابط')),
                                  selected: noLink,
                                  onSelected: (_) =>
                                      setSheetState(() => noLink = true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(
                                    child: Text('رابط خارجي'),
                                  ),
                                  selected: !noLink,
                                  onSelected: (_) =>
                                      setSheetState(() => noLink = false),
                                ),
                              ),
                            ],
                          ),
                          if (!noLink) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: linkController,
                              textDirection: TextDirection.ltr,
                              keyboardType: TextInputType.url,
                              decoration: _sheetInputDecoration(
                                label: 'رابط الإعلان (يُفتح عند الضغط)',
                                hint: 'https://example.com',
                                icon: Icons.link_rounded,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: sortOrderController,
                            keyboardType: TextInputType.number,
                            decoration: _sheetInputDecoration(
                              label: 'ترتيب العرض (0 للأعلى أولوية)',
                              icon: Icons.sort_rounded,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.slate50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: SwitchListTile(
                              title: Text(
                                'تفعيل الإعلان فوراً',
                                style: AppTypography.cairo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                'الإعلانات المفعلة تظهر مباشرة للمستخدمين في لوحة الإعلانات',
                                style: AppTypography.cairo(fontSize: 11),
                              ),
                              value: isActive,
                              onChanged: (val) =>
                                  setSheetState(() => isActive = val),
                              activeThumbColor: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: AppColors.outline),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(sheetCtx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: isUploading || isSaving
                                  ? null
                                  : () async {
                                      final title = titleController.text.trim();
                                      final description =
                                          descriptionController.text.trim();
                                      final imageUrl = previewImageUrl.trim();
                                      final sortOrder =
                                          int.tryParse(
                                            sortOrderController.text.trim(),
                                          ) ??
                                          0;

                                      if (title.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showTopSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'يرجى إدخال عنوان الإعلان',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      if (imageUrl.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showTopSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'يرجى اختيار صورة للإعلان أو إدخال رابطها',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      final rawLink =
                                          linkController.text.trim();

                                      if (!noLink && rawLink.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showTopSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'يرجى إدخال رابط الإعلان أو اختيار "بدون رابط"',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      if (!noLink &&
                                          (rawLink.contains(' ') ||
                                              !rawLink.contains('.'))) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showTopSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'رابط الإعلان غير صالح',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      var link = rawLink;
                                      if (!noLink) {
                                        final parsedLink = Uri.tryParse(link);
                                        if (parsedLink == null ||
                                            !parsedLink.hasScheme) {
                                          link = 'https://$link';
                                        }
                                      }

                                      setSheetState(() => isSaving = true);
                                      final admin = Provider.of<AdminProvider>(
                                        context,
                                        listen: false,
                                      );
                                      final catalog =
                                          Provider.of<AppCatalogProvider>(
                                            context,
                                            listen: false,
                                          );

                                      final data = {
                                        'title': title,
                                        'description': description,
                                        'imageUrl': imageUrl,
                                        'actionType': noLink ? 'none' : 'url',
                                        'actionValue': noLink ? '' : link,
                                        'sortOrder': sortOrder,
                                        'isActive': isActive,
                                      };

                                      bool success;
                                      if (isEditing) {
                                        success = await admin.updateBanner(
                                          banner.id,
                                          data,
                                        );
                                      } else {
                                        success = await admin.createBanner(
                                          data,
                                        );
                                      }

                                      if (sheetCtx.mounted) {
                                        Navigator.of(sheetCtx).pop();
                                      }

                                      if (mounted) {
                                        if (success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showTopSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isEditing
                                                    ? 'تم تحديث الإعلان بنجاح'
                                                    : 'تمت إضافة الإعلان بنجاح',
                                              ),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                          catalog.fetchBanners();
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showTopSnackBar(
                                            SnackBar(
                                              content: Text(
                                                admin.errorMessage ??
                                                    'فشلت العملية',
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.slate900,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: Text(
                                isEditing ? 'حفظ التعديلات' : 'إضافة الإعلان',
                              ),
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
                  ScaffoldMessenger.of(context).showTopSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الإعلان بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  catalog.fetchBanners();
                } else {
                  ScaffoldMessenger.of(context).showTopSnackBar(
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
    final inactiveCount = banners.length - activeCount;
    final filtered = _filteredBanners(banners);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة لوحة الإعلانات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate600),
            onPressed: () => admin.fetchAdminBanners(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: SizedBox(
        height: 42,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddOrEditBannerDialog(),
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 17),
          label: Text(
            'إضافة إعلان',
            style: AppTypography.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.slate900,
          foregroundColor: Colors.white,
          elevation: 2,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
      body: admin.isLoading && banners.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : RefreshIndicator(
              onRefresh: () => admin.fetchAdminBanners(),
              color: AppColors.primaryBlue,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 68),
                children: [
                  // Swiss Neo-Bento Executive Banner (Compact)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.slate900,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.slate800),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.campaign_outlined,
                                    color: AppColors.ticketAmber,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'لوحة الإعلانات الترويجية',
                                      style: AppTypography.cairo(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'BILLBOARD & PROMO PASSES',
                                      style: AppTypography.technicalCode(
                                        fontSize: 9,
                                        color: Colors.white60,
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
                                color: AppColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
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
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: AppColors.emerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$activeCount نشط',
                                    style: AppTypography.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 8),
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
                              height: 28,
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
                              height: 28,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            _buildStatItem(
                              'معطّلة',
                              inactiveCount.toString(),
                              Icons.pause_circle_outline,
                              AppColors.ticketAmber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (banners.isNotEmpty) ...[
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.cairo(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'ابحث في الإعلانات...',
                        hintStyle: AppTypography.cairo(
                          fontSize: 11.5,
                          color: AppColors.slate400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 17,
                          color: AppColors.slate400,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'الكل (${banners.length})'),
                          const SizedBox(width: 6),
                          _buildFilterChip('active', 'المفعّلة ($activeCount)'),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'inactive',
                            'المعطّلة ($inactiveCount)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإعلانات (${filtered.length})',
                        style: AppTypography.cairo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        'مرتبة حسب الأولوية',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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
                  else if (filtered.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Center(
                        child: Text(
                          'لا توجد إعلانات مطابقة للبحث أو الفلتر الحالي',
                          style: AppTypography.cairo(
                            fontSize: 13,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((banner) => _buildBannerAdminCard(banner)),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.14),
      labelStyle: AppTypography.cairo(
        fontSize: 10.5,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? AppColors.primaryBlue : AppColors.slate600,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryBlue : AppColors.outline,
      ),
      onSelected: (_) => setState(() => _statusFilter = key),
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
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTypography.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.cairo(fontSize: 9.5, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildBannerAdminCard(BannerModel banner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: banner.isActive
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : AppColors.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aspect-ratio Cropped Card (Compact)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: SizedBox(
              height: 108,
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
                    top: 7,
                    right: 8,
                    left: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: banner.isActive
                                ? AppColors.emerald.withValues(alpha: 0.9)
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                banner.isActive
                                    ? Icons.check_circle
                                    : Icons.pause_circle_outline,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                banner.isActive ? 'نشط' : 'معطّل',
                                style: AppTypography.cairo(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  banner.actionValue != null &&
                                          banner.actionValue!.trim().isNotEmpty
                                      ? Icons.link
                                      : Icons.block,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    banner.actionValue != null &&
                                            banner.actionValue!
                                                .trim()
                                                .isNotEmpty
                                        ? banner.actionValue!.trim()
                                        : 'بدون رابط',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.cairo(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom content (Title & Description)
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (banner.description.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            banner.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 10,
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

          // Action Toolbar Row (Compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                // Sort Order Stepper
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(7),
                        ),
                        onTap: banner.sortOrder > 0
                            ? () => _adjustSortOrder(banner, -1)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 13,
                            color: banner.sortOrder > 0
                                ? AppColors.slate700
                                : AppColors.slate300,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '#${banner.sortOrder}',
                          style: AppTypography.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate700,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(7),
                        ),
                        onTap: () => _adjustSortOrder(banner, 1),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 13,
                            color: AppColors.slate700,
                          ),
                        ),
                      ),
                    ],
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
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: banner.isActive
                            ? AppColors.emerald
                            : AppColors.slate600,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.76,
                      child: Switch(
                        value: banner.isActive,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    ),
                  ],
                ),
                const SizedBox(width: 2),

                // Edit button
                IconButton(
                  tooltip: 'تعديل',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.slate50,
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: AppColors.primaryBlue,
                  ),
                  onPressed: () => _showAddOrEditBannerDialog(banner: banner),
                ),
                const SizedBox(width: 4),

                // Delete button
                IconButton(
                  tooltip: 'حذف',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.roseWash,
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 15,
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
