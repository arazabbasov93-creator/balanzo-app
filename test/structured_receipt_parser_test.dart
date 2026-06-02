import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

void main() {
  group('StructuredReceiptParser', () {
    test('parses ITEM lines from e-kassa structured output', () {
      const text = '''
STORE: QARIŞIQ MALLAR MAĞAZASI
DATE: 2026-05-30
TOTAL: 20.09 AZN
---
ITEM: Dəst (ANTHRACITE) | QTY: 1.00 | UNIT: 19.99 | TOTAL: 19.99
ITEM: Poşet S | QTY: 1.00 | UNIT: 0.10 | TOTAL: 0.10
''';

      final receipt = StructuredReceiptParser.tryParse(text);
      expect(receipt, isNotNull);
      expect(receipt!.store, 'QARIŞIQ MALLAR MAĞAZASI');
      expect(receipt.items.length, 2);
      expect(receipt.total, closeTo(20.09, 0.01));
      expect(receipt.items.first.name, contains('Dəst'));
    });
  });
}
