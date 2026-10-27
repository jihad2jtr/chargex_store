import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/product_kinds.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/product_model.dart';
import '../../models/service_template_model.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exchange_rate_provider.dart';
import '../../providers/margin_provider.dart';
import '../../widgets/balance_badge.dart';
import '../../widgets/product_list_card.dart';

class AppProductsScreen extends StatefulWidget {
  final AppItemModel app;

  const AppProductsScreen({super.key, required this.app});

  @override
  State<AppProductsScreen> createState() => _AppProductsScreenState();
}

class _AppProductsScreenState extends State<AppProductsScreen> {
  /// فلتر الفئة التفصيلية: 'all' أو مفتاح فئة (quantity / package / مخصصة)
  String _kindFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppCatalogProvider>(
        context,
        listen: false,
      ).fetchProductsByApp(widget.app.id);
    });
  }

  @override
  void didUpdateWidget(covariant AppProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app.id != widget.app.id) {
      _kindFilter = 'all';
    }
  }

  void _openPurchaseDialog(ProductModel product) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final marginProvider = Provider.of<MarginProvider>(context, listen: false);
    final userBalance = auth.currentUser?.balance ?? 0.0;
    final bool hasMargin =
        marginProvider.isEnabled && marginProvider.marginPercent > 0;
    final double customerPrice = marginProvider.calculateCustomerPrice(
      product.salePrice,
    );
    final double profitAmount = marginProvider.calculateProfit(
      product.salePrice,
    );
    final templateFields =
        product.serviceTemplate?.fields ?? const <ServiceFieldDef>[];
    final Map<String, TextEditingController> controllers = {};
    final Map<String, int> quantityValues = {};

    if (templateFields.isNotEmpty) {
      for (final field in templateFields) {
        if (field.type == 'quantity') {
          quantityValues[field.label] = 1;
        } else {
          controllers[field.label] = TextEditingController();
        }
      }
    } else {
      for (final field in product.requiredFields) {
        controllers[field] = TextEditingController();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              widget.app.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: AppColors.outline),

                  // Pricing & Balance Comparison
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'سعر الشراء (من رصيدك):',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            Row(
                              children: [
                                if (product.hasPriceChanged &&
                                    product.previousPrice != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      '\$${product.previousPrice!.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppColors.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                        fontSize: 13,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                Text(
                                  '\$${product.salePrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.secondaryBright,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (hasMargin) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'سعر البيع للزبون (+${marginProvider.marginPercent.toStringAsFixed(0)}%):',
                                style: const TextStyle(
                                  color: AppColors.tertiaryLight,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '\$${customerPrice.toStringAsFixed(2)} (ربحك: +\$${profitAmount.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  color: AppColors.tertiaryLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'رصيدك الحالي:',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '\$${userBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: userBalance >= product.salePrice
                                    ? AppColors.tertiaryLight
                                    : AppColors.errorLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Required inputs (e.g. Player ID)
                  if (product.type != 'codes' &&
                      (templateFields.isNotEmpty ||
                          product.requiredFields.isNotEmpty)) ...[
                    if (templateFields.isNotEmpty)
                      for (final field in templateFields) ...[
                        if (field.type == 'quantity')
                          _buildQuantityField(
                            field,
                            quantityValues,
                            setSheetState,
                          )
                        else
                          TextField(
                            controller: controllers[field.label],
                            obscureText: field.isSensitive,
                            keyboardType: field.type == 'phone'
                                ? TextInputType.phone
                                : field.type == 'email'
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: field.label,
                              hintText: field.placeholder.isNotEmpty
                                  ? field.placeholder
                                  : 'أدخل ${field.label}',
                              prefixIcon: Icon(_fieldIcon(field.type)),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ]
                    else
                      for (final field in product.requiredFields) ...[
                        TextField(
                          controller: controllers[field],
                          decoration: InputDecoration(
                            labelText: field,
                            hintText: 'أدخل $field الخاص بك',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],

                  if (product.type == 'codes') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: AppColors.tertiaryLight,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تسليم فوري: سيظهر لك كود البطاقة مباشرة بعد إتمام الدفع',
                              style: TextStyle(
                                color: AppColors.tertiaryLight,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (product.type == 'manual') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amberContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: AppColors.amber,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'شحن يدوي: سيتم مراجعة طلبك وتنفيذه من قبل الإدارة في أقرب وقت',
                              style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Confirm Purchase Button
                  Consumer<AppCatalogProvider>(
                    builder: (context, catalog, child) {
                      final hasEnough = userBalance >= product.salePrice;
                      final unavailable = !product.providerAvailable;

                      return ElevatedButton(
                        onPressed:
                            (!hasEnough || unavailable || catalog.isOrdering)
                            ? null
                            : () async {
                                final Map<String, dynamic> accountInput = {};
                                for (final entry in controllers.entries) {
                                  final val = entry.value.text.trim();
                                  final isOptional = templateFields.any(
                                    (f) => f.label == entry.key && !f.required,
                                  );
                                  if (val.isEmpty &&
                                      product.type != 'codes' &&
                                      !isOptional) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'يرجى إدخال ${entry.key}',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  accountInput[entry.key] = val;
                                }
                                for (final entry in quantityValues.entries) {
                                  accountInput[entry.key] = entry.value;
                                }

                                final result = await catalog.purchaseProduct(
                                  productId: product.id,
                                  accountInput: accountInput,
                                );

                                if (result != null && context.mounted) {
                                  Navigator.of(context).pop(); // Close sheet
                                  auth.updateBalanceLocally(
                                    (result['newBalance'] is num)
                                        ? (result['newBalance'] as num)
                                              .toDouble()
                                        : (userBalance - product.salePrice),
                                  );

                                  _showPurchaseSuccessDialog(result);
                                } else if (context.mounted) {
                                  // A failed attempt is refunded server-side, but the
                                  // balance may have been resynced — refresh before reporting
                                  await auth.refreshProfile();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        catalog.errorMessage ??
                                            'فشل إتمام العملية',
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: hasEnough
                              ? AppColors.primaryContainer
                              : AppColors.surfaceBright,
                        ),
                        child: catalog.isOrdering
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                unavailable
                                    ? 'الخدمة غير متاحة حالياً'
                                    : hasEnough
                                    ? 'تأكيد الشراء (\$${product.salePrice.toStringAsFixed(2)})'
                                    : 'رصيد غير كافٍ (\$${product.salePrice.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _fieldIcon(String type) {
    switch (type) {
      case 'phone':
        return Icons.phone_outlined;
      case 'name':
        return Icons.person_outline;
      case 'email':
        return Icons.email_outlined;
      case 'password':
        return Icons.lock_outline;
      case 'player_id':
        return Icons.badge_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  Widget _buildQuantityField(
    ServiceFieldDef field,
    Map<String, int> values,
    void Function(void Function()) setSheetState,
  ) {
    final qty = values[field.label] ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              field.label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: qty > 1
                ? () => setSheetState(() => values[field.label] = qty - 1)
                : null,
          ),
          Text(
            '$qty',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => setSheetState(() => values[field.label] = qty + 1),
          ),
        ],
      ),
    );
  }

  void _showPurchaseSuccessDialog(Map<String, dynamic> result) {
    final deliveredCode = result['deliveredCode'] as String?;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.tertiary, size: 28),
              SizedBox(width: 10),
              Text('تمت العملية بنجاح!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(result['message'] ?? 'تم إتمام الطلب بنجاح.'),
              if (deliveredCode != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'كود الشحن الرقمي الخاص بك:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SelectableText(
                        deliveredCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryBright,
                          letterSpacing: 1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: deliveredCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ الكود للحافظة'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسناً'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = Provider.of<AppCatalogProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    // تجميع الباقات حسب الفئة التفصيلية (كمية / باقة / فئة مخصصة)
    final groups = _groupProducts(catalog.currentProducts);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.app.name,
          style: AppTypography.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: BalanceBadge(balance: auth.currentUser?.balance ?? 0.0),
          ),
        ],
      ),
      body: catalog.isLoading && catalog.currentProducts.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : groups.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (groups.length > 1) _buildKindFilterBar(groups),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primaryBlue,
                    onRefresh: () => catalog.fetchProductsByApp(
                      widget.app.id,
                      forceRefresh: true,
                    ),
                    child: _buildProductsList(context, groups),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 54,
              color: AppColors.slate600.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد باقات متاحة حالياً لهذه الخدمة',
              style: AppTypography.cairo(
                color: AppColors.slate600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LIST VIEW (كروت الباقات المستطيلة بعرض الشاشة مع تدرج اللون الأصفر للسعر)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // التجميع حسب الفئة التفصيلية (كمية / باقة / فئة مخصصة)
  // ---------------------------------------------------------------------------

  List<_ProductKindGroup> _groupProducts(List<ProductModel> products) {
    final Map<String, List<ProductModel>> grouped = {};
    for (final product in products) {
      final kind = normalizeProductKind(product.kind);
      grouped.putIfAbsent(kind, () => []).add(product);
    }
    final groups = grouped.entries
        .map((e) => _ProductKindGroup(kind: e.key, products: e.value))
        .toList();
    // الفئات المدمجة (كمية ثم باقة) أولاً ثم الفئات المخصصة
    groups.sort(
      (a, b) =>
          productKindSortIndex(a.kind).compareTo(productKindSortIndex(b.kind)),
    );
    return groups;
  }

  Widget _buildKindFilterBar(List<_ProductKindGroup> groups) {
    final total = groups.fold<int>(0, (sum, g) => sum + g.products.length);
    // صف أفقي بارتفاع طبيعي (بدون ارتفاع ثابت) لتفادي أي قص للشرائح
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Row(
        children: [
          _buildKindChip('all', 'الكل ($total)'),
          for (final group in groups) ...[
            const SizedBox(width: 8),
            _buildKindChip(
              group.kind,
              '${productKindLabel(group.kind)} (${group.products.length})',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKindChip(String key, String label) {
    final selected = _kindFilter == key;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        key == 'all' ? Icons.apps_rounded : productKindIcon(key),
        size: 15,
        color: selected ? AppColors.primary : AppColors.slate500,
      ),
      selected: selected,
      selectedColor: AppColors.primaryContainer.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? AppColors.primary : AppColors.slate600,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.outline),
      onSelected: (_) => setState(() => _kindFilter = key),
    );
  }

  Widget _buildKindSectionHeader(_ProductKindGroup group) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10, right: 2, left: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              productKindIcon(group.kind),
              size: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            productKindLabel(group.kind),
            style: AppTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${group.products.length}',
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(
    BuildContext context,
    List<_ProductKindGroup> groups,
  ) {
    final marginProvider = Provider.of<MarginProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final rates = Provider.of<ExchangeRateProvider>(context);
    final bool hasMargin =
        marginProvider.isEnabled && marginProvider.marginPercent > 0;

    final visibleGroups = _kindFilter == 'all'
        ? groups
        : groups.where((g) => g.kind == _kindFilter).toList();
    // احتياط: إذا كانت الفئة المختارة لم تعد موجودة نعرض كل الفئات
    final displayGroups = visibleGroups.isEmpty ? groups : visibleGroups;
    final showHeaders = groups.length > 1;

    final List<Widget> children = [];
    for (final group in displayGroups) {
      if (showHeaders) children.add(_buildKindSectionHeader(group));
      for (final product in group.products) {
        final double customerPrice = marginProvider.calculateCustomerPrice(
          product.salePrice,
        );
        children.add(
          ProductListCard(
            product: product,
            displayPrice: customerPrice,
            // سعر التكلفة قبل نسبة الوكيل — يظهر بجانب سعر البيع عند تفعيلها
            costPrice: hasMargin ? product.salePrice : null,
            balance: auth.currentUser?.balance,
            // المقابل التقريبي بالليرة السورية تحت السعر بالدولار
            sypPriceText: rates.sypText(customerPrice),
            marginText: hasMargin
                ? '+${marginProvider.marginPercent.toStringAsFixed(0)}% للزبون'
                : null,
            onTap: () => _openPurchaseDialog(product),
          ),
        );
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: children,
    );
  }
}

/// مجموعة باقات تنتمي لفئة تفصيلية واحدة (كمية / باقة / فئة مخصصة)
class _ProductKindGroup {
  final String kind;
  final List<ProductModel> products;

  const _ProductKindGroup({required this.kind, required this.products});
}
