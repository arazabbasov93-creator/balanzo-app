import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/receipt.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

Receipt? _parse(String raw) {
  final structured = OcrService.preprocessEkassaText(raw);
  return StructuredReceiptParser.tryParse(structured);
}

Receipt? _parseFile(String path) => _parse(File(path).readAsStringSync());

void main() {
  group('row-order English e-kassa (iPhone OCR layout)', () {
    test('CaBCpw pharmacy — 7 items, 62.38', () {
      final receipt = _parseFile('tool/ocr_CaBCpw.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 7);
      expect(receipt.total, closeTo(62.38, 0.05));
    });

    test('2vL7E market — 4 items, 8.87', () {
      final receipt = _parseFile('tool/ocr_2vL7E.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 4);
      expect(receipt.total, closeTo(8.87, 0.05));
    });

    test('2vL7E missing QOZLU row recovers from orphan price', () {
      const raw = '''
Object name: MƏHƏLLƏ MARKET
25.05.2026
Quantity Price Total
Product
ASSORTI TORT M.R
0.150 15.00 2.25
*VAT-exempt
ASSORTI CHEESCAKE M.R (kg)
0.270 14.00 3.78
*VAT-exempt
MEHELLE PAKET
1
0.04 0.04
*VAT: 18%
ASSORTI QOZLU M.R
0.280 10.00 2.80
*VAT: 18%
8.87
Total
Fiscal ID: 2vL7E5bXRJ3Y
''';
      final receipt = _parse(raw);
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 4);
      expect(receipt.total, closeTo(8.87, 0.05));
      expect(
        receipt.items.any((i) => i.name.toUpperCase().contains('QOZLU')),
        isTrue,
      );
    });
  });

  group('Receipt.withCorrectedTotals', () {
    test('keeps header total when items incomplete (government verified)', () {
      const receipt = Receipt(
        items: [
          ReceiptItem(name: 'A', quantity: 1, unitPrice: 2.25, totalPrice: 2.25),
          ReceiptItem(name: 'B', quantity: 1, unitPrice: 3.78, totalPrice: 3.78),
        ],
        subtotal: 6.03,
        vat: 0,
        total: 8.87,
        isGovernmentVerified: true,
      );
      final fixed = receipt.withCorrectedTotals();
      expect(fixed.total, closeTo(8.87, 0.01));
    });

    test('keeps header total when fiscal ID present (photo scan)', () {
      const receipt = Receipt(
        items: [
          ReceiptItem(name: 'A', quantity: 1, unitPrice: 2.25, totalPrice: 2.25),
          ReceiptItem(name: 'B', quantity: 1, unitPrice: 3.78, totalPrice: 3.78),
        ],
        subtotal: 6.03,
        vat: 0,
        total: 8.87,
        documentId: '2vL7E5bXRJ3Y',
      );
      final fixed = receipt.withCorrectedTotals();
      expect(fixed.total, closeTo(8.87, 0.01));
    });
  });
}
