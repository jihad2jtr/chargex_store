// تجميع قسائم الشحن المسبق في دفعات + تصدير كل مجموعة (قائمة منسوخة / PDF)
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/utils/voucher_batches.dart';
import 'package:layan_chargex/core/utils/voucher_pdf.dart';
import 'package:layan_chargex/models/shipping_code_model.dart';

ShippingCodeModel _code({
  required String code,
  double amount = 10,
  String? batchId,
  String? batchNote,
  bool isUsed = false,
  String? usedByName,
  DateTime? createdAt,
}) {
  return ShippingCodeModel(
    id: code,
    code: code,
    amount: amount,
    isUsed: isUsed,
    usedByName: usedByName,
    batchId: batchId,
    batchNote: batchNote,
    createdAt: createdAt ?? DateTime(2026, 10, 28, 9, 30),
  );
}

void main() {
  group('groupVoucherBatches', () {
    test('groups codes of one generation call into a single batch', () {
      final List<VoucherBatch> batches =
          groupVoucherBatches(<ShippingCodeModel>[
            _code(code: 'CHG-AAAA-1111', batchId: 'B-20261028-1111'),
            _code(code: 'CHG-AAAA-2222', batchId: 'B-20261028-1111'),
            _code(
              code: 'CHG-BBBB-3333',
              batchId: 'B-20261027-2222',
              createdAt: DateTime(2026, 10, 27, 9, 30),
            ),
          ]);

      expect(batches, hasLength(2));
      expect(batches.first.codes, hasLength(2));
      expect(batches.last.codes, hasLength(1));
    });

    test('newest batch comes first', () {
      final List<VoucherBatch> batches =
          groupVoucherBatches(<ShippingCodeModel>[
            _code(
              code: 'OLD',
              batchId: 'B-1',
              createdAt: DateTime(2026, 10, 1, 8),
            ),
            _code(
              code: 'NEW',
              batchId: 'B-2',
              createdAt: DateTime(2026, 10, 28, 8),
            ),
          ]);

      expect(batches.first.id, 'B-2');
      expect(batches.last.id, 'B-1');
    });

    test(
      'legacy codes without batchId merge into one clearly labelled batch',
      () {
        final List<VoucherBatch> batches =
            groupVoucherBatches(<ShippingCodeModel>[
              _code(code: 'L1', createdAt: DateTime(2026, 10, 28, 1, 0)),
              _code(code: 'L2', createdAt: DateTime(2026, 10, 28, 23, 0)),
              _code(code: 'L3', createdAt: DateTime(2026, 10, 20, 12, 0)),
            ]);

        // سطر واحد لكل ما بلا معرّف: لا نُخترع دفعات من التاريخ
        expect(batches, hasLength(1));
        expect(batches.first.id, legacyBatchKey);
        expect(batches.first.isLegacy, isTrue);
        expect(batches.first.title, legacyBatchTitle);
        expect(batches.first.displayId, 'بدون معرّف');
        expect(batches.first.codes, hasLength(3));
        expect(
          batches.first.codes.map((ShippingCodeModel c) => c.code),
          <String>['L2', 'L1', 'L3'],
        );
      },
    );

    test('a real batch and the legacy line stay separate', () {
      final List<VoucherBatch> batches =
          groupVoucherBatches(<ShippingCodeModel>[
            _code(code: 'N1', batchId: 'B-20261028-1111'),
            _code(code: 'N2', batchId: 'B-20261028-1111'),
            _code(code: 'L1', createdAt: DateTime(2026, 10, 12, 12, 0)),
            _code(code: 'L2', createdAt: DateTime(2026, 10, 13, 12, 0)),
          ]);

      expect(batches, hasLength(2));
      expect(batches.first.id, 'B-20261028-1111');
      expect(batches.first.isLegacy, isFalse);
      expect(batches.last.id, legacyBatchKey);
      expect(batches.last.codes, hasLength(2));
    });

    test('batch carries the admin note, otherwise the date labels it', () {
      final List<VoucherBatch> withNote = groupVoucherBatches(
        <ShippingCodeModel>[
          _code(code: 'C1', batchId: 'B-9', batchNote: 'قسائم منصة الأسبوع 44'),
        ],
      );
      expect(withNote.first.title, 'قسائم منصة الأسبوع 44');

      final List<VoucherBatch> withoutNote = groupVoucherBatches(
        <ShippingCodeModel>[_code(code: 'C2', batchId: 'B-8')],
      );
      expect(withoutNote.first.title, startsWith('دفعة 2026-10-28'));
    });

    test('counts and values stay separated per batch', () {
      final VoucherBatch batch = groupVoucherBatches(<ShippingCodeModel>[
        _code(code: 'A1', amount: 20, batchId: 'B-1'),
        _code(code: 'A2', amount: 20, batchId: 'B-1', isUsed: true),
        _code(code: 'A3', amount: 20, batchId: 'B-1', isUsed: true),
      ]).single;

      expect(batch.total, 3);
      expect(batch.availableCount, 1);
      expect(batch.usedCount, 2);
      expect(batch.unitAmount, 20);
      expect(batch.availableValue, 20);
      expect(batch.hasAvailable, isTrue);
    });
  });

  group('voucherBatchListText', () {
    late VoucherBatch batch;

    setUp(() {
      batch = groupVoucherBatches(<ShippingCodeModel>[
        _code(
          code: 'CHG-1111-AAAA',
          amount: 15,
          batchId: 'B-20261028-7A2B',
          createdAt: DateTime(2026, 10, 28, 9, 31),
        ),
        _code(
          code: 'CHG-2222-BBBB',
          amount: 15,
          batchId: 'B-20261028-7A2B',
          isUsed: true,
          usedByName: 'وسام',
          createdAt: DateTime(2026, 10, 28, 9, 30),
        ),
      ]).single;
    });

    test('the copied list has a header and one numbered line per voucher', () {
      final String text = voucherBatchListText(batch);
      final List<String> lines = text.split('\n');

      expect(lines.first, contains('قسائم شحن مسبق'));
      expect(text, contains('الدفعة: B-20261028-7A2B'));
      expect(text, contains('قيمة القسيمة: \$15.00'));
      expect(text, contains('العدد: 2 (متاحة 1 / مستخدمة 1)'));
      expect(text, contains('1. CHG-1111-AAAA\$15.00'));
      expect(text, contains('2. CHG-2222-BBBB\$15.00 — مستخدمة: وسام'));
      expect(
        lines.where((String l) => l.startsWith('1.') || l.startsWith('2.')),
        hasLength(2),
      );
    });

    test('codesOnly pastes bare codes, one per line', () {
      expect(
        voucherBatchListText(batch, codesOnly: true),
        'CHG-1111-AAAA\nCHG-2222-BBBB',
      );
    });
  });

  group('export helpers', () {
    final VoucherBatch batch = groupVoucherBatches(<ShippingCodeModel>[
      _code(code: 'CHG-A', amount: 5, batchId: 'B-20261028-7A2B'),
      _code(code: 'CHG-B', amount: 5, batchId: 'B-20261028-7A2B', isUsed: true),
    ]).single;

    test('filterVoucherBatch keeps only available vouchers', () {
      final VoucherBatch available = filterVoucherBatch(
        batch,
        (ShippingCodeModel c) => !c.isUsed,
      );

      expect(available.codes, hasLength(1));
      expect(available.id, batch.id);
      expect(available.createdAt, batch.createdAt);
      // الدفعة الأصلية لا تتغير
      expect(batch.codes, hasLength(2));
    });

    test('findVoucherBatch locates the freshly generated batch', () {
      final List<VoucherBatch> batches = <VoucherBatch>[batch];

      expect(findVoucherBatch(batches, batch.id), same(batch));
      expect(findVoucherBatch(batches, ''), same(batch));
      expect(findVoucherBatch(batches, 'B-unknown'), isNull);
    });

    test('pdf file name is ascii-safe and ends with .pdf', () {
      final String name = voucherBatchFileName(batch);

      expect(name, matches(RegExp(r'^[A-Za-z0-9._-]+\.pdf$')));
      expect(name, contains('20261028'));
    });

    test('the pdf bytes are a real document with content', () async {
      final Uint8List bytes = await buildVoucherBatchPdfBytes(batch);

      expect(bytes.length, greaterThan(800));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'الملف الناتج ليس PDF صالحاً',
      );
    });

    test('a batch with many vouchers still produces a pdf', () async {
      final VoucherBatch big = groupVoucherBatches(
        List<ShippingCodeModel>.generate(
          50,
          (int i) => _code(code: 'CHG-$i', amount: 2, batchId: 'B-BIG'),
        ),
      ).single;

      final Uint8List bytes = await buildVoucherBatchPdfBytes(big);

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
