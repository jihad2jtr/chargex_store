import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'voucher_batches.dart';

/// يبني ملف PDF يحوي قسائم الدفعة (أكواد + قيم + حالة).
///
/// ملاحظة: النص داخل الملف لاتيني وأرقام، لأن خط Helvetica المدمج في حزمة pdf
/// لا يحمل حروفاً عربية. الأكواد نفسها لاتينية، والعناوين مختصرة (Code / Value
/// / Status) وواضحة لأي مستلم أو مطبوعة تُسلَّم للعميل.
Future<Uint8List> buildVoucherBatchPdfBytes(VoucherBatch batch) async {
  final pw.Document doc = pw.Document();

  final List<List<String>> rows = <List<String>>[
    for (int i = 0; i < batch.codes.length; i++)
      <String>[
        '${i + 1}',
        batch.codes[i].code,
        '\$${batch.codes[i].amount.toStringAsFixed(2)}',
        batch.codes[i].isUsed ? 'USED' : 'ACTIVE',
      ],
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 40),
      header: (pw.Context context) => _buildHeader(batch),
      footer: (pw.Context context) => _buildFooter(batch, context),
      build: (pw.Context context) => <pw.Widget>[
        pw.TableHelper.fromTextArray(
          headers: const <String>['#', 'Code', 'Value (USD)', 'Status'],
          data: rows,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignments: <int, pw.Alignment>{
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(34),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(90),
            3: pw.FixedColumnWidth(80),
          },
          border: pw.TableBorder.symmetric(
            inside: const pw.BorderSide(width: 0.5, color: PdfColors.grey400),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _buildHeader(VoucherBatch batch) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'JGO STORE',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Prepaid Recharge Vouchers',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Batch: ${batch.id}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey400, thickness: 0.8),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 18,
          runSpacing: 4,
          children: <pw.Widget>[
            _summaryItem('Generated', formatBatchDate(batch.createdAt)),
            _summaryItem('Vouchers', '${batch.total}'),
            _summaryItem('Available', '${batch.availableCount}'),
            _summaryItem('Used', '${batch.usedCount}'),
            _summaryItem(
              'Unit value',
              '\$${batch.unitAmount.toStringAsFixed(2)}',
            ),
            _summaryItem(
              'Total value',
              '\$${batch.availableValue.toStringAsFixed(2)}',
            ),
          ],
        ),
        pw.SizedBox(height: 10),
      ],
    ),
  );
}

pw.Widget _summaryItem(String label, String value) {
  return pw.Row(
    children: <pw.Widget>[
      pw.Text(
        '$label: ',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _buildFooter(VoucherBatch batch, pw.Context context) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          'Redeem inside the app: Wallet > Redeem Code',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}

/// يكتب الـ PDF في مجلد مؤقت ويعيد مساره (نستخدمه للمشاركة أو الحفظ).
Future<String> writeVoucherBatchPdfFile(VoucherBatch batch) async {
  final Uint8List bytes = await buildVoucherBatchPdfBytes(batch);
  final Directory dir = await getTemporaryDirectory();
  final File file = File(
    '${dir.path}${Platform.pathSeparator}${voucherBatchFileName(batch)}',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// يصدّر الدفعة كملف PDF عبر مشاركة النظام (حفظ في الملفات / واتساب / …).
Future<String> shareVoucherBatchPdf(VoucherBatch batch) async {
  final String path = await writeVoucherBatchPdfFile(batch);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(path)],
      fileNameOverrides: <String>[voucherBatchFileName(batch)],
      subject: 'JGO vouchers - ${batch.id}',
    ),
  );
  return path;
}
