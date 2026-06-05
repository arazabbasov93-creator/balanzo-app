import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';
import 'package:balanzo/services/receipt_ocr_pipeline.dart';

void main() {
  const cases = <({String id, int items, double total})>[
    (id: 'E7av3BYTEgRV', items: 2, total: 6.33),
    (id: '5SXTeKsQ8E9znnUWtzPjV7JNrHdNMpasQRcQc9Ubr9Wm', items: 2, total: 5.05),
    (id: 'CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp', items: 7, total: 62.38),
    (id: '2vL7E5bXRJ3Y', items: 4, total: 8.87),
    (id: '24AAdtSZ36Wr', items: 9, total: 30.42),
    (id: '7p4vW1ybWF2a', items: 2, total: 20.09),
  ];

  for (final c in cases) {
    test('${c.id} — ${c.items} items, ${c.total}', () {
      final path = 'tool/ocr_${c.id}.txt';
      expect(File(path).existsSync(), isTrue, reason: 'Run Vision OCR first: $path');
      final raw = File(path).readAsStringSync();
      final structured = OcrService.preprocessEkassaText(raw);
      final r = StructuredReceiptParser.tryParse(structured);
      expect(r, isNotNull);
      expect(r!.items.length, c.items);
      expect(r.total, closeTo(c.total, 0.1));
      final sum = r.items.fold(0.0, (s, i) => s + i.totalPrice);
      expect(sum, closeTo(c.total, 0.15));
      expect(ReceiptOcrPipeline.isParseLikelyIncomplete(r), isFalse);
    });
  }
}
