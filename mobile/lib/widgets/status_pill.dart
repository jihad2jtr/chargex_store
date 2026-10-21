import 'package:flutter/material.dart';
import '../core/theme/app_typography.dart';

class StatusPill extends StatelessWidget {
  final String status;
  final String? label;

  const StatusPill({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String display = label ?? status;

    switch (status.toLowerCase()) {
      case 'online':
      case 'completed':
      case 'approved':
      case 'active':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        if (label == null) {
          if (status == 'online') display = 'متصل';
          if (status == 'completed') display = 'مكتمل';
          if (status == 'approved') display = 'تمت الموافقة';
          if (status == 'active') display = 'مفعل';
        }
        break;
      case 'pending':
      case 'processing':
      case 'assigned':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        if (label == null) {
          if (status == 'pending') display = 'قيد الانتظار';
          if (status == 'processing') display = 'قيد المعالجة';
          if (status == 'assigned') display = 'تم الإسناد';
        }
        break;
      case 'in_progress':
      case 'accepted':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        if (label == null) {
          if (status == 'in_progress') display = 'قيد التنفيذ';
          if (status == 'accepted') display = 'تم القبول';
        }
        break;
      case 'offline':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        if (label == null) display = 'غير متصل';
        break;
      case 'error':
      case 'rejected':
      case 'inactive':
      case 'disputed':
      default:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        if (label == null) {
          if (status == 'error') display = 'خطأ';
          if (status == 'rejected') display = 'مرفوض';
          if (status == 'inactive') display = 'معطل';
          if (status == 'disputed') display = 'اعتراض';
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            display,
            style: AppTypography.cairo(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

