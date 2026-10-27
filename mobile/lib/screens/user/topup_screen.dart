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
import '../../providers/exchange_rate_provider.dart';
import '../../models/payment_account_model.dart';
import '../../widgets/balance_badge.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/digital_pass_card.dart';

class TopupScreen extends StatefulWidget {
  final bool showAppBar;
  const TopupScreen({super.key, this.showAppBar = true});

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  // آخر طريقة دفع فُتحت: 'id' | 'sham_cash' | 'binance' | 'codes'
  String? _selectedMethod;

  // فلتر سجل «طلباتي الأخيرة»: all | sham_cash | binance | code | id
  String _topupLogFilter = 'all';

  /// النافذة المنبثقة ليست جزءاً من شجرة الصفحة، فتحتاج علامة تحديث خاصة بها
  final ValueNotifier<int> _sheetTick = ValueNotifier<int>(0);
  BuildContext? _sheetContext;
  Widget? _sheetBanner;

  // Preset quick amounts in USD
  static const List<double> _quickAmounts = [5.0, 10.0, 25.0, 50.0, 100.0];

  // Code Redeem
  final _codeController = TextEditingController();
  bool _isVerifyingCode = false;
  Map<String, dynamic>? _codeVerificationResult;

  // Sham Cash
  // شام كاش لا يطلب رقم حساب المرسل: صورة الإيصال مع المبلغ تكفي للتحقق
  final _shamAmountController = TextEditingController();
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
      Provider.of<ExchangeRateProvider>(context, listen: false).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _shamAmountController.dispose();
    _binanceAmountController.dispose();
    _binanceSenderController.dispose();
    _sheetTick.dispose();
    super.dispose();
  }

  /// تحديث حالة النموذج داخل الصفحة وداخل نافذة طريقة الدفع معاً
  void _refreshForm(VoidCallback mutate) {
    setState(mutate);
    _sheetTick.value++;
  }

  /// إغلاق نافذة طريقة الدفع بعد نجاح العملية
  void _closeSheet() {
    final BuildContext? sheet = _sheetContext;
    _sheetContext = null;
    if (sheet != null && Navigator.of(sheet).canPop()) {
      Navigator.of(sheet).pop();
    }
  }

  /// رسالة للمستخدم: SnackBar في الصفحة، أو شريط داخل نافذة طريقة الدفع
  /// لأن النافذة تغطي الشريط السفلي للصفحة
  void _showMessage(SnackBar snackBar) {
    if (_sheetContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    final Color tone = snackBar.backgroundColor ?? const Color(0xFF334155);
    _refreshForm(() {
      _sheetBanner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: tone.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: snackBar.content,
      );
    });

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted || _sheetContext == null || _sheetBanner == null) return;
      _refreshForm(() => _sheetBanner = null);
    });
  }

  // Pick receipt image (Gallery or Camera)
  Future<void> _pickReceipt(bool isSham) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'إرفاق إيصال التحويل',
                style: AppTypography.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختر طريقة رفع صورة الإشعار أو لقطة الشاشة',
                style: AppTypography.cairo(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF38BDF8),
                    size: 22,
                  ),
                ),
                title: Text(
                  'اختيار صورة من المعرض',
                  style: AppTypography.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'صور المعرض ولقطات الشاشة المحفوظة',
                  style: AppTypography.cairo(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _handleImagePick(isSham, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF34D399),
                    size: 22,
                  ),
                ),
                title: Text(
                  'التقاط صورة بالكاميرا',
                  style: AppTypography.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'تصوير الإشعار الورقي أو شاشة الجهاز فورياً',
                  style: AppTypography.cairo(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
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
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final mimeType = image.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        final base64Str = 'data:$mimeType;base64,${base64Encode(bytes)}';

        _refreshForm(() {
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
          _showMessage(
            SnackBar(
              content: Text(
                'تم إرفاق صورة الإيصال بنجاح ✅',
                style: AppTypography.cairo(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          SnackBar(
            content: Text(
              'تعذر اختيار الصورة: $e',
              style: AppTypography.cairo(),
            ),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeReceipt(bool isSham) {
    _refreshForm(() {
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
      _showMessage(
        SnackBar(
          content: Text(
            'يرجى إدخال كود الشحن أولاً',
            style: AppTypography.cairo(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _refreshForm(() {
      _isVerifyingCode = true;
      _codeVerificationResult = null;
    });

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final result = await wallet.verifyCode(code);

    if (!mounted) return;

    _refreshForm(() {
      _isVerifyingCode = false;
      _codeVerificationResult =
          result ??
          {
            'valid': false,
            'message':
                wallet.errorMessage ?? 'الكود غير صحيح أو منتهي الصلاحية',
          };
    });
  }

  // Redeem recharge code
  void _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage(
        SnackBar(
          content: Text('يرجى إدخال كود الشحن', style: AppTypography.cairo()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msg = await wallet.redeemCode(code);

    if (!mounted) return;

    if (msg != null) {
      _codeController.clear();
      _refreshForm(() {
        _codeVerificationResult = null;
      });
      _closeSheet();
      await auth.refreshProfile();
      await wallet.fetchBalance();
      if (!mounted) return;
      _showMessage(
        SnackBar(
          content: Text(msg, style: AppTypography.cairo(color: Colors.white)),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showMessage(
        SnackBar(
          content: Text(
            wallet.errorMessage ?? 'فشل شحن الكود',
            style: AppTypography.cairo(),
          ),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Submit Sham Cash topup request
  void _submitShamCash() async {
    final amount = double.tryParse(_shamAmountController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage(
        SnackBar(
          content: Text(
            'يرجى إدخال مبلغ صحيح بالدولار (\$)',
            style: AppTypography.cairo(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);

    // رفع صورة الإيصال أولاً للحصول على رابط مستقر
    String? receiptUrl;
    if (_shamReceiptBase64 != null) {
      receiptUrl = await wallet.uploadReceiptImage(_shamReceiptBase64!);
      if (receiptUrl == null && mounted) {
        _showMessage(
          SnackBar(
            content: Text(
              'تعذر رفع صورة الإيصال على السيرفر، ستُرسل مع الطلب مباشرة',
              style: AppTypography.cairo(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    final ok = await wallet.submitTopupRequest(
      type: 'sham_cash',
      amount: amount,
      details: const {},
      receiptImageUrl: receiptUrl ?? _shamReceiptBase64,
    );

    if (!mounted) return;

    if (ok) {
      _shamAmountController.clear();
      _refreshForm(() {
        _shamReceiptBytes = null;
        _shamReceiptBase64 = null;
        _shamReceiptName = null;
      });
      _closeSheet();
      _showMessage(
        SnackBar(
          content: Text(
            'تم إرسال طلب الشحن بنجاح، جاري المراجعة ✅',
            style: AppTypography.cairo(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showMessage(
        SnackBar(
          content: Text(
            wallet.errorMessage ?? 'فشل إرسال الطلب',
            style: AppTypography.cairo(),
          ),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Submit Binance topup request
  void _submitBinance() async {
    final amount = double.tryParse(_binanceAmountController.text.trim());
    final sender = _binanceSenderController.text.trim();

    if (amount == null || amount <= 0) {
      _showMessage(
        SnackBar(
          content: Text(
            'يرجى إدخال مبلغ صحيح بالدولار USDT',
            style: AppTypography.cairo(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (sender.isEmpty) {
      _showMessage(
        SnackBar(
          content: Text(
            'يرجى إدخال معرف الدفع الخاص بك (Pay ID / TxID)',
            style: AppTypography.cairo(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);

    // رفع صورة الإيصال أولاً للحصول على رابط مستقر
    String? receiptUrl;
    if (_binanceReceiptBase64 != null) {
      receiptUrl = await wallet.uploadReceiptImage(_binanceReceiptBase64!);
      if (receiptUrl == null && mounted) {
        _showMessage(
          SnackBar(
            content: Text(
              'تعذر رفع صورة الإيصال على السيرفر، ستُرسل مع الطلب مباشرة',
              style: AppTypography.cairo(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    final ok = await wallet.submitTopupRequest(
      type: 'binance',
      amount: amount,
      details: {'txid': sender},
      receiptImageUrl: receiptUrl ?? _binanceReceiptBase64,
    );

    if (!mounted) return;

    if (ok) {
      _binanceAmountController.clear();
      _binanceSenderController.clear();
      _refreshForm(() {
        _binanceReceiptBytes = null;
        _binanceReceiptBase64 = null;
        _binanceReceiptName = null;
      });
      _closeSheet();
      _showMessage(
        SnackBar(
          content: Text(
            'تم إرسال طلب الشحن بنجاح، جاري المراجعة ✅',
            style: AppTypography.cairo(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showMessage(
        SnackBar(
          content: Text(
            wallet.errorMessage ?? 'فشل إرسال الطلب',
            style: AppTypography.cairo(),
          ),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Show Account Payment Code Dialog (صورة الباركود المرفوعة أو QR مولّد)
  void _showAccountQrModal(
    String title,
    PaymentAccountModel acc,
    Color accentColor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  acc.barcodeUrl.trim().isEmpty
                      ? Icons.qr_code_2_rounded
                      : Icons.qr_code_scanner_rounded,
                  color: accentColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _accountPayCodeImage(acc, 220),
            ),
            const SizedBox(height: 12),
            Text(
              acc.accountName,
              style: AppTypography.cairo(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              acc.accountId,
              style: AppTypography.technicalCode(
                color: accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                'نسخ المعرف',
                style: AppTypography.cairo(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: acc.accountId));
                Navigator.pop(ctx);
                _showMessage(
                  const SnackBar(
                    content: Text('تم نسخ المعرف بنجاح 📋'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// صورة الدفع: الباركود المرفوع من الأدمن، أو QR مولّد من رقم الحساب كاحتياط
  Widget _accountPayCodeImage(PaymentAccountModel acc, double size) {
    if (acc.barcodeUrl.trim().isEmpty) {
      return _generatedQr(acc.accountId, size);
    }
    return Image.network(
      acc.barcodeUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _generatedQr(acc.accountId, size),
    );
  }

  Widget _generatedQr(String data, double size) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);
    final rates = Provider.of<ExchangeRateProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 1,
              centerTitle: false,
              title: Text(
                'شحن المحفظة والرصيد',
                style: AppTypography.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: BalanceBadge(balance: user?.balance ?? 0.0),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        onRefresh: () async {
          await wallet.fetchPaymentAccounts();
          await wallet.fetchMyTopupRequests();
          await auth.refreshProfile();
          await rates.fetch(force: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Compact header (wallet + exchange rate)
              _buildCompactHeader(user, wallet, rates),

              const SizedBox(height: 12),

              // 2. Payment method selector
              _buildModernMethodTabs(),

              const SizedBox(height: 12),

              // 3. نموذج الطريقة يُعرض في نافذة منبثقة عند اختيارها
              Text(
                'اضغط على طريقة الدفع لفتح نافذة الطلب وإتمام الشحن',
                textAlign: TextAlign.center,
                style: AppTypography.cairo(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Previous Top-up Requests Section
              if (wallet.myTopupRequests.isNotEmpty) ...[
                _buildRecentRequestsSection(wallet),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 0. SECTION CARD (بطاقة قسم نظيفة ومدمجة)
  // ---------------------------------------------------------------------------
  /// السطح الأساسي لكل قسم في الصفحة: بطاقة بيضاء بحواف ناعمة وحشوة داخلية
  Widget _sectionCard({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. COMPACT HEADER CARD (الرصيد + سعر الصرف في بطاقة واحدة)
  // ---------------------------------------------------------------------------
  Widget _buildCompactHeader(
    dynamic user,
    WalletProvider wallet,
    ExchangeRateProvider rates,
  ) {
    final pendingCount = wallet.myTopupRequests
        .where((r) => r.status == 'pending')
        .length;
    final rate = rates.rate;
    final rateAvailable = rates.hasRate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1329), Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0284C7).withValues(alpha: 0.22),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF38BDF8),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),

          // Name + balance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.name ?? 'عميل JGO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                // يصغر عند ضيق المساحة بدل أن يفيض على كبسولة سعر الصرف
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${(user?.balance ?? 0.0).toStringAsFixed(2)}',
                        style: AppTypography.price(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'USD',
                        style: AppTypography.technicalCode(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '$pendingCount قيد المراجعة',
                            style: AppTypography.cairo(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFCD34D),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Mini exchange-rate capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.currency_exchange_rounded,
                  size: 14,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'سعر الصرف اليوم',
                      style: AppTypography.cairo(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    Text(
                      rateAvailable ? '${rate!.rateText} ل.س' : '— ل.س',
                      style: AppTypography.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFBBF24),
                      ),
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

  // ---------------------------------------------------------------------------
  // 2. SEGMENTED METHOD TABS (Pills)
  // ---------------------------------------------------------------------------
  Widget _buildModernMethodTabs() {
    // شريط اختيار طريقة الدفع — 4 عناصر متساوية بمقاس مضغوط
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMethodTabItem(
              id: 'id',
              title: 'الآيدي',
              icon: Icons.fingerprint_rounded,
              activeColor: const Color(0xFF0284C7),
            ),
          ),
          Expanded(
            child: _buildMethodTabItem(
              id: 'sham_cash',
              title: 'شام كاش',
              icon: Icons.account_balance_wallet_rounded,
              activeColor: const Color(0xFF2563EB),
              brand: BrandLogo.shamCash,
            ),
          ),
          Expanded(
            child: _buildMethodTabItem(
              id: 'binance',
              title: 'Binance',
              icon: Icons.currency_bitcoin_rounded,
              activeColor: const Color(0xFFD97706),
              brand: BrandLogo.binance,
            ),
          ),
          Expanded(
            child: _buildMethodTabItem(
              id: 'codes',
              title: 'أكواد',
              icon: Icons.confirmation_number_rounded,
              activeColor: const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabItem({
    required String id,
    required String title,
    required IconData icon,
    required Color activeColor,
    String? brand,
  }) {
    final isSelected = _selectedMethod == id;

    return InkWell(
      onTap: () => _openMethodSheet(
        id: id,
        title: title,
        icon: icon,
        color: activeColor,
        brand: brand,
      ),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (brand != null)
              BrandLogo(asset: brand, size: 18, radius: 5)
            else
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.slate600,
              ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2.b METHOD FORM SHEET (نموذج طريقة الدفع في نافذة منبثقة)
  // ---------------------------------------------------------------------------
  Future<void> _openMethodSheet({
    required String id,
    required String title,
    required IconData icon,
    required Color color,
    String? brand,
  }) async {
    setState(() => _selectedMethod = id);
    _sheetBanner = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (sheetContext) {
        _sheetContext = sheetContext;
        final user = Provider.of<AuthProvider>(
          sheetContext,
          listen: false,
        ).currentUser;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: brand != null
                            ? BrandLogo(asset: brand, size: 18, radius: 5)
                            : Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        tooltip: 'إغلاق',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _sheetTick,
                    builder: (_, _, _) => Stack(
                      children: [
                        Consumer<WalletProvider>(
                          builder: (_, wallet, _) => SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            child: _buildCurrentTabContent(user, wallet),
                          ),
                        ),
                        if (_sheetBanner != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 10,
                            child: _sheetBanner!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    _sheetContext = null;
  }

  // ---------------------------------------------------------------------------
  // 3. TAB CONTENT SELECTOR
  // ---------------------------------------------------------------------------
  Widget _buildCurrentTabContent(dynamic user, WalletProvider wallet) {
    switch (_selectedMethod) {
      case 'id':
        return _buildIdTabContent(user);
      case 'sham_cash':
        return _buildShamCashTabContent(wallet);
      case 'binance':
        return _buildBinanceTabContent(wallet);
      case 'codes':
        return _buildCodesTabContent(wallet);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 1: VIA ID (الشحن المباشر عبر الآيدي)
  // ---------------------------------------------------------------------------
  Widget _buildIdTabContent(dynamic user) {
    final userId = user?.displayId ?? user?.id ?? '8940-CX';

    return _sectionCard(
      key: const ValueKey('tab_id'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الشحن المباشر عبر معرّف الحساب',
                      style: AppTypography.cairo(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'زوّد وكيلك أو الإدارة بالآيدي لشحن رصيدك فورياً',
                      style: AppTypography.cairo(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Luxury ID Showcase Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معرّف حسابك الخاص (UID):',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      SelectableText(
                        userId,
                        style: AppTypography.technicalCode(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0284C7),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: Text(
                    'نسخ الآيدي',
                    style: AppTypography.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: userId));
                    _showMessage(
                      SnackBar(
                        content: Text(
                          'تم نسخ الآيدي: $userId بنجاح 📋',
                          style: AppTypography.cairo(),
                        ),
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Steps list with stylish modern bullets
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildSimpleStepRow(
                  number: '1',
                  title: 'انسخ معرّف حسابك',
                  desc: 'اضغط على زر "نسخ الآيدي" الموضح بالأعلى.',
                ),
                const SizedBox(height: 10),
                _buildSimpleStepRow(
                  number: '2',
                  title: 'أرسله للوكيل أو الدعم الفني',
                  desc:
                      'تواصل مع إدارتنا أو وكيلك المعتمد وزوّده بالآيدي والمبلغ المطلوب.',
                ),
                const SizedBox(height: 10),
                _buildSimpleStepRow(
                  number: '3',
                  title: 'إيداع فوري وآمن',
                  desc: 'يتم شحن المبلغ المالي في رصيدك فورياً دون أي تأخير.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStepRow({
    required String number,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                desc,
                style: AppTypography.cairo(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: SHAM CASH (شام كاش)
  // ---------------------------------------------------------------------------
  Widget _buildShamCashTabContent(WalletProvider wallet) {
    if (wallet.shamCashAccounts.isEmpty) {
      return _buildEmptyAccountsCard('شام كاش');
    }

    return _sectionCard(
      key: const ValueKey('tab_sham_cash'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const BrandLogo(
                  asset: BrandLogo.shamCash,
                  size: 20,
                  radius: 5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حسابات الدفع عبر شام كاش',
                  style: AppTypography.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Payment Destination Cards
          for (final acc in wallet.shamCashAccounts)
            _buildDestinationCard(
              title: 'حساب شام كاش الرسمي',
              acc: acc,
              accentColor: const Color(0xFF2563EB),
            ),

          const SizedBox(height: 12),

          // Preset Amount Selector ($5, $10, $25, $50, $100)
          Text(
            'اختر أو أدخل المبلغ المطلوب (\$ USD):',
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickAmountChips(
            _shamAmountController,
            const Color(0xFF2563EB),
          ),

          const SizedBox(height: 12),

          // Custom Amount Input
          TextField(
            controller: _shamAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.technicalCode(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'المبلغ المحول بالدولار (\$ USD)',
              labelStyle: AppTypography.cairo(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              prefixIcon: const Icon(
                Icons.attach_money_rounded,
                color: Color(0xFF2563EB),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Receipt Upload Component
          _buildModernReceiptBox(
            isSham: true,
            bytes: _shamReceiptBytes,
            name: _shamReceiptName,
            accentColor: const Color(0xFF2563EB),
          ),

          const SizedBox(height: 12),

          // Submit Button
          ElevatedButton.icon(
            icon: wallet.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 17),
            label: Text(
              wallet.isLoading
                  ? 'جاري إرسال الطلب...'
                  : 'تأكيد وإرسال طلب الشحن',
              style: AppTypography.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: wallet.isLoading ? null : _submitShamCash,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: BINANCE PAY (USDT)
  // ---------------------------------------------------------------------------
  Widget _buildBinanceTabContent(WalletProvider wallet) {
    if (wallet.binanceAccounts.isEmpty) {
      return _buildEmptyAccountsCard('بايناس');
    }

    return _sectionCard(
      key: const ValueKey('tab_binance'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const BrandLogo(
                  asset: BrandLogo.binance,
                  size: 20,
                  radius: 5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حسابات الدفع عبر Binance Pay (USDT)',
                  style: AppTypography.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Payment Destination Cards
          for (final acc in wallet.binanceAccounts)
            _buildDestinationCard(
              title: 'حساب Binance Pay الرسمي',
              acc: acc,
              accentColor: const Color(0xFFD97706),
            ),

          const SizedBox(height: 12),

          // Preset Amount Selector
          Text(
            'اختر أو أدخل المبلغ المطلوب (\$ USDT):',
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickAmountChips(
            _binanceAmountController,
            const Color(0xFFD97706),
          ),

          const SizedBox(height: 12),

          // Custom Amount Input
          TextField(
            controller: _binanceAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.technicalCode(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'المبلغ المحول بالدولار (\$ USDT)',
              labelStyle: AppTypography.cairo(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              prefixIcon: const Icon(
                Icons.attach_money_rounded,
                color: Color(0xFFD97706),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD97706),
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sender Pay ID / TxID
          TextField(
            controller: _binanceSenderController,
            style: AppTypography.technicalCode(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'معرف الدفع الخاص بك (Pay ID أو TxID)',
              labelStyle: AppTypography.cairo(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              prefixIcon: const Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFFD97706),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD97706),
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Receipt Upload Component
          _buildModernReceiptBox(
            isSham: false,
            bytes: _binanceReceiptBytes,
            name: _binanceReceiptName,
            accentColor: const Color(0xFFD97706),
          ),

          const SizedBox(height: 12),

          // Submit Button
          ElevatedButton.icon(
            icon: wallet.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 17),
            label: Text(
              wallet.isLoading
                  ? 'جاري إرسال الطلب...'
                  : 'تأكيد وإرسال طلب الشحن',
              style: AppTypography.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: wallet.isLoading ? null : _submitBinance,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: RECHARGE CODES (أكواد الشحن الرقمية)
  // ---------------------------------------------------------------------------
  Widget _buildCodesTabContent(WalletProvider wallet) {
    final hasVerified = _codeVerificationResult != null;
    final isValid = hasVerified && (_codeVerificationResult!['valid'] == true);

    return _sectionCard(
      key: const ValueKey('tab_codes'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: Color(0xFF059669),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'شحن كود رقمي مباشر (Voucher)',
                  style: AppTypography.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'أدخل كود الشحن الخاص بك ليتم إضافة قيمته لمحفظتك فوراً',
            style: AppTypography.cairo(
              fontSize: 11.5,
              color: const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 12),

          // Code Input Field with Paste & Clear Buttons
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            style: AppTypography.technicalCode(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: const Color(0xFF0F172A),
            ),
            onChanged: (_) {
              if (_codeVerificationResult != null) {
                setState(() {
                  _codeVerificationResult = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'كود الشحن الرقمي',
              hintText: 'CHG-XXXX-XXXX',
              labelStyle: AppTypography.cairo(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              hintStyle: AppTypography.technicalCode(
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.5,
              ),
              prefixIcon: const Icon(
                Icons.vpn_key_rounded,
                color: Color(0xFF10B981),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 1.5,
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.content_paste_rounded,
                      color: Color(0xFF0284C7),
                      size: 19,
                    ),
                    tooltip: 'لصق الكود',
                    onPressed: () async {
                      final data = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        _codeController.text = data.text!.trim().toUpperCase();
                        setState(() {
                          _codeVerificationResult = null;
                        });
                      }
                    },
                  ),
                  if (_codeController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      onPressed: () {
                        _codeController.clear();
                        setState(() {
                          _codeVerificationResult = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Verify Button
          OutlinedButton.icon(
            icon: _isVerifyingCode
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF059669),
                    ),
                  )
                : const Icon(Icons.verified_outlined, size: 17),
            label: Text(
              _isVerifyingCode
                  ? 'جاري التحقق من الكود...'
                  : 'التحقق من صلاحية الكود أولاً',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF059669),
              side: const BorderSide(color: Color(0xFF10B981)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isVerifyingCode ? null : _verifyCode,
          ),

          // Verification Status Banner
          if (hasVerified) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isValid
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isValid
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isValid
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: isValid
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isValid
                              ? 'كود شحن صالح ومطابق ✅'
                              : 'الكود غير صالح ❌',
                          style: AppTypography.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isValid
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                        Text(
                          _codeVerificationResult!['message']?.toString() ?? '',
                          style: AppTypography.cairo(
                            fontSize: 11,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Redeem Button
          ElevatedButton.icon(
            icon: wallet.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.bolt_rounded, size: 19),
            label: Text(
              wallet.isLoading
                  ? 'جاري شحن الرصيد...'
                  : 'شحن الكود فورياً في المحفظة',
              style: AppTypography.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: wallet.isLoading ? null : _redeemCode,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER COMPONENTS
  // ---------------------------------------------------------------------------

  // Quick Amount Selector Chips ($5, $10, $25, $50, $100)
  Widget _buildQuickAmountChips(
    TextEditingController controller,
    Color activeColor,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _quickAmounts.map((amt) {
          final amtStr = amt.toInt().toString();
          final isSelected = controller.text.trim() == amtStr;

          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  controller.text = amtStr;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? activeColor : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  '\$$amtStr',
                  style: AppTypography.technicalCode(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Payment Destination Card (صورة الباركود + اسم الحساب + الرقم مع نسخ)
  Widget _buildDestinationCard({
    required String title,
    required PaymentAccountModel acc,
    required Color accentColor,
  }) {
    final accountId = acc.accountId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة كود الدفع (باركود مرفوع أو QR مولّد) — الضغط للتكبير
          InkWell(
            onTap: () => _showAccountQrModal(title, acc, accentColor),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _accountPayCodeImage(acc, 110)),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.9),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Account details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cairo(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  acc.accountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                // Account ID bar with 1-tap copy
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          accountId,
                          style: AppTypography.technicalCode(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: accountId));
                          _showMessage(
                            SnackBar(
                              content: Text(
                                'تم نسخ: $accountId بنجاح 📋',
                                style: AppTypography.cairo(),
                              ),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'نسخ',
                                style: AppTypography.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'حول إلى هذا الحساب ثم اضغط الصورة للتكبير',
                  style: AppTypography.cairo(
                    fontSize: 9.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Receipt Box
  Widget _buildModernReceiptBox({
    required bool isSham,
    required Uint8List? bytes,
    required String? name,
    required Color accentColor,
  }) {
    if (bytes != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                width: 50,
                height: 50,
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
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'تم إرفاق إيصال التحويل',
                        style: AppTypography.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name ?? 'صورة الإشعار',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'حذف الإيصال',
              onPressed: () => _removeReceipt(isSham),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
      label: Text(
        'إرفاق إيصال أو صورة التحويل (اختياري/موصى به)',
        style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _pickReceipt(isSham),
    );
  }

  Widget _buildEmptyAccountsCard(String methodTitle) {
    return _sectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 36,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد حسابات نشطة حالياً لـ $methodTitle',
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يرجى التواصل مع الإدارة أو استخدام طريقة شحن أخرى كالمعرّف المباشر.',
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 11.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. RECENT TOPUP REQUESTS
  // ---------------------------------------------------------------------------
  Widget _buildRecentRequestsSection(WalletProvider wallet) {
    final all = wallet.myTopupRequests;
    final shown = all.where((r) => _matchesLogFilter(r.type)).toList();

    int countOf(String key) =>
        all.where((r) => _matchesLogFilter(r.type, key)).length;

    return _sectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلباتي الأخيرة',
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${all.length} عمليات',
                style: AppTypography.cairo(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _logFilterChip('all', 'الكل', all.length),
                const SizedBox(width: 6),
                _logFilterChip('sham_cash', 'شام كاش', countOf('sham_cash')),
                const SizedBox(width: 6),
                _logFilterChip('binance', 'Binance', countOf('binance')),
                const SizedBox(width: 6),
                _logFilterChip('code', 'كروت الشحن', countOf('code')),
                const SizedBox(width: 6),
                _logFilterChip('id', 'آيدي', countOf('id')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'لا توجد عمليات في هذا النوع',
                textAlign: TextAlign.center,
                style: AppTypography.cairo(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            )
          else
            ...shown.take(5).map((req) => _buildTopupRequestItem(req)),
        ],
      ),
    );
  }

  /// هل تنتمي العملية لنوع الفلتر المختار؟
  /// فلتر «آيدي» يجمع الشحن المباشر من الإدارة مع طلب «معرّف مباشر».
  bool _matchesLogFilter(String type, [String? filter]) {
    final String f = filter ?? _topupLogFilter;
    if (f == 'all') return true;
    if (f == 'id') return type == 'id_topup' || type == 'id_recharge';
    return type == f;
  }

  Widget _logFilterChip(String key, String label, int count) {
    final bool selected = _topupLogFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _topupLogFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? const Color(0xFF0F172A) : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.plusJakartaSans(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopupRequestItem(dynamic req) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (req.status) {
      case 'approved':
        statusColor = const Color(0xFF059669);
        statusText = 'مقبول';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFDC2626);
        statusText = 'مرفوض';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusText = 'قيد المراجعة';
        statusIcon = Icons.schedule_rounded;
    }

    // نوع العملية: طلب يدوي (شام كاش / بينانس / معرّف مباشر) أو شحن عبر كود
    String methodLabel;
    switch (req.type) {
      case 'sham_cash':
        methodLabel = 'شام كاش';
        break;
      case 'binance':
        methodLabel = 'Binance Pay';
        break;
      case 'id_recharge':
        methodLabel = 'معرّف مباشر';
        break;
      case 'id_topup':
        methodLabel = 'شحن بالآيدي';
        break;
      case 'code':
        methodLabel = 'كود شحن';
        break;
      default:
        methodLabel = 'شحن رصيد';
    }

    // السطر الثاني: كود الشحن إن كانت العملية عبر كود، وإلا ملاحظات الإدارة
    final String codeValue = req.details is Map
        ? (req.details['code'] ?? '').toString().trim()
        : '';
    final String notesText = (req.adminNotes ?? '').toString().trim();
    final String? noteLine = codeValue.isNotEmpty
        ? 'الكود: $codeValue'
        : (notesText.isNotEmpty ? 'ملاحظات: $notesText' : null);

    // لمسة التذكرة: طرفان نصف دائرة مقتطعان فعلياً من الحافتين
    // (نفس هوية التذاكر في شاشة طلباتي وشحن المحفظة)
    // الكعب عند الطرف الأيسر: خلفية فاتحة بلون الحالة خلف كلمة الحالة،
    // وتفصله عن جسم الصف حافة مثقوبة
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CustomPaint(
        foregroundPainter: TicketPassBorderPainter(
          cornerRadius: 10,
          notchRadius: 6,
          borderColor: AppColors.outline,
        ),
        child: ClipPath(
          clipper: TicketPassClipper(cornerRadius: 10, notchRadius: 6),
          child: Container(
            color: AppColors.background,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                '\$${req.amount.toStringAsFixed(2)}',
                                style: AppTypography.price(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '• $methodLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cairo(
                                    fontSize: 10.5,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (noteLine != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              noteLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cairo(
                                fontSize: 9.5,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _stubPerforation(statusColor),
                  Container(
                    width: 74,
                    color: statusColor.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// خط تثقيب رأسي يفصل كعب التذكرة الملون عن جسمها
  Widget _stubPerforation(Color color) {
    return SizedBox(
      width: 9,
      child: CustomPaint(
        painter: _StubPerforationPainter(color: color.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _StubPerforationPainter extends CustomPainter {
  final Color color;
  const _StubPerforationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const double dash = 4;
    const double gap = 3.5;
    const double inset = 6;
    double y = inset;
    while (y < size.height - inset) {
      final double end = y + dash < size.height - inset
          ? y + dash
          : size.height - inset;
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, end),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_StubPerforationPainter oldDelegate) =>
      oldDelegate.color != color;
}
