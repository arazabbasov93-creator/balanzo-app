import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/receipt_ocr_pipeline.dart';

void main() {
  group('ReceiptOcrPipeline', () {
    test('extracts fiscal ID from English and Azeri labels', () {
      expect(
        ReceiptOcrPipeline.extractFiscalId(
          'Fiscal ID: CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp',
        ),
        'CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp',
      );
      expect(
        ReceiptOcrPipeline.extractFiscalId('Fiskal İD: 7p4vW1ybWF2a'),
        '7p4vW1ybWF2a',
      );
    });

    test('photo and fiscal-ID paths parse e-kassa OCR identically', () async {
      final fromFile = OcrService.preprocessEkassaText(
        File('tool/ocr_2vL7E.txt').readAsStringSync(),
      );

      final receipt = await ReceiptOcrPipeline.parseOcrText(fromFile);
      expect(receipt.items.length, 4);
      expect(receipt.total, closeTo(8.87, 0.05));
      expect(receipt.isGovernmentVerified, isFalse);
    });

    test('government fetch sets verified flag and document ID', () async {
      const structured = '''
STORE: APTEK
DATE: 2026-05-25
TOTAL: 62.38 AZN
---
ITEM: MEKSUN | QTY: 1.00 | UNIT: 4.45 | TOTAL: 4.45
Fiscal ID: CaBCpwD37fLQ
''';
      final receipt = await ReceiptOcrPipeline.parseOcrText(
        structured,
        documentId: 'CaBCpwD37fLQ',
        isGovernmentVerified: true,
      );
      expect(receipt.isGovernmentVerified, isTrue);
      expect(receipt.documentId, 'CaBCpwD37fLQ');
    });

    test('extracts fiscal ID from raw OCR when saving photo scan', () async {
      const raw = '''
Object name: MƏHƏLLƏ MARKET
Product Quantity Price Total
ASSORTI TORT M.R
0.150 15.00 2.25
Total 8.87
Fiscal ID: 2vL7E5bXRJ3Y
''';
      final structured = OcrService.preprocessEkassaText(raw);
      final receipt = await ReceiptOcrPipeline.parseOcrText(structured);
      expect(receipt.documentId, '2vL7E5bXRJ3Y');
      expect(receipt.isGovernmentVerified, isFalse);
    });

    test('detects e-kassa OCR text', () {
      expect(
        ReceiptOcrPipeline.isEkassaOcrText(
          'STORE: TEST\nTOTAL: 10.00 AZN\n---\nITEM: A | QTY: 1 | UNIT: 10 | TOTAL: 10\nFiscal ID: abc',
        ),
        isTrue,
      );
      expect(
        ReceiptOcrPipeline.isEkassaOcrText(
          'STORE: CAFE\nITEM: Coffee | QTY: 1 | UNIT: 3 | TOTAL: 3',
        ),
        isFalse,
      );
    });
  });
}
