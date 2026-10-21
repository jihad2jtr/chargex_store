import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_pill.dart';
import 'provider_products_screen.dart';

class ProvidersManagementScreen extends StatefulWidget {
  const ProvidersManagementScreen({super.key});

  @override
  State<ProvidersManagementScreen> createState() => _ProvidersManagementScreenState();
}

class _ProvidersManagementScreenState extends State<ProvidersManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchProviders();
    });
  }

  void _openAddEditDialog([ProviderModel? provider]) {
    final nameCtrl = TextEditingController(text: provider?.name ?? '');
    final urlCtrl = TextEditingController(text: provider?.baseUrl ?? '');
    final keyCtrl = TextEditingController(text: provider?.apiKey ?? '');
    final secretCtrl = TextEditingController(text: provider?.apiSecret ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(provider == null ? 'إضافة مزود جديد' : 'تعديل المزود'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المزود (مثال: Smile One, SEAGM)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'Base URL رابط الـ API'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretCtrl,
                  decoration: const InputDecoration(labelText: 'API Secret (اختياري)'),
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
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                final key = keyCtrl.text.trim();

                if (name.isEmpty || url.isEmpty || key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول الأساسية')),
                  );
                  return;
                }

                final admin = Provider.of<AdminProvider>(context, listen: false);
                final data = {
                  'name': name,
                  'baseUrl': url,
                  'apiKey': key,
                  'apiSecret': secretCtrl.text.trim().isNotEmpty ? secretCtrl.text.trim() : null,
                };

                bool ok;
                if (provider == null) {
                  ok = await admin.createProvider(data);
                } else {
                  ok = await admin.updateProvider(provider.id, data);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم حفظ بيانات المزود بنجاح' : (admin.errorMessage ?? 'حدث خطأ')),
                      backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _openProviderProducts(ProviderModel provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderProductsScreen(provider: provider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'إدارة المزودين والربط المباشر',
          style: AppTypography.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryBlue),
            onPressed: () => _openAddEditDialog(),
          ),
        ],
      ),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : admin.providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('لا يوجد مزودين مضافين حالياً', style: AppTypography.cairo(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openAddEditDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: Text('إضافة أول مزود', style: AppTypography.arabicButton(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: admin.providers.length,
                  itemBuilder: (context, index) {
                    final provider = admin.providers[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                provider.name,
                                style: AppTypography.cairo(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              StatusPill(status: provider.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            provider.baseUrl,
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'رصيد المزود: \$${provider.balance.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (provider.lastCheckAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'آخر فحص: ${provider.lastCheckAt!.hour.toString().padLeft(2, '0')}:${provider.lastCheckAt!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                          if (provider.lastError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'خطأ: ${provider.lastError}',
                              style: const TextStyle(fontSize: 11, color: AppColors.errorLight),
                            ),
                          ],
                          const Divider(height: 20, color: AppColors.outline),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  // View Products button
                                  TextButton.icon(
                                    onPressed: () => _openProviderProducts(provider),
                                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                                    label: const Text('عرض المنتجات', style: TextStyle(fontSize: 12)),
                                  ),
                                  // Sync Products button
                                  TextButton.icon(
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('جاري مزامنة المنتجات والأسعار من المزود...')),
                                      );
                                      final res = await admin.syncProviderProducts(provider.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res?['message'] ?? 'تمت المزامنة بنجاح'),
                                            backgroundColor: res != null ? AppColors.tertiary : AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.sync, size: 16, color: AppColors.primary),
                                    label: const Text('مزامنة', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Test Status button
                                  IconButton(
                                    tooltip: 'فحص الاتصال وتحديث الرصيد',
                                    icon: const Icon(Icons.refresh, size: 20, color: AppColors.secondary),
                                    onPressed: () => admin.checkProviderStatus(provider.id),
                                  ),
                                  // Edit
                                  IconButton(
                                    tooltip: 'تعديل',
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                    onPressed: () => _openAddEditDialog(provider),
                                  ),
                                  // Delete
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                    onPressed: () => admin.deleteProvider(provider.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
