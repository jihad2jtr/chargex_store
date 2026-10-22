import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/margin_provider.dart';
import '../../widgets/balance_badge.dart';
import '../../widgets/digital_pass_card.dart';

class AppProductsScreen extends StatefulWidget {
  final AppItemModel app;

  const AppProductsScreen({super.key, required this.app});

  @override
  State<AppProductsScreen> createState() => _AppProductsScreenState();
}

class _AppProductsScreenState extends State<AppProductsScreen> {
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
    final Map<String, TextEditingController> controllers = {};

    for (final field in product.requiredFields) {
      controllers[field] = TextEditingController();
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
                      product.requiredFields.isNotEmpty) ...[
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

                      return ElevatedButton(
                        onPressed: (!hasEnough || catalog.isOrdering)
                            ? null
                            : () async {
                                final Map<String, dynamic> accountInput = {};
                                for (final entry in controllers.entries) {
                                  final val = entry.value.text.trim();
                                  if (val.isEmpty && product.type != 'codes') {
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
                                hasEnough
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
      body: catalog.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : catalog.currentProducts.isEmpty
          ? _buildEmptyState()
          : _buildProductsList(context, catalog.currentProducts),
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

  Widget _buildProductsList(BuildContext context, List<ProductModel> products) {
    final marginProvider = Provider.of<MarginProvider>(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final double customerPrice = marginProvider.calculateCustomerPrice(
          product.salePrice,
        );
        final bool hasMargin =
            marginProvider.isEnabled && marginProvider.marginPercent > 0;
        final String? marginText = hasMargin
            ? '+${marginProvider.marginPercent.toStringAsFixed(0)}% للزبون'
            : null;

        final passItem = DigitalPassItem.fromProduct(
          product,
          widget.app,
          customerPrice: customerPrice,
        );

        return HorizontalDigitalPassCardWidget(
          item: passItem,
          product: product,
          displayPrice: customerPrice,
          marginText: marginText,
          onTapCharge: () => _openPurchaseDialog(product),
        );
      },
    );
  }
}
