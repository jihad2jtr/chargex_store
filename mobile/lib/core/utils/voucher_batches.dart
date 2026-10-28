import 'package:intl/intl.dart';

import '../../models/shipping_code_model.dart';

/// القسائم التي أُنشئت قبل أن يطبع الخادم معرّف دفعة تُجمع في سطر واحد
/// واضح بدل اختراع دفعات وهمية (كل يوم دفعة) توحي بأن كل قسيمة مجموعة.
const String legacyBatchKey = 'legacy';
const String legacyBatchTitle = 'قسائم قديمة — بلا معرّف دفعة';

/// دفعة قسائم: كل الأكواد التي أُنشئت في عملية توليد واحدة (تشترك بـ batchId).
class VoucherBatch {
  final String id;
  final String? note;
  final DateTime? createdAt;
  final List<ShippingCodeModel> codes;

  const VoucherBatch({
    required this.id,
    required this.codes,
    this.note,
    this.createdAt,
  });

  /// الدفعة التي أُنشئت قبل إضافة الدفعات (لا تحمل batchId من الخادم)
  bool get isLegacy => codes.every((c) => (c.batchId ?? '').isEmpty);

  int get total => codes.length;
  int get availableCount => codes.where((c) => !c.isUsed).length;
  int get usedCount => codes.where((c) => c.isUsed).length;

  bool get hasAvailable => availableCount > 0;

  /// قيمة القسيمة الواحدة (كل دفعة تتولّد بقيمة واحدة)
  double get unitAmount => codes.isEmpty ? 0.0 : codes.first.amount;

  /// إجمالي القيمة المتاح صرفها من الدفعة
  double get availableValue => codes
      .where((c) => !c.isUsed)
      .fold<double>(0.0, (sum, c) => sum + c.amount);

  /// عنوان الدفعة كما يظهر في الواجهة والتصدير
  String get title {
    if (isLegacy) return legacyBatchTitle;
    final String label = (note ?? '').trim();
    return label.isEmpty ? 'دفعة ${formatBatchDate(createdAt)}' : label;
  }

  /// معرّف يُعرض بدل المعرّف الخام: سطر القديمة بلا معرّف حقيقي
  String get displayId => isLegacy ? 'بدون معرّف' : id;
}

/// تاريخ الدفعة بصيغة مقروءة (تُستخدم في العنوان ونسخ القائمة)
String formatBatchDate(DateTime? date) {
  if (date == null) return 'غير محدد';
  return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
}

/// يجمع القسائم في دفعات: الأحدث أولاً، وداخل الدفعة الأحدث أولاً أيضاً.
/// القسائم القديمة التي لا يحملها الخادم `batchId` تُجمَّع في سطر واحد
/// (`legacyBatchKey`) حتى لا تبدو كل قسيمة كأنها دفعة مستقلة.
List<VoucherBatch> groupVoucherBatches(List<ShippingCodeModel> codes) {
  final Map<String, List<ShippingCodeModel>> groups =
      <String, List<ShippingCodeModel>>{};
  for (final ShippingCodeModel code in codes) {
    groups
        .putIfAbsent(_batchKeyOf(code), () => <ShippingCodeModel>[])
        .add(code);
  }

  final List<VoucherBatch> batches = groups.entries.map((
    MapEntry<String, List<ShippingCodeModel>> entry,
  ) {
    final List<ShippingCodeModel> sorted = entry.value
      ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));
    return VoucherBatch(
      id: entry.key,
      note: sorted
          .map((c) => c.batchNote)
          .firstWhere(
            (String? n) => (n ?? '').trim().isNotEmpty,
            orElse: () => null,
          ),
      // أقدم قسيمة هي زمن إنشاء الدفعة
      createdAt: sorted.isEmpty
          ? null
          : sorted.map((c) => c.createdAt).nonNulls.reduce(_earlierOf),
      codes: sorted,
    );
  }).toList();

  batches.sort((a, b) {
    final int byDate = _compareDates(b.createdAt, a.createdAt);
    if (byDate != 0) return byDate;
    // نفس اللحظة: معرّف أحدث حرفياً يظهر أولاً (B-20261028 قبل B-20261027)
    return b.id.compareTo(a.id);
  });
  return batches;
}

String _batchKeyOf(ShippingCodeModel code) {
  final String? id = code.batchId;
  if (id != null && id.isNotEmpty) return id;
  // لا تخمين لدفعات من التاريخ: كل ما بلا معرّف يذهب في سطر واحد
  return legacyBatchKey;
}

int _compareDates(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // بلا تاريخ يذهب للأسفل
  if (b == null) return -1;
  return a.compareTo(b);
}

DateTime _earlierOf(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

/// نسخة من الدفعة بقسائم مطابقة فقط — للتصدير الجزئي (المتاحة وحدها مثلاً)
VoucherBatch filterVoucherBatch(
  VoucherBatch batch,
  bool Function(ShippingCodeModel code) test,
) {
  return VoucherBatch(
    id: batch.id,
    note: batch.note,
    createdAt: batch.createdAt,
    codes: batch.codes.where(test).toList(growable: false),
  );
}

/// يجِد الدفعة بمعرّفها بعد إعادة الجلب (للعرض الفوري بعد التوليد)
VoucherBatch? findVoucherBatch(List<VoucherBatch> batches, String id) {
  if (id.isEmpty) return batches.isEmpty ? null : batches.first;
  for (final VoucherBatch batch in batches) {
    if (batch.id == id) return batch;
  }
  return null;
}

/// قائمة منسوخة جاهزة للّصق في محادثة أو جدول.
/// [codesOnly] تعطي الأكواد سطرًا سطرًا بدون أي زينة (لأغراض الاستيراد).
String voucherBatchListText(VoucherBatch batch, {bool codesOnly = false}) {
  if (codesOnly) {
    return batch.codes.map((c) => c.code).join('\n');
  }

  final StringBuffer buf = StringBuffer()
    ..writeln('🎫 قسائم شحن مسبق — JGO Store')
    ..writeln('الدفعة: ${batch.displayId}')
    ..writeln('التاريخ: ${formatBatchDate(batch.createdAt)}')
    ..writeln('قيمة القسيمة: \$${batch.unitAmount.toStringAsFixed(2)}')
    ..writeln(
      'العدد: ${batch.total} (متاحة ${batch.availableCount} / مستخدمة ${batch.usedCount})',
    )
    ..writeln('');

  int index = 1;
  for (final ShippingCodeModel code in batch.codes) {
    final String status = code.isUsed
        ? ' — مستخدمة${(code.usedByName ?? '').isEmpty ? '' : ': ${code.usedByName}'}'
        : '';
    buf.writeln(
      '${index++}. ${code.code}\$${code.amount.toStringAsFixed(2)}$status',
    );
  }
  return buf.toString().trimRight();
}

/// اسم ملف الـ PDF الخاص بالدفعة (أحرف إنجليزية فقط ليُفتح على أي نظام)
String voucherBatchFileName(VoucherBatch batch) {
  final String safeId = batch.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
  final String stamp = batch.createdAt == null
      ? DateFormat('yyyyMMdd').format(DateTime.now())
      : DateFormat('yyyyMMdd').format(batch.createdAt!.toLocal());
  return 'JGO-vouchers-$stamp-${safeId.isEmpty ? 'batch' : safeId}.pdf';
}
