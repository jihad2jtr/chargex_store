import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/card_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/product_model.dart';
import '../../providers/admin_provider.dart';

class AppProductsManagementScreen extends StatefulWidget {
  final AppItemModel app;

  const AppProductsManagementScreen({super.key, required this.app});

  @override
  State<AppProductsManagementScreen> createState() => _AppProductsManagementScreenState();
}

class _AppProductsManagementScreenState extends State<AppProductsManagementScreen> {
  String _productTypeFilter = 'all'; // 'all' | 'direct_api' | 'codes' | 'manual'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      admin.fetchAppProducts(widget.app.id);
      admin.fetchProviders();
      admin.fetchSupervisors();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- Add / Edit Product Dialog ---
  void _openAddEditProductDialog([ProductModel? product]) {
    final admin = Provider.of<AdminProvider>(context, listen: false);

    String? selectedProviderId = product?.providerId;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final costCtrl = TextEditingController(text: (product?.costPrice ?? 1.0).toString());
    final marginCtrl = TextEditingController(text: (product?.profitMarginValue ?? 10.0).toString());
    String marginType = product?.profitMarginType ?? 'percentage';
    String productType = product?.type ?? 'direct_api';
    final codeCtrl = TextEditingController(text: product?.providerProductCode ?? '');
    bool isActive = product?.isActive ?? true;

    // Manual Human Service Fields
    String? assignedSupervisorId = product?.assignedSupervisorId;
    final estimatedMinutesCtrl = TextEditingController(text: (product?.estimatedMinutes ?? 30).toString());
    bool isSensitive = product?.isSensitive ?? false;
    final instructionsCtrl = TextEditingController(text: product?.instructions ?? '');

    double previewSalePrice = product?.salePrice ?? 1.10;

    void updatePreviewPrice(StateSetter setDialogState) {
      final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
      final margin = double.tryParse(marginCtrl.text.trim()) ?? 0.0;
      setDialogState(() {
        if (marginType == 'percentage') {
          previewSalePrice = cost * (1 + margin / 100);
        } else {
          previewSalePrice = cost + margin;
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(product == null ? Icons.add_box_outlined : Icons.edit, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 8),
                  Text(product == null ? 'إضافة باقة لـ "${widget.app.name}"' : 'تعديل الباقة'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Target App Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          buildSmartAppImage(
                            widget.app.iconUrl,
                            width: 24,
                            height: 24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          const SizedBox(width: 8),
                          Text('التطبيق: ${widget.app.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الباقة (مثال: 660 UC ببجي)',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Product Type
                    DropdownButtonFormField<String>(
                      initialValue: productType,
                      decoration: const InputDecoration(
                        labelText: 'نوع العملية',
                        prefixIcon: Icon(Icons.tune),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'direct_api', child: Text('شحن مباشر من المزود (API)')),
                        DropdownMenuItem(value: 'codes', child: Text('أكواد مخزنة مسبقاً (بطاقات رقمية)')),
                        DropdownMenuItem(value: 'manual', child: Text('شحن يدوي من الإدارة (معرف اللاعب)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => productType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Provider (Optional or for direct_api)
                    if (admin.providers.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: selectedProviderId,
                        decoration: const InputDecoration(
                          labelText: 'المزود المربوط (اختياري)',
                          prefixIcon: Icon(Icons.hub_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('بدون مزود')),
                          ...admin.providers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedProviderId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (productType == 'direct_api') ...[
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'كود المنتج لدى المزود (Product Code)',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (productType == 'manual') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.engineering_rounded, size: 16, color: AppColors.secondary),
                                SizedBox(width: 6),
                                Text(
                                  'إعدادات الخدمة اليدوية (تنفيذ بشري)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Supervisor Selector
                            DropdownButtonFormField<String?>(
                              initialValue: assignedSupervisorId,
                              decoration: const InputDecoration(
                                labelText: 'المشرف المسؤول الافتراضي',
                                prefixIcon: Icon(Icons.person_pin_rounded),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('بدون مشرف محدد (يعينه الأدمن لاحقاً)')),
                                ...admin.supervisors.map((s) => DropdownMenuItem(
                                      value: s['_id']?.toString(),
                                      child: Text('${s['name']} (${s['email']})'),
                                    )),
                              ],
                              onChanged: (val) {
                                setDialogState(() => assignedSupervisorId = val);
                              },
                            ),
                            const SizedBox(height: 10),

                            // SLA / Estimated Minutes
                            TextField(
                              controller: estimatedMinutesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الوقت المتوقع للتنفيذ (بالدقائق)',
                                prefixIcon: Icon(Icons.timer_outlined),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Instructions to Customer
                            TextField(
                              controller: instructionsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تعليمات للعميل أو متطلبات الخدمة (اختياري)',
                                prefixIcon: Icon(Icons.info_outline_rounded),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Sensitive Switch
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('خدمة حساسة مشفرة (AES-256)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: const Text('مثل إنشاء حسابات جيميل أو بيانات سرية يتم تشفيرها وحذفها بعد الاستلام', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                              value: isSensitive,
                              activeThumbColor: AppColors.secondary,
                              onChanged: (val) => setDialogState(() => isSensitive = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Cost Price
                    TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'سعر التكلفة (\$ USD)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => updatePreviewPrice(setDialogState),
                    ),
                    const SizedBox(height: 12),

                    // Profit Margin Type & Value
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: marginType,
                            decoration: const InputDecoration(labelText: 'نوع الربح'),
                            items: const [
                              DropdownMenuItem(value: 'percentage', child: Text('نسبة (%)')),
                              DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (\$)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => marginType = val);
                                updatePreviewPrice(setDialogState);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: marginCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: marginType == 'percentage' ? 'نسبة الربح %' : 'قيمة الربح \$',
                            ),
                            onChanged: (_) => updatePreviewPrice(setDialogState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Calculated Sale Price
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('السعر النهائي للبيع:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '\$${previewSalePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondaryBright,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Active Switch inside Dialog
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? AppColors.tertiary.withValues(alpha: 0.5) : AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isActive ? Icons.visibility : Icons.visibility_off,
                                size: 18,
                                color: isActive ? AppColors.tertiaryLight : AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isActive ? 'الباقة نشطة (ظاهرة للعملاء)' : 'الباقة معطلة (مخفية)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? AppColors.tertiaryLight : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isActive,
                            activeThumbColor: AppColors.tertiary,
                            onChanged: (val) {
                              setDialogState(() => isActive = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                    final margin = double.tryParse(marginCtrl.text.trim()) ?? 0.0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('اسم الباقة مطلوب')),
                      );
                      return;
                    }

                    final data = {
                      'appId': widget.app.id,
                      'name': name,
                      'description': descCtrl.text.trim(),
                      'type': productType,
                      'providerId': selectedProviderId,
                      'providerProductCode': codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                      'costPrice': cost,
                      'profitMarginType': marginType,
                      'profitMarginValue': margin,
                      'isActive': isActive,
                      'requiredFields': ['Player ID'],
                      if (productType == 'manual') ...{
                        'assignedSupervisorId': assignedSupervisorId,
                        'estimatedMinutes': int.tryParse(estimatedMinutesCtrl.text.trim()) ?? 30,
                        'isSensitive': isSensitive,
                        'instructions': instructionsCtrl.text.trim(),
                      },
                    };

                    bool ok;
                    if (product == null) {
                      ok = await admin.createProduct(data);
                    } else {
                      ok = await admin.updateProduct(product.id, data);
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'تم حفظ الباقة بنجاح' : (admin.errorMessage ?? 'حدث خطأ')),
                          backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('حفظ الباقة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Add Codes to Inventory Dialog ---
  void _openAddCodesDialog(ProductModel product) {
    final codesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إضافة أكواد لمخزون: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أدخل الأكواد الرقمية (كود في كل سطر):', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: codesCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'CHG-1234-ABCD\nCHG-5678-EFGH\n...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiary),
              onPressed: () async {
                final text = codesCtrl.text.trim();
                final codes = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                if (codes.isEmpty) return;

                final admin = Provider.of<AdminProvider>(context, listen: false);
                final ok = await admin.addCodesToInventory(product.id, codes);
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تمت إضافة ${codes.length} كود للمخزون بنجاح' : 'فشلت الإضافة'),
                      backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('إضافة للمخزون'),
            ),
          ],
        );
      },
    );
  }

  // --- Confirm Delete Product ---
  void _confirmDeleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد حذف الباقة'),
        content: Text('هل أنت متأكد من حذف الباقة "${product.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final ok = await admin.deleteProduct(product.id);
              if (ctx.mounted) Navigator.of(ctx).pop();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم حذف الباقة بنجاح' : 'فشل حذف الباقة'),
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

  // --- Sync Provider Prices ---
  void _syncProviderPrices() async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final msg = await admin.syncProviderPrices();

    if (!mounted) return;

    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.tertiary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'فشل تحديث الأسعار'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    // Filter products for this app
    final search = _searchCtrl.text.trim().toLowerCase();
    final sourceProducts = admin.currentAppProducts.isNotEmpty
        ? admin.currentAppProducts
        : admin.adminProducts.where((p) => p.appId == widget.app.id).toList();

    final products = sourceProducts.where((p) {
      if (_productTypeFilter != 'all' && p.type != _productTypeFilter) return false;
      if (search.isNotEmpty && !p.name.toLowerCase().contains(search)) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            buildSmartAppImage(
              widget.app.iconUrl,
              width: 28,
              height: 28,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'باقات ${widget.app.name}',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.slate900),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث الأسعار من المزودين',
            icon: const Icon(Icons.sync, color: AppColors.primaryBlue),
            onPressed: admin.isLoading ? null : _syncProviderPrices,
          ),
          IconButton(
            tooltip: 'إضافة باقة جديدة',
            icon: const Icon(Icons.add, color: AppColors.slate900),
            onPressed: () => _openAddEditProductDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: admin.isLoading && products.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : RefreshIndicator(
              onRefresh: () async {
                await admin.fetchAdminProducts(widget.app.id);
                await admin.fetchProviders();
              },
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                slivers: [
                  // App Summary Banner (Swiss Neo-Bento Executive)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
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
                        child: Row(
                          children: [
                            buildSmartAppImage(
                              widget.app.iconUrl,
                              width: 50,
                              height: 50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.app.name,
                                    style: AppTypography.cairo(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'الفئة: ${widget.app.category?.isNotEmpty == true ? widget.app.category : 'عام'} • إجمالي الباقات: ${products.length}',
                                    style: AppTypography.cairo(fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('إضافة باقة', style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _openAddEditProductDialog(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search & Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'ابحث عن باقة في ${widget.app.name}...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('all', 'الكل (${products.length})'),
                                const SizedBox(width: 8),
                                _buildFilterChip('direct_api', 'شحن API مباشر'),
                                const SizedBox(width: 8),
                                _buildFilterChip('codes', 'أكواد وبطاقات'),
                                const SizedBox(width: 8),
                                _buildFilterChip('manual', 'شحن يدوي'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Products List
                  if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد باقات مضافة لتطبيق "${widget.app.name}" حالياً',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'أضف باقات الشحن والأسعار لتبدأ بالظهور للعملاء في واجهة الشراء',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text('إضافة أول باقة لـ ${widget.app.name}'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
                                onPressed: () => _openAddEditProductDialog(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            final provider = admin.providers.where((p) => p.id == product.providerId).firstOrNull;

                            return _buildProductCard(
                              product: product,
                              providerName: provider?.name,
                              onToggleActive: () async {
                                final wasActive = product.isActive;
                                final ok = await admin.toggleProductActive(product.id, widget.app.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? (!wasActive
                                                ? 'تم تفعيل "${product.name}" وإظهاره للعملاء ✅'
                                                : 'تم تعطيل "${product.name}" وإخفاؤه عن العملاء 🚫')
                                            : (admin.errorMessage ?? 'فشل تعديل حالة الباقة'),
                                      ),
                                      backgroundColor: ok
                                          ? (!wasActive ? AppColors.tertiary : AppColors.error)
                                          : AppColors.error,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              onEdit: () => _openAddEditProductDialog(product),
                              onDelete: () => _confirmDeleteProduct(product),
                              onAddCodes: () => _openAddCodesDialog(product),
                            );
                          },
                          childCount: products.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _productTypeFilter == key;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.outline),
      onSelected: (_) {
        setState(() {
          _productTypeFilter = key;
        });
      },
    );
  }

  Widget _buildProductCard({
    required ProductModel product,
    String? providerName,
    required VoidCallback onToggleActive,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onAddCodes,
  }) {
    Color typeColor;
    String typeLabel;
    switch (product.type) {
      case 'codes':
        typeColor = const Color(0xFF8B5CF6);
        typeLabel = 'بطاقات وأكواد';
        break;
      case 'manual':
        typeColor = AppColors.amber;
        typeLabel = 'شحن يدوي';
        break;
      default:
        typeColor = AppColors.primary;
        typeLabel = 'شحن API مباشر';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
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
          // Header: Name + Status Badge + Type Pill + Switch
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: AppTypography.arabicCardTitle(fontSize: 15, color: AppColors.slate900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.isActive
                            ? AppColors.emerald.withValues(alpha: 0.12)
                            : AppColors.rose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: product.isActive ? AppColors.emerald.withValues(alpha: 0.3) : AppColors.rose.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: product.isActive ? AppColors.emerald : AppColors.rose,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.isActive ? 'نشط' : 'معطّل',
                            style: AppTypography.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: product.isActive ? AppColors.emerald : AppColors.rose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  typeLabel,
                  style: AppTypography.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: product.isActive,
                activeThumbColor: AppColors.emerald,
                onChanged: (_) => onToggleActive(),
              ),
            ],
          ),

          // Provider & Code info if present
          if (providerName != null || product.providerProductCode != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (providerName != null) ...[
                  const Icon(Icons.hub_outlined, size: 14, color: AppColors.slate600),
                  const SizedBox(width: 4),
                  Text('المزود: $providerName', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600)),
                  const SizedBox(width: 12),
                ],
                if (product.providerProductCode != null && product.providerProductCode!.isNotEmpty) ...[
                  const Icon(Icons.qr_code, size: 14, color: AppColors.slate600),
                  const SizedBox(width: 4),
                  Text('كود المزود: ${product.providerProductCode}', style: AppTypography.spaceMono(fontSize: 11, color: AppColors.slate600)),
                ],
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Pricing Summary Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('التكلفة: \$${product.costPrice.toStringAsFixed(2)} | ', style: AppTypography.plusJakartaSans(fontSize: 11, color: AppColors.slate600)),
                    Text(
                      product.profitMarginType == 'percentage'
                          ? 'الربح: ${product.profitMarginValue}%'
                          : 'الربح: \$${product.profitMarginValue}',
                      style: AppTypography.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('سعر البيع: ', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600)),
                    Text(
                      '\$${product.salePrice.toStringAsFixed(2)}',
                      style: AppTypography.price(fontSize: 15, color: AppColors.primaryBlue),
                    ),
                    if (product.hasPriceChanged && product.previousPrice != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(\$${product.previousPrice!.toStringAsFixed(2)})',
                        style: AppTypography.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.slate600.withValues(alpha: 0.5),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Digital codes inventory section (for codes type)
          if (product.type == 'codes') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 16, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Text(
                        'المخزون المتوفر: ${product.availableCodesCount} كود',
                        style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 15),
                    label: Text('إضافة أكواد', style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: onAddCodes,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Card Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text('تعديل الباقة', style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.slate900,
                  side: const BorderSide(color: AppColors.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: onEdit,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.rose, size: 20),
                tooltip: 'حذف الباقة',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
