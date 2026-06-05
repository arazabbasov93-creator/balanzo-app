import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';
import 'package:balanzo/services/receipt_ocr_pipeline.dart';

void main() {
  const cases = <({String id, int items, double total})>[
    (id: '24AAdtSZ36Wr4yuE9BoPFSMZe7ZPvoPS1mmYJANykPHm', items: 9, total: 30.42),
    (id: 'GaqmqkHKcYdeBoyBi3twrvMnBYNfp9vuZSRGGsAABvdD', items: 1, total: 1.50),
    (id: '3SqhhohgojRd5Sp2N8PenAsUnZPKdnQ8nxNBQbqvR2sE', items: 2, total: 4.70),
    (id: '9NCEbrxc83kmP5McGoLhzKPF9wQGcaJffEYMoBaw91vN', items: 1, total: 3.40),
    (id: 'FX6N23EBFrATEnRyRRCAdPsE4oDnW6v3456MKdpRf9Lg', items: 2, total: 1.90),
    (id: '4tTQLtJ6pL5N2iAxhgTPoMr5KtneSzkwmdzhevxthJQQ', items: 1, total: 3.40),
    (id: '7p4vW1ybWF2a6jgeD7WAAHXmaey6ZU6mAHriAaj746fS', items: 2, total: 20.09),
    (id: 'E7av3BYTEgRVLAQDkZ1y1LEyuJMBkaBs4d33tQXw7yAf', items: 2, total: 6.33),
  ];

  for (final c in cases) {
    test('${c.id} — ${c.items} items, ${c.total}', () {
      final path = 'tool/ocr_${c.id}.txt';
      expect(File(path).existsSync(), isTrue, reason: path);
      final raw = File(path).readAsStringSync();
      final structured = OcrService.preprocessEkassaText(raw);
      final r = StructuredReceiptParser.tryParse(structured);
      expect(r, isNotNull, reason: 'parse failed for ${c.id}');
      expect(r!.items.length, c.items, reason: r.items.map((i) => i.name).join(', '));
      expect(r.total, closeTo(c.total, 0.1));
      final sum = r.items.fold(0.0, (s, i) => s + i.totalPrice);
      expect(sum, closeTo(c.total, 0.15));
      expect(ReceiptOcrPipeline.isParseLikelyIncomplete(r), isFalse);
    });
  }
}
