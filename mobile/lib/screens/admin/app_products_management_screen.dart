import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/product_kinds.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/product_model.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_thumb.dart';
import '../../widgets/ops_ticket_card.dart';
import '../../widgets/status_pill.dart';

class AppProductsManagementScreen extends StatefulWidget {
  final AppItemModel app;

  const AppProductsManagementScreen({super.key, required this.app});

  @override
  State<AppProductsManagementScreen> createState() =>
      _AppProductsManagementScreenState();
}

class _AppProductsManagementScreenState
    extends State<AppProductsManagementScreen> {
  String _productTypeFilter =
      'all'; // 'all' | 'direct_api' | 'codes' | 'manual'
  String _productKindFilter = 'all'; // 'all' | 'quantity' | 'package' | مخصص
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'
  String _sortKey =
      'kind'; // kind | name | price_asc | price_desc | margin_desc
  final TextEditingController _searchCtrl = TextEditingController();

  /// لون هوية باقات الأكواد/البطاقات في اللوحة
  static const Color _violet = Color(0xFF8B5CF6);

  /// خيارات ترتيب الباقات في شريط الأدوات
  static const List<({String key, String label, IconData icon})> _sortOptions =
      [
        (key: 'kind', label: 'حسب الفئة', icon: Icons.category_rounded),
        (key: 'name', label: 'الاسم أ - ي', icon: Icons.sort_by_alpha_rounded),
        (key: 'price_asc', label: 'الأرخص', icon: Icons.trending_down_rounded),
        (key: 'price_desc', label: 'الأغلى', icon: Icons.trending_up_rounded),
        (
          key: 'margin_desc',
          label: 'الأعلى ربحاً',
          icon: Icons.percent_rounded,
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      admin.fetchAppProducts(widget.app.id);
      admin.fetchProviders();
      admin.fetchAllUsers(silent: true);
      admin.fetchServiceTemplates();
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
    final costCtrl = TextEditingController(
      text: (product?.costPrice ?? 1.0).toString(),
    );
    String productType = product?.type ?? 'direct_api';
    final codeCtrl = TextEditingController(
      text: product?.providerProductCode ?? '',
    );
    final quantityLabelCtrl = TextEditingController(
      text: product?.quantityLabel ?? '',
    );
    String? selectedTemplateId = product?.serviceTemplateId;
    bool isActive = product?.isActive ?? true;

    // الفئة التفصيلية: «باقات» أو «عملات» أو فئة مخصصة أضافتها الإدارة
    // (منتج جديد يرث فئة التطبيق، ومنتج قائم يُقرأ من بياناته)
    String selectedKind = product != null
        ? normalizeProductKind(product.kind)
        : productKindFromText(widget.app.category);
    final List<String> availableKinds = <String>[];
    for (final kind in <String>[
      ...kBuiltinProductKinds.map((k) => k.key),
      ...admin.currentAppProducts.map((p) => normalizeProductKind(p.kind)),
      selectedKind,
    ]) {
      if (!availableKinds.contains(kind)) availableKinds.add(kind);
    }
    availableKinds.sort(
      (a, b) => productKindSortIndex(a).compareTo(productKindSortIndex(b)),
    );

    // Manual Human Service Fields
    String? assignedSupervisorId = product?.assignedSupervisorId;
    final estimatedMinutesCtrl = TextEditingController(
      text: (product?.estimatedMinutes ?? 30).toString(),
    );
    bool isSensitive = product?.isSensitive ?? false;
    final instructionsCtrl = TextEditingController(
      text: product?.instructions ?? '',
    );

    double previewSalePrice = product?.salePrice ?? 1.10;

    // هامش الربح يُقرأ من المزود المرتبط (وليس من المنتج)
    ProviderModel? providerOf(String? providerId) {
      if (providerId == null) return null;
      for (final p in admin.providers) {
        if (p.id == providerId) return p;
      }
      return null;
    }

    void updatePreviewPrice(StateSetter setDialogState) {
      final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
      final p = providerOf(selectedProviderId);
      final marginValue = p?.profitMarginValue ?? 0.0;
      final marginType = p?.profitMarginType ?? 'percentage';
      setDialogState(() {
        previewSalePrice = marginType == 'fixed'
            ? cost + marginValue
            : cost * (1 + marginValue / 100);
      });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // إضافة فئة تفصيلية جديدة — تُحفظ كنص حر على المنتج وتظهر لاحقاً
            // كخيار إضافي لكل منتجات هذا التطبيق
            Future<void> addNewKind() async {
              final kindCtrl = TextEditingController();
              final created = await showDialog<String>(
                context: dialogCtx,
                builder: (kindCtx) => AlertDialog(
                  backgroundColor: AppColors.surfaceContainer,
                  title: const Text('فئة تفصيلية جديدة'),
                  content: TextField(
                    controller: kindCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفئة',
                      hintText: 'مثال: حساب جاهز',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(kindCtx).pop(),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final value = kindCtrl.text.trim();
                        if (value.isEmpty) return;
                        Navigator.of(kindCtx).pop(value);
                      },
                      child: const Text('إضافة'),
                    ),
                  ],
                ),
              );
              if (created == null || created.trim().isEmpty) return;
              final value = created.trim();
              setDialogState(() {
                if (!availableKinds.contains(value)) availableKinds.add(value);
                selectedKind = value;
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    product == null ? Icons.add_box_outlined : Icons.edit,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    product == null
                        ? 'إضافة باقة لـ "${widget.app.name}"'
                        : 'تعديل الباقة',
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Target App Notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          AppThumb(app: widget.app, size: 24, radius: 6),
                          const SizedBox(width: 8),
                          Text(
                            'التطبيق: ${widget.app.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
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
                        DropdownMenuItem(
                          value: 'direct_api',
                          child: Text('شحن مباشر من المزود (API)'),
                        ),
                        DropdownMenuItem(
                          value: 'codes',
                          child: Text('أكواد مخزنة مسبقاً (بطاقات رقمية)'),
                        ),
                        DropdownMenuItem(
                          value: 'manual',
                          child: Text('شحن يدوي من الإدارة (معرف اللاعب)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => productType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // الفئة التفصيلية: قائمة منسدلة (باقات / عملات + فئات مخصصة)
                    DropdownButtonFormField<String>(
                      // مفتاح مرتبط بالقيمة حتى تتحدّث القائمة عند إضافة فئة جديدة
                      key: ValueKey('kind_$selectedKind'),
                      initialValue: availableKinds.contains(selectedKind)
                          ? selectedKind
                          : availableKinds.first,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الفئة التفصيلية داخل ${widget.app.name}',
                        prefixIcon: const Icon(Icons.category_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'إضافة فئة جديدة',
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.amber,
                          onPressed: addNewKind,
                        ),
                      ),
                      items: [
                        for (final kind in availableKinds)
                          DropdownMenuItem<String>(
                            value: kind,
                            child: Row(
                              children: [
                                Icon(
                                  productKindIcon(kind),
                                  size: 16,
                                  color: AppColors.slate600,
                                ),
                                const SizedBox(width: 8),
                                Text(productKindLabel(kind)),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedKind = val);
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // توضيح معنى الفئة المختارة (عملات = شدات/كوينز، باقات = بكج)
                      productKindHint(selectedKind),
                      style: AppTypography.cairo(
                        fontSize: 11,
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // حجم الكمية (وصفي، مثال: 60 UC)
                    TextField(
                      controller: quantityLabelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'حجم الكمية (مثال: 60 UC)',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // نوع قالب الخدمة (حقول الإدخال)
                    DropdownButtonFormField<String?>(
                      initialValue: selectedTemplateId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'نوع قالب الخدمة (حقول الإدخال)',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('بدون قالب (معرف اللاعب افتراضياً)'),
                        ),
                        ...admin.serviceTemplates.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} • ${t.fields.length} حقول',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedTemplateId = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Provider (Optional or for direct_api)
                    // مزودو الأرقام الوهمية خارج القائمة: لا يخدمون منتجات ولا كتالوج
                    if (admin.providers.any((p) => !p.isVirtualNumber)) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: selectedProviderId,
                        decoration: const InputDecoration(
                          labelText: 'المزود المربوط (اختياري)',
                          prefixIcon: Icon(Icons.hub_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('بدون مزود'),
                          ),
                          ...admin.providers
                              .where((p) => !p.isVirtualNumber)
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                              ),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedProviderId = val);
                          updatePreviewPrice(setDialogState);
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
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.engineering_rounded,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'إعدادات الخدمة اليدوية (تنفيذ بشري)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
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
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'بدون مشرف محدد (يعينه الأدمن لاحقاً)',
                                  ),
                                ),
                                ...admin.allUsers.map(
                                  (s) => DropdownMenuItem(
                                    value: s['_id']?.toString(),
                                    child: Text('${s['name']} (${s['email']})'),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setDialogState(
                                  () => assignedSupervisorId = val,
                                );
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
                                labelText:
                                    'تعليمات للعميل أو متطلبات الخدمة (اختياري)',
                                prefixIcon: Icon(Icons.info_outline_rounded),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Sensitive Switch
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'خدمة حساسة مشفرة (AES-256)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text(
                                'مثل إنشاء حسابات جيميل أو بيانات سرية يتم تشفيرها وحذفها بعد الاستلام',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              value: isSensitive,
                              activeThumbColor: AppColors.secondary,
                              onChanged: (val) =>
                                  setDialogState(() => isSensitive = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Cost Price
                    TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر التكلفة (\$ USD)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => updatePreviewPrice(setDialogState),
                    ),
                    const SizedBox(height: 12),

                    // هامش الربح يُقرأ من المزود المرتبط (وليس من المنتج)
                    Builder(
                      builder: (context) {
                        final p = providerOf(selectedProviderId);
                        final hasProvider = p != null;
                        final marginText = !hasProvider
                            ? 'بدون مزود — لا يُطبَّق هامش ربح'
                            : (p.profitMarginType == 'fixed'
                                  ? '\$${p.profitMarginValue.toStringAsFixed(2)}'
                                  : '${p.profitMarginValue.toStringAsFixed(1)}%');
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.07,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasProvider
                                      ? 'هامش الربح مُحدَّد من إعدادات المزود "${p.name}": $marginText\nلتغييره عدّل نسبة الربح في إعدادات المزود.'
                                      : 'هامش الربح يُضبط من إعدادات المزود. اختر مزوداً لتطبيق هامشه على هذا المنتج.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryBlue,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                          const Text(
                            'السعر النهائي للبيع:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? AppColors.tertiary.withValues(alpha: 0.5)
                              : AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 18,
                                color: isActive
                                    ? AppColors.tertiaryLight
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isActive
                                    ? 'الباقة نشطة (ظاهرة للعملاء)'
                                    : 'الباقة معطلة (مخفية)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? AppColors.tertiaryLight
                                      : AppColors.error,
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

                    // بيانات الخادم (للقراءة فقط) — تظهر عند التعديل فقط
                    if (product != null) ...[
                      const SizedBox(height: 16),
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.dns_rounded,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'بيانات الخادم (للقراءة فقط)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _serverInfoRow('معرّف المنتج', product.id),
                            _serverInfoRow(
                              'المزود المربوط',
                              providerOf(product.providerId)?.name ??
                                  (product.providerId ?? '—'),
                            ),
                            _serverInfoRow(
                              'كود المنتج لدى المزود',
                              (product.providerProductCode ?? '').isEmpty
                                  ? '—'
                                  : product.providerProductCode!,
                            ),
                            _serverInfoRow(
                              'سعر التكلفة الحالي',
                              '\$${product.costPrice.toStringAsFixed(2)}',
                            ),
                            _serverInfoRow(
                              'هامش الربح المطبّق',
                              product.profitMarginType == 'fixed'
                                  ? '\$${product.profitMarginValue.toStringAsFixed(2)}'
                                  : '${product.profitMarginValue.toStringAsFixed(1)}%',
                            ),
                            _serverInfoRow(
                              'السعر النهائي للبيع',
                              '\$${product.salePrice.toStringAsFixed(2)}',
                            ),
                            if (product.hasPriceChanged &&
                                product.previousPrice != null)
                              _serverInfoRow(
                                'السعر السابق',
                                '\$${product.previousPrice!.toStringAsFixed(2)}',
                              ),
                            _serverInfoRow(
                              'عدد الأكواد المتاحة',
                              '${product.availableCodesCount}',
                            ),
                            _serverInfoRow(
                              'الحقول المطلوبة',
                              product.requiredFields.isEmpty
                                  ? '—'
                                  : product.requiredFields.join('، '),
                            ),
                            if (product.sensitiveFields.isNotEmpty)
                              _serverInfoRow(
                                'الحقول الحساسة',
                                product.sensitiveFields.join('، '),
                              ),
                            if (product.type == 'manual' &&
                                (product.assignedSupervisorName ?? '')
                                    .isNotEmpty)
                              _serverInfoRow(
                                'المشرف الحالي',
                                product.assignedSupervisorName!,
                              ),
                            _serverInfoRow(
                              'حالة المزود',
                              product.providerAvailable ? 'متصل' : 'غير متاح',
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    backgroundColor: AppColors.primaryContainer,
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                    final selectedProvider = providerOf(selectedProviderId);

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
                      'providerProductCode': codeCtrl.text.trim().isNotEmpty
                          ? codeCtrl.text.trim()
                          : null,
                      'costPrice': cost,
                      'profitMarginType':
                          selectedProvider?.profitMarginType ?? 'percentage',
                      'profitMarginValue':
                          selectedProvider?.profitMarginValue ?? 0.0,
                      'isActive': isActive,
                      'quantityLabel': quantityLabelCtrl.text.trim(),
                      'kind': selectedKind,
                      'serviceTemplateId': selectedTemplateId,
                      if (productType == 'manual') ...{
                        'assignedSupervisorId': assignedSupervisorId,
                        'estimatedMinutes':
                            int.tryParse(estimatedMinutesCtrl.text.trim()) ??
                            30,
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
                          content: Text(
                            ok
                                ? 'تم حفظ الباقة بنجاح'
                                : (admin.errorMessage ?? 'حدث خطأ'),
                          ),
                          backgroundColor: ok
                              ? AppColors.tertiary
                              : AppColors.error,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('إضافة أكواد لمخزون: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أدخل الأكواد الرقمية (كود في كل سطر):',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
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
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiary,
              ),
              onPressed: () async {
                final text = codesCtrl.text.trim();
                final codes = text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (codes.isEmpty) return;

                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                final ok = await admin.addCodesToInventory(product.id, codes);
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'تمت إضافة ${codes.length} كود للمخزون بنجاح'
                            : 'فشلت الإضافة',
                      ),
                      backgroundColor: ok
                          ? AppColors.tertiary
                          : AppColors.error,
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final ok = await admin.deleteProduct(product.id);
              if (ctx.mounted) Navigator.of(ctx).pop();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'تم حذف الباقة بنجاح' : 'فشل حذف الباقة',
                    ),
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

  // --- Server (read-only) info row used in the edit dialog ---
  Widget _serverInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        SnackBar(
          content: Text(admin.errorMessage ?? 'فشل تحديث الأسعار'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    final String search = _searchCtrl.text.trim().toLowerCase();
    final List<ProductModel> sourceProducts =
        admin.currentAppProducts.isNotEmpty
        ? admin.currentAppProducts
        : admin.adminProducts.where((p) => p.appId == widget.app.id).toList();

    // النطاق بعد فلتر الحالة والبحث فقط: منه تُحسب كل عدّادات الفلاتر
    final List<ProductModel> scope = sourceProducts.where((p) {
      if (_statusFilter == 'active' && !p.isActive) return false;
      if (_statusFilter == 'inactive' && p.isActive) return false;
      if (search.isNotEmpty) {
        final bool hit =
            p.name.toLowerCase().contains(search) ||
            (p.providerProductCode ?? '').toLowerCase().contains(search) ||
            productKindLabel(p.kind).contains(_searchCtrl.text.trim());
        if (!hit) return false;
      }
      return true;
    }).toList();

    final List<ProductModel> products = _sortedProducts(
      scope.where((p) {
        if (_productTypeFilter != 'all' && p.type != _productTypeFilter) {
          return false;
        }
        if (_productKindFilter != 'all' &&
            normalizeProductKind(p.kind) != _productKindFilter) {
          return false;
        }
        return true;
      }).toList(),
    );

    final bool anyFilter =
        _productTypeFilter != 'all' ||
        _productKindFilter != 'all' ||
        _statusFilter != 'all' ||
        search.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(admin, sourceProducts),
            _buildFilterPanel(
              scope: scope,
              shown: products.length,
              total: sourceProducts.length,
              anyFilter: anyFilter,
            ),
            Expanded(child: _buildListBody(admin, products, anyFilter)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- الهيدر

  /// هيدر اللوحة: هوية التطبيق + تحديث/إضافة + أربع بلاطات عدّادات قابلة للضغط
  /// (كل بلاطة تشغّل فلترًا مباشرة بدل أن تكون رقمًا ساكنًا).
  Widget _buildHeader(AdminProvider admin, List<ProductModel> all) {
    final int active = all.where((p) => p.isActive).length;
    final int stock = all
        .where((p) => p.type == 'codes')
        .fold(0, (int sum, ProductModel p) => sum + p.availableCodesCount);
    final bool canPop = Navigator.of(context).canPop();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkNav, AppColors.slate800],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNav.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                _headerIconButton(
                  Icons.arrow_forward_rounded,
                  'رجوع',
                  () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
              ],
              AppThumb(app: widget.app, size: 34, radius: 10),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'باقات ${widget.app.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.app.category?.isNotEmpty == true ? widget.app.category : 'عام'} · ${all.length} باقة · ${all.length - active} معطّلة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              _headerIconButton(
                Icons.sync_rounded,
                'تحديث الأسعار من المزودين',
                admin.isLoading ? null : _syncProviderPrices,
              ),
              const SizedBox(width: 6),
              _headerIconButton(
                Icons.add_rounded,
                'إضافة باقة جديدة',
                () => _openAddEditProductDialog(),
              ),
              const SizedBox(width: 2),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  value: '${all.length}',
                  label: 'كل الباقات',
                  icon: Icons.layers_rounded,
                  color: Colors.white,
                  selected:
                      _statusFilter == 'all' && _productTypeFilter == 'all',
                  onTap: _clearFilters,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricTile(
                  value: '$active',
                  label: 'ظاهرة للعملاء',
                  icon: Icons.visibility_rounded,
                  color: AppColors.accentGreen,
                  selected: _statusFilter == 'active',
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == 'active'
                        ? 'all'
                        : 'active',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricTile(
                  value: '${all.length - active}',
                  label: 'معطّلة',
                  icon: Icons.block_rounded,
                  color: AppColors.rose,
                  selected: _statusFilter == 'inactive',
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == 'inactive'
                        ? 'all'
                        : 'inactive',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricTile(
                  value: '$stock',
                  label: 'كود متوفر',
                  icon: Icons.confirmation_number_rounded,
                  color: _violet,
                  selected: _productTypeFilter == 'codes',
                  onTap: () => setState(
                    () => _productTypeFilter = _productTypeFilter == 'codes'
                        ? 'all'
                        : 'codes',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: onTap == null ? 0.05 : 0.10),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 17,
              color: onTap == null
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricTile({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.16 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 11, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- لوحة الفلاتر

  /// بحث + ترتيب + نوع + فئة + شريط نتائج داخل لوحة واحدة متماسكة.
  Widget _buildFilterPanel({
    required List<ProductModel> scope,
    required int shown,
    required int total,
    required bool anyFilter,
  }) {
    final List<String> presentKinds =
        <String>{
          ...scope
              .where(
                (p) =>
                    _productTypeFilter == 'all' || p.type == _productTypeFilter,
              )
              .map((p) => normalizeProductKind(p.kind)),
        }.toList()..sort(
          (a, b) => productKindSortIndex(a).compareTo(productKindSortIndex(b)),
        );

    int typeCount(String key) =>
        key == 'all' ? scope.length : scope.where((p) => p.type == key).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
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
      child: Column(
        children: [
          _buildSearchRow(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _typeSegment(
                    'all',
                    'الكل',
                    Icons.layers_rounded,
                    typeCount('all'),
                  ),
                ),
                Expanded(
                  child: _typeSegment(
                    'direct_api',
                    'مباشر',
                    Icons.bolt_rounded,
                    typeCount('direct_api'),
                  ),
                ),
                Expanded(
                  child: _typeSegment(
                    'codes',
                    'أكواد',
                    Icons.confirmation_number_rounded,
                    typeCount('codes'),
                  ),
                ),
                Expanded(
                  child: _typeSegment(
                    'manual',
                    'يدوي',
                    Icons.handyman_rounded,
                    typeCount('manual'),
                  ),
                ),
              ],
            ),
          ),
          if (presentKinds.length > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _kindChip('all', 'كل الفئات', Icons.apps_rounded, null),
                  for (final kind in presentKinds) ...[
                    const SizedBox(width: 6),
                    _kindChip(
                      kind,
                      productKindLabel(kind),
                      productKindIcon(kind),
                      scope
                          .where((p) => normalizeProductKind(p.kind) == kind)
                          .length,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 7),
          _buildResultsBar(shown: shown, total: total, anyFilter: anyFilter),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 10, end: 2),
            child: Icon(
              Icons.search_rounded,
              size: 17,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: AppTypography.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'ابحث باسم الباقة أو كود المزود...',
                hintStyle: AppTypography.cairo(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            _iconToolButton(Icons.close_rounded, 'مسح البحث', () {
              _searchCtrl.clear();
              setState(() {});
            }),
          _buildSortButton(),
          const SizedBox(width: 3),
        ],
      ),
    );
  }

  Widget _iconToolButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 15, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      tooltip: 'ترتيب الباقات',
      color: Colors.white,
      initialValue: _sortKey,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.sort_rounded,
        size: 17,
        color: _sortKey == 'kind'
            ? AppColors.textSecondary
            : AppColors.primaryBlue,
      ),
      onSelected: (key) => setState(() => _sortKey = key),
      itemBuilder: (context) => [
        for (final option in _sortOptions)
          PopupMenuItem<String>(
            value: option.key,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 15,
                  color: option.key == _sortKey
                      ? AppColors.primaryBlue
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: option.key == _sortKey
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: option.key == _sortKey
                        ? AppColors.primaryBlue
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _typeSegment(String key, String label, IconData icon, int count) {
    final bool selected = _productTypeFilter == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _productTypeFilter = key;
          _productKindFilter = 'all';
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.darkNav : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppTypography.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChip(String key, String label, IconData icon, int? count) {
    final bool selected = _productKindFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _productKindFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.amberContainer : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.amber : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected ? AppColors.secondaryBright : AppColors.slate500,
            ),
            const SizedBox(width: 5),
            Text(
              count == null ? label : '$label ($count)',
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected
                    ? AppColors.secondaryBright
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBar({
    required int shown,
    required int total,
    required bool anyFilter,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            anyFilter
                ? 'عرض $shown من $total باقة مطابقة'
                : 'إجمالي $total باقة في ${widget.app.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (anyFilter) ...[
          const SizedBox(width: 8),
          _panelButton(
            label: 'مسح الفلاتر',
            icon: Icons.filter_alt_off_rounded,
            color: AppColors.slate700,
            filled: false,
            onTap: _clearFilters,
          ),
        ],
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _productTypeFilter = 'all';
      _productKindFilter = 'all';
      _statusFilter = 'all';
      _searchCtrl.clear();
    });
  }

  List<ProductModel> _sortedProducts(List<ProductModel> input) {
    final List<ProductModel> out = List<ProductModel>.of(input);
    switch (_sortKey) {
      case 'name':
        out.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'price_asc':
        out.sort((a, b) => a.salePrice.compareTo(b.salePrice));
        break;
      case 'price_desc':
        out.sort((a, b) => b.salePrice.compareTo(a.salePrice));
        break;
      case 'margin_desc':
        out.sort((a, b) => _marginOf(b).compareTo(_marginOf(a)));
        break;
      default:
        out.sort((a, b) {
          final int byKind = productKindSortIndex(
            a.kind,
          ).compareTo(productKindSortIndex(b.kind));
          return byKind != 0 ? byKind : a.name.compareTo(b.name);
        });
    }
    return out;
  }

  /// الهامش بالدولار — يُستخدم لمقارنة الترتيب فقط
  double _marginOf(ProductModel p) => p.profitMarginType == 'percentage'
      ? p.salePrice * p.profitMarginValue / 100
      : p.profitMarginValue;

  // --------------------------------------------------------------- القائمة

  Widget _buildListBody(
    AdminProvider admin,
    List<ProductModel> products,
    bool anyFilter,
  ) {
    if (admin.isLoading && products.isEmpty) return _buildLoadingList();

    return RefreshIndicator(
      onRefresh: () async {
        await admin.fetchAppProducts(widget.app.id);
        await admin.fetchProviders();
      },
      color: AppColors.primaryBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(anyFilter),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ProductModel product = products[index];
                  final ProviderModel? provider = admin.providers
                      .where((p) => p.id == product.providerId)
                      .firstOrNull;

                  return _buildProductCard(
                    product: product,
                    providerName: provider?.name,
                    onToggleActive: () => _toggleActive(admin, product),
                    onEdit: () => _openAddEditProductDialog(product),
                    onDelete: () => _confirmDeleteProduct(product),
                    onAddCodes: () => _openAddCodesDialog(product),
                  );
                }, childCount: products.length),
              ),
            ),
        ],
      ),
    );
  }

  /// هيكل تحميل مؤقت بدل الدوّار المفرد
  Widget _buildLoadingList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 0; i < 4; i++)
          Container(
            height: 92,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(bool anyFilter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline),
              ),
              child: Icon(
                anyFilter
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 27,
                color: AppColors.slate400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              anyFilter
                  ? 'لا باقة تطابق هذا التحديد'
                  : 'لا باقات في ${widget.app.name} بعد',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              anyFilter
                  ? 'غيّر النوع أو الفئة أو امسح الفلاتر للوصول إلى بقية الباقات.'
                  : 'أضف أول باقة لتظهر للعملاء في واجهة الشراء بالسعر الذي تحدده.',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            _panelButton(
              label: anyFilter ? 'مسح الفلاتر' : 'إضافة أول باقة',
              icon: anyFilter
                  ? Icons.filter_alt_off_rounded
                  : Icons.add_rounded,
              color: anyFilter ? AppColors.slate700 : AppColors.primaryBlue,
              filled: !anyFilter,
              onTap: anyFilter
                  ? _clearFilters
                  : () => _openAddEditProductDialog(),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- البطاقة

  /// باقة واحدة بتذكرة موحّدة: هوية النوع + السعر + الحالة + صفوف التسعير
  /// + تنبيه أحمر عند تعطّل المخزون أو المزود + أزرار الإجراءات.
  Widget _buildProductCard({
    required ProductModel product,
    String? providerName,
    required VoidCallback onToggleActive,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onAddCodes,
  }) {
    final bool isCodes = product.type == 'codes';
    final bool isManual = product.type == 'manual';
    final Color accent = isCodes
        ? _violet
        : isManual
        ? AppColors.ticketAmber
        : AppColors.primaryBlue;
    final IconData icon = isCodes
        ? Icons.confirmation_number_rounded
        : isManual
        ? Icons.handyman_rounded
        : Icons.bolt_rounded;
    final String typeLabel = isCodes
        ? 'بطاقات وأكواد'
        : isManual
        ? 'شحن يدوي'
        : 'شحن API مباشر';

    final String subtitle = <String>[
      productKindLabel(product.kind),
      if (product.quantityLabel.trim().isNotEmpty) product.quantityLabel.trim(),
      if (providerName != null) 'المزود: $providerName',
    ].join(' · ');

    // أهم تنبيه تشغيلي فقط حتى لا تتضخم البطاقة
    final String? warning = !product.providerAvailable && !isCodes && !isManual
        ? 'المزود متوقف — الشحن المباشر لن يعمل لهذه الباقة'
        : isCodes && product.availableCodesCount == 0
        ? 'نفد مخزون الأكواد — أضف أكوادًا قبل طلب العملاء'
        : null;

    final String code = (product.providerProductCode ?? '').trim();

    return OpsTicketCard(
      accent: accent,
      icon: icon,
      tag: typeLabel,
      title: product.name,
      subtitle: subtitle,
      amount: Text(
        '\$${product.salePrice.toStringAsFixed(2)}',
        style: AppTypography.price(
          fontSize: 15,
          color: AppColors.secondaryBright,
        ),
      ),
      status: StatusPill(
        status: product.isActive ? 'active' : 'inactive',
        label: product.isActive ? 'نشط' : 'معطّل',
      ),
      rows: [
        OpsTicketInfoRow(
          icon: Icons.payments_rounded,
          label: 'التكلفة',
          value: '\$${product.costPrice.toStringAsFixed(2)}',
          mono: true,
          tint: AppColors.slate600,
        ),
        OpsTicketInfoRow(
          icon: Icons.percent_rounded,
          label: 'الهامش',
          value: product.profitMarginType == 'percentage'
              ? '+${product.profitMarginValue.toStringAsFixed(0)}%'
              : '+\$${product.profitMarginValue.toStringAsFixed(2)}',
          tint: AppColors.accentGreen,
        ),
        if (isCodes)
          OpsTicketInfoRow(
            icon: Icons.inventory_2_rounded,
            label: 'المخزون',
            value: '${product.availableCodesCount} كود متوفر',
            tint: product.availableCodesCount == 0 ? AppColors.rose : _violet,
          ),
        if (isManual)
          OpsTicketInfoRow(
            icon: Icons.timer_outlined,
            label: 'التنفيذ',
            value:
                '${product.estimatedMinutes} دقيقة${(product.assignedSupervisorName ?? '').isNotEmpty ? ' · ${product.assignedSupervisorName}' : ''}',
            tint: AppColors.slate600,
          ),
        if (product.hasPriceChanged && product.previousPrice != null)
          OpsTicketInfoRow(
            icon: Icons.history_rounded,
            label: 'السعر السابق',
            value: '\$${product.previousPrice!.toStringAsFixed(2)}',
            mono: true,
            tint: AppColors.slate400,
          ),
        if (product.requiredFields.isNotEmpty)
          OpsTicketInfoRow(
            icon: Icons.input_rounded,
            label: 'حقول الطلب',
            value: product.requiredFields.join('، '),
          ),
      ],
      note: warning,
      meta: code.isNotEmpty ? 'CODE: $code' : null,
      actions: [
        _panelButton(
          label: product.isActive ? 'تعطيل' : 'تفعيل',
          icon: product.isActive
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_fill_rounded,
          color: product.isActive ? AppColors.rose : AppColors.accentGreen,
          filled: false,
          onTap: onToggleActive,
        ),
        const SizedBox(width: 6),
        if (isCodes) ...[
          _cardIconAction(
            Icons.add_rounded,
            'إضافة أكواد',
            _violet,
            onAddCodes,
          ),
          const SizedBox(width: 6),
        ],
        _cardIconAction(
          Icons.edit_outlined,
          'تعديل الباقة',
          AppColors.primaryBlue,
          onEdit,
        ),
        const SizedBox(width: 6),
        _cardIconAction(
          Icons.delete_outline_rounded,
          'حذف الباقة',
          AppColors.rose,
          onDelete,
        ),
      ],
    );
  }

  Widget _panelButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool filled = true,
  }) {
    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardIconAction(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }

  /// تبديل حالة الباقة (نشط/معطّل) مع رسالة قصيرة
  Future<void> _toggleActive(AdminProvider admin, ProductModel product) async {
    final bool wasActive = product.isActive;
    final bool ok = await admin.toggleProductActive(product.id, widget.app.id);
    if (!mounted) return;

    _toast(
      ok
          ? (wasActive
                ? 'تم تعطيل «${product.name}» وإخفاؤه عن العملاء'
                : 'تم تفعيل «${product.name}» وإظهاره للعملاء')
          : (admin.errorMessage ?? 'فشل تعديل حالة الباقة'),
      ok,
    );
  }

  void _toast(String message, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.tertiary : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
