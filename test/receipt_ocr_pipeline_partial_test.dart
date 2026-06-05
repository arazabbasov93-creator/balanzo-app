import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/receipt_ocr_pipeline.dart';

void main() {
  test('partial e-kassa parse is allowed (no throw)', () async {
    const ocr = '''
STORE: TEST MARKET
DATE: 2026-05-25
TOTAL: 20.09 AZN
FISCAL_ID: abc123
---
''';
    final receipt = await ReceiptOcrPipeline.parseOcrText(
      ocr,
      isGovernmentVerified: true,
    );
    expect(receipt.items, isEmpty);
    expect(receipt.total, closeTo(20.09, 0.01));
    expect(receipt.store, 'TEST MARKET');
    expect(ReceiptOcrPipeline.isParseLikelyIncomplete(receipt), isTrue);
  });
}
