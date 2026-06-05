import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';
import 'package:balanzo/utils/receipt_numbers.dart';

void main() {
  test('formatQuantity does not round 0.335 to 0.34', () {
    expect(ReceiptNumbers.formatQuantity(0.335), '0.335');
    expect(ReceiptNumbers.formatQuantity(0.225), '0.225');
  });

  test('E7av3 CHEESCAKE keeps qty 0.335 and total 4.69 from live OCR', () {
    final raw = File('tool/ocr_E7av3BYTEgRV.txt').readAsStringSync();
    final structured = OcrService.preprocessEkassaText(raw);
    expect(structured, contains('QTY: 0.335'));
    expect(structured, isNot(contains('QTY: 0.34')));

    final receipt = StructuredReceiptParser.tryParse(structured);
    expect(receipt, isNotNull);
    final cheesecake = receipt!.items.firstWhere(
      (i) => i.name.toUpperCase().contains('CHEESCAKE'),
    );
    expect(cheesecake.quantity, closeTo(0.335, 0.0001));
    expect(cheesecake.unitPrice, closeTo(14.0, 0.01));
    expect(cheesecake.totalPrice, closeTo(4.69, 0.01));
  });
}
