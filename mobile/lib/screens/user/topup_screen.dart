import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/balance_badge.dart';

class TopupScreen extends StatefulWidget {
  final bool showAppBar;
  const TopupScreen({super.key, this.showAppBar = true});

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  // Currently expanded method: 'id' | 'sham_cash' | 'binance' | 'codes' | null
  String? _expandedMethod = 'id';

  // Code Redeem
  final _codeController = TextEditingController();
  bool _isVerifyingCode = false;
  Map<String, dynamic>? _codeVerificationResult;

  // Sham Cash
  final _shamAmountController = TextEditingController();
  final _shamSenderController = TextEditingController();
  Uint8List? _shamReceiptBytes;
  String? _shamReceiptBase64;
  String? _shamReceiptName;

  // Binance
  final _binanceAmountController = TextEditingController();
  final _binanceSenderController = TextEditingController();
  Uint8List? _binanceReceiptBytes;
  String? _binanceReceiptBase64;
  String? _binanceReceiptName;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      wallet.fetchPaymentAccounts();
      wallet.fetchMyTopupRequests();
      wallet.fetchBalance();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _shamAmountController.dispose();
    _shamSenderController.dispose();
    _binanceAmountController.dispose();
    _binanceSenderController.dispose();
    super.dispose();
  }

  void _toggleMethod(String methodKey) {
    setState(() {
      if (_expandedMethod == methodKey) {
        _expandedMethod = null; // collapse if already open
      } else {
        _expandedMethod = methodKey;
      }
    });
  }

  // Pick receipt image (Gallery or Camera)
  Future<void> _pickReceipt(bool isSham) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر طريقة رفع إيصال التحويل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('اختيار صورة من المعرض'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _handleImagePick(isSham, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.secondary),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _handleImagePick(isSham, ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleImagePick(bool isSham, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final mimeType = image.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        final base64Str = 'data:$mimeType;base64,${base64Encode(bytes)}';

        setState(() {
          if (isSham) {
            _shamReceiptBytes = bytes;
            _shamReceiptBase64 = base64Str;
            _shamReceiptName = image.name;
          } else {
            _binanceReceiptBytes = bytes;
            _binanceReceiptBase64 = base64Str;
            _binanceReceiptName = image.name;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرفاق صورة الإيصال بنجاح ✅'), backgroundColor: AppColors.tertiary),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الصورة: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _removeReceipt(bool isSham) {
    setState(() {
      if (isSham) {
        _shamReceiptBytes = null;
        _shamReceiptBase64 = null;
        _shamReceiptName = null;
      } else {
        _binanceReceiptBytes = null;
        _binanceReceiptBase64 = null;
        _binanceReceiptName = null;
      }
    });
  }

  // Verify recharge code
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كود الشحن أولاً')),
      );
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _codeVerificationResult = null;
    });

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final result = await wallet.verifyCode(code);

    if (!mounted) return;

    setState(() {
      _isVerifyingCode = false;
      _codeVerificationResult = result ?? {'valid': false, 'message': wallet.errorMessage ?? 'الكود غير صحيح'};
    });
  }

  // Redeem recharge code
  void _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كود الشحن')),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msg = await wallet.redeemCode(code);

    if (!mounted) return;

    if (msg != null) {
      _codeController.clear();
      setState(() {
        _codeVerificationResult = null;
      });
      await auth.refreshProfile();
      await wallet.fetchBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.tertiary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wallet.errorMessage ?? 'فشل شحن الكود'), backgroundColor: AppColors.error),
      );
    }
  }

  // Submit Sham Cash topup request
  void _submitShamCash() async {
    final amount = double.tryParse(_shamAmountController.text.trim());
    final sender = _shamSenderController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح بالدولار')),
      );
      return;
    }

    if (sender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم حسابك المحول منه أو رقم العملية')),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final ok = await wallet.submitTopupRequest(
      type: 'sham_cash',
      amount: amount,
      details: {'senderAccount': sender},
      receiptImageUrl: _shamReceiptBase64,
    );

    if (!mounted) return;

    if (ok) {
      _shamAmountController.clear();
      _shamSenderController.clear();
      setState(() {
        _shamReceiptBytes = null;
        _shamReceiptBase64 = null;
        _shamReceiptName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الشحن بنجاح، جاري المراجعة ✅'), backgroundColor: AppColors.tertiary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wallet.errorMessage ?? 'فشل إرسال الطلب'), backgroundColor: AppColors.error),
      );
    }
  }

  // Submit Binance topup request
  void _submitBinance() async {
    final amount = double.tryParse(_binanceAmountController.text.trim());
    final sender = _binanceSenderController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح بالدولار USDT')),
      );
      return;
    }

    if (sender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال معرف الدفع الخاص بك (Pay ID / TxID)')),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final ok = await wallet.submitTopupRequest(
      type: 'binance',
      amount: amount,
      details: {'senderPayId': sender},
      receiptImageUrl: _binanceReceiptBase64,
    );

    if (!mounted) return;

    if (ok) {
      _binanceAmountController.clear();
      _binanceSenderController.clear();
      setState(() {
        _binanceReceiptBytes = null;
        _binanceReceiptBase64 = null;
        _binanceReceiptName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الشحن بنجاح، جاري المراجعة ✅'), backgroundColor: AppColors.tertiary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wallet.errorMessage ?? 'فشل إرسال الطلب'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: Text(
                'شحن الرصيد',
                style: AppTypography.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BalanceBadge(balance: user?.balance ?? 0.0),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await wallet.fetchPaymentAccounts();
          await wallet.fetchMyTopupRequests();
          await auth.refreshProfile();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Summary Card (Executive Swiss Slate)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, size: 28, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رصيدك المتاح حالياً',
                            style: AppTypography.cairo(fontSize: 12, color: Colors.white70),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${(user?.balance ?? 0.0).toStringAsFixed(2)}',
                            style: AppTypography.price(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'وسائل الشحن 👇',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Method 1: عبر الآيدي (Via ID)
              _buildMethodCard(
                methodKey: 'id',
                title: 'الشحن المباشر عبر الآيدي',
                subtitle: 'انسخ معرّف حسابك وزوّده للإدارة لشحن رصيدك فورياً',
                icon: Icons.badge_outlined,
                accentColor: AppColors.primaryBlue,
                isExpanded: _expandedMethod == 'id',
                content: _buildIdContent(user?.displayId ?? user?.id ?? ''),
              ),

              const SizedBox(height: 14),

              // Method 2: شام كاش (Sham Cash)
              _buildMethodCard(
                methodKey: 'sham_cash',
                title: 'شام كاش (Sham Cash)',
                subtitle: 'تحويل داخلي عبر الحساب مع باركود ورفع إيصال',
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AppColors.primaryBlue,
                isExpanded: _expandedMethod == 'sham_cash',
                content: _buildShamCashContent(wallet),
              ),

              const SizedBox(height: 14),

              // Method 3: بايناس (Binance)
              _buildMethodCard(
                methodKey: 'binance',
                title: 'بايناس (Binance Pay / USDT)',
                subtitle: 'تحويل رقمي مع Pay ID وباركود ورفع إيصال',
                icon: Icons.currency_bitcoin,
                accentColor: AppColors.ticketAmber,
                isExpanded: _expandedMethod == 'binance',
                content: _buildBinanceContent(wallet),
              ),

              const SizedBox(height: 14),

              // Method 4: أكواد الشحن (Recharge Code)
              _buildMethodCard(
                methodKey: 'codes',
                title: 'كود الشحن الرقمي (Recharge Code)',
                subtitle: 'إدخال الكود، التحقق من صلاحيته، وشحنه فورياً',
                icon: Icons.qr_code_2,
                accentColor: AppColors.emerald,
                isExpanded: _expandedMethod == 'codes',
                content: _buildCodesContent(wallet),
              ),

              const SizedBox(height: 24),

              // Previous Topup Requests section (if any)
              if (wallet.myTopupRequests.isNotEmpty) ...[
                Text(
                  'طلبات الشحن السابقة الخاصة بك',
                  style: AppTypography.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 10),
                ...wallet.myTopupRequests.take(5).map((req) => _buildTopupRequestItem(req)),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Common wrapper card for list items
  Widget _buildMethodCard({
    required String methodKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isExpanded,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? accentColor : AppColors.outline,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? accentColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Clickable tile
          InkWell(
            onTap: () => _toggleMethod(methodKey),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.cairo(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isExpanded ? accentColor : AppColors.slate400,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.outline),
            Padding(
              padding: const EdgeInsets.all(18),
              child: content,
            ),
          ],
        ],
      ),
    );
  }

  // 1. Content for 'عبر الآيدي' (Via ID)
  Widget _buildIdContent(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'معرّف الحساب المخصص لك (User ID)',
          style: AppTypography.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.slate700,
          ),
        ),
        const SizedBox(height: 10),

        // User ID Box with Copy Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معرّف الحساب (ID):',
                      style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      userId,
                      style: AppTypography.spaceMono(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: Text('نسخ', style: AppTypography.cairo(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: userId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ معرّف الحساب بنجاح 📋'), backgroundColor: AppColors.primaryBlue),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Instructions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'طريقة الاستخدام:',
                    style: AppTypography.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '1. انسخ معرّف حسابك أعلاه.\n2. زوّد إدارة النظام أو وكيل الشحن بالآيدي والمبلغ المطلوب عبر الواتساب أو التلغرام.\n3. سيتم تحويل الرصيد إلى محفظتك فورياً دون انتظار.',
                style: AppTypography.cairo(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Content for 'شام كاش' (Sham Cash)
  Widget _buildShamCashContent(WalletProvider wallet) {
    if (wallet.shamCashAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(
          'لا توجد حسابات شام كاش نشطة حالياً، يرجى مراجعة الإدارة عبر الواتساب.',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(color: AppColors.slate500, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Accounts Cards (Barcode, Account Name, Account ID)
        for (final acc in wallet.shamCashAccounts) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اسم الحساب:', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
                        Text(acc.accountName, style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppColors.primaryBlue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: acc.accountId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رقم الحساب')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('رقم الحساب:', style: AppTypography.cairo(fontSize: 12, color: AppColors.slate500)),
                      SelectableText(
                        acc.accountId,
                        style: AppTypography.spaceMono(fontSize: 16, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // QR / Barcode
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: QrImageView(
                    data: acc.accountId,
                    version: QrVersions.auto,
                    size: 130,
                  ),
                ),
                const SizedBox(height: 6),
                Text('امسح الباركود للتحويل المباشر', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Text('بيانات تأكيد التحويل:', style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        const SizedBox(height: 12),

        // Amount in USD Input
        TextField(
          controller: _shamAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'المبلغ المحول بالدولار (\$ USD)',
            labelStyle: AppTypography.cairo(color: AppColors.slate500),
            prefixIcon: const Icon(Icons.attach_money, color: AppColors.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
          ),
        ),

        const SizedBox(height: 12),

        // Sender account / Transaction ID
        TextField(
          controller: _shamSenderController,
          decoration: InputDecoration(
            labelText: 'رقم حسابك المحول منه أو رقم العملية',
            labelStyle: AppTypography.cairo(color: AppColors.slate500),
            prefixIcon: const Icon(Icons.receipt_long, color: AppColors.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
          ),
        ),

        const SizedBox(height: 14),

        // Receipt Upload Section
        _buildReceiptUploadBox(
          isSham: true,
          bytes: _shamReceiptBytes,
          name: _shamReceiptName,
        ),

        const SizedBox(height: 18),

        // Submit Button
        ElevatedButton.icon(
          icon: wallet.isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded),
          label: Text(
            wallet.isLoading ? 'جاري الإرسال...' : 'إرسال طلب الشحن',
            style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: wallet.isLoading ? null : _submitShamCash,
        ),
      ],
    );
  }

  // 3. Content for 'بايناس' (Binance Pay)
  Widget _buildBinanceContent(WalletProvider wallet) {
    if (wallet.binanceAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(
          'لا توجد حسابات بيناس نشطة حالياً، يرجى مراجعة الإدارة.',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(color: AppColors.slate500, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Accounts Cards (Barcode, Account Name, Pay ID)
        for (final acc in wallet.binanceAccounts) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اسم الحساب:', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
                        Text(acc.accountName, style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppColors.ticketAmber),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: acc.accountId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ Pay ID')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('معرف الدفع (Pay ID):', style: AppTypography.cairo(fontSize: 12, color: AppColors.slate500)),
                      SelectableText(
                        acc.accountId,
                        style: AppTypography.spaceMono(fontSize: 16, color: AppColors.ticketAmber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // QR / Barcode
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: QrImageView(
                    data: acc.accountId,
                    version: QrVersions.auto,
                    size: 130,
                  ),
                ),
                const SizedBox(height: 6),
                Text('امسح الباركود عبر تطبيق Binance للتحويل', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Text('بيانات تأكيد التحويل:', style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        const SizedBox(height: 12),

        // Amount in USD Input
        TextField(
          controller: _binanceAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'المبلغ المحول بالدولار USDT (\$)',
            labelStyle: AppTypography.cairo(color: AppColors.slate500),
            prefixIcon: const Icon(Icons.attach_money, color: AppColors.ticketAmber),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
          ),
        ),

        const SizedBox(height: 12),

        // Sender Pay ID / TxID
        TextField(
          controller: _binanceSenderController,
          decoration: InputDecoration(
            labelText: 'معرف الدفع الخاص بك (Pay ID / TxID)',
            labelStyle: AppTypography.cairo(color: AppColors.slate500),
            prefixIcon: const Icon(Icons.fingerprint, color: AppColors.ticketAmber),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
          ),
        ),

        const SizedBox(height: 14),

        // Receipt Upload Section
        _buildReceiptUploadBox(
          isSham: false,
          bytes: _binanceReceiptBytes,
          name: _binanceReceiptName,
        ),

        const SizedBox(height: 18),

        // Submit Button
        ElevatedButton.icon(
          icon: wallet.isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded),
          label: Text(
            wallet.isLoading ? 'جاري الإرسال...' : 'إرسال طلب الشحن',
            style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ticketAmber,
            foregroundColor: AppColors.slate900,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: wallet.isLoading ? null : _submitBinance,
        ),
      ],
    );
  }

  // Receipt image upload box with preview and delete action
  Widget _buildReceiptUploadBox({
    required bool isSham,
    required Uint8List? bytes,
    required String? name,
  }) {
    if (bytes != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 4),
                      Text('تم إرفاق صورة الإيصال', style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name ?? 'إيصال التحويل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.rose),
              tooltip: 'حذف الإيصال',
              onPressed: () => _removeReceipt(isSham),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: Text('رفع إيصال التحويل (صورة)', style: AppTypography.cairo(fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        side: const BorderSide(color: AppColors.outline),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _pickReceipt(isSham),
    );
  }

  // 4. Content for 'أكواد الشحن' (Recharge Code)
  Widget _buildCodesContent(WalletProvider wallet) {
    final hasVerified = _codeVerificationResult != null;
    final isValid = hasVerified && (_codeVerificationResult!['valid'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدخل كود الشحن الرقمي المكون من أرقام وحروف:',
          style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate700),
        ),
        const SizedBox(height: 10),

        // Code Input Field
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: AppTypography.spaceMono(fontWeight: FontWeight.bold, letterSpacing: 1.5),
          onChanged: (_) {
            if (_codeVerificationResult != null) {
              setState(() {
                _codeVerificationResult = null;
              });
            }
          },
          decoration: InputDecoration(
            labelText: 'كود الشحن (مثال: CHG-ABCD-1234)',
            labelStyle: AppTypography.cairo(color: AppColors.slate500),
            prefixIcon: const Icon(Icons.qr_code_2, color: AppColors.emerald),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
            suffixIcon: _codeController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _codeController.clear();
                      setState(() {
                        _codeVerificationResult = null;
                      });
                    },
                  )
                : null,
          ),
        ),

        const SizedBox(height: 12),

        // Verify Code Button
        OutlinedButton.icon(
          icon: _isVerifyingCode
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified_outlined, size: 18),
          label: Text(
            _isVerifyingCode ? 'جاري التحقق...' : 'التحقق من صلاحية الكود',
            style: AppTypography.cairo(fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.emerald,
            side: const BorderSide(color: AppColors.emerald),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isVerifyingCode ? null : _verifyCode,
        ),

        // Verification Result Banner
        if (hasVerified) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isValid ? AppColors.emerald.withValues(alpha: 0.1) : AppColors.rose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isValid ? AppColors.emerald : AppColors.rose),
            ),
            child: Row(
              children: [
                Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? AppColors.emerald : AppColors.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid ? 'كود صالح للاستخدام ✅' : 'الكود غير صالح ❌',
                        style: AppTypography.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isValid ? AppColors.emerald : AppColors.rose,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _codeVerificationResult!['message']?.toString() ?? '',
                        style: AppTypography.cairo(fontSize: 12, color: AppColors.slate900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Recharge Code Now Button
        ElevatedButton.icon(
          icon: wallet.isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.bolt),
          label: Text(
            wallet.isLoading ? 'جاري شحن الكود...' : 'شحن الكود الآن',
            style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: wallet.isLoading ? null : _redeemCode,
        ),
      ],
    );
  }

  // Item for previous topup requests
  Widget _buildTopupRequestItem(dynamic req) {
    Color statusColor;
    String statusText;
    switch (req.status) {
      case 'approved':
        statusColor = AppColors.emerald;
        statusText = 'مقبول ومضاف';
        break;
      case 'rejected':
        statusColor = AppColors.rose;
        statusText = 'مرفوض';
        break;
      default:
        statusColor = AppColors.ticketAmber;
        statusText = 'قيد المراجعة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'طلب شحن بقيمة ',
                    style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  Text(
                    '\$${req.amount.toStringAsFixed(2)}',
                    style: AppTypography.price(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  Text(
                    ' (${req.type == 'sham_cash' ? 'شام كاش' : 'بيناس'})',
                    style: AppTypography.cairo(fontSize: 12, color: AppColors.slate500),
                  ),
                ],
              ),
              if (req.adminNotes != null && req.adminNotes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('ملاحظات: ${req.adminNotes}', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
              ],
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusText,
              style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
