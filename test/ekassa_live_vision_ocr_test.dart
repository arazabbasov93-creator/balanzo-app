import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/receipt.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

Receipt? _parseFile(String path) {
  final structured = OcrService.preprocessEkassaText(
    File(path).readAsStringSync(),
  );
  return StructuredReceiptParser.tryParse(structured);
}

void main() {
  group('live Vision OCR from government JPEG', () {
    test('E7av3 market — 2 items, 6.33', () {
      final receipt = _parseFile('tool/ocr_E7av3BYTEgRV.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
      expect(receipt.total, closeTo(6.33, 0.05));
    });

    test('5SXTe store — 2 items, 5.05', () {
      final receipt = _parseFile('tool/ocr_5SXTeKsQ8E9znnUWtzPjV7JNrHdNMpasQRcQc9Ubr9Wm.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
      expect(receipt.total, closeTo(5.05, 0.05));
      final sum = receipt.items.fold(0.0, (s, i) => s + i.totalPrice);
      expect(sum, closeTo(5.05, 0.05));
    });

    test('CaBCpw pharmacy — 7 items, 62.38', () {
      final receipt = _parseFile('tool/ocr_CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 7);
      expect(receipt.total, closeTo(62.38, 0.05));
    });

    test('2vL7E market — 4 items, 8.87', () {
      final receipt = _parseFile('tool/ocr_2vL7E5bXRJ3Y.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 4);
      expect(receipt.total, closeTo(8.87, 0.05));
    });

    test('24AAdt market — 9 items, 30.42', () {
      final receipt = _parseFile('tool/ocr_24AAdtSZ36Wr.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 9);
      expect(receipt.total, closeTo(30.42, 0.1));
      final sum = receipt.items.fold(0.0, (s, i) => s + i.totalPrice);
      expect(sum, closeTo(30.42, 0.15));
    });

    test('7p4v QARIŞIQ MALLAR — 2 items, 20.09', () {
      final receipt = _parseFile('tool/ocr_7p4vW1ybWF2a.txt');
      expect(receipt, isNotNull);
      expect(receipt!.items.length, 2);
      expect(receipt.total, closeTo(20.09, 0.1));
    });
  });
}
