import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

void main() {
  test('detailed item audit', () {
    const cases = {
      'E7av3BYTEgRV': [(4.69, 'CHEESCAKE'), (1.64, 'QOZ')],
      '5SXTeKsQ8E9znnUWtzPjV7JNrHdNMpasQRcQc9Ubr9Wm': [(5.02, 'Gunebaxan'), (0.03, 'Klok')],
      'CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp': [
        (8.59, 'OTIPAKS'),
        (4.64, 'OTRIVIN'),
        (4.45, 'MEKSUN'),
        (21.40, 'RODINIR'),
        (0.10, 'KLOK'),
        (23.20, 'PULMOTEN'),
        (0.00, 'hediyy'),
      ],
      '2vL7E5bXRJ3Y': [(2.25, 'TORT'), (2.80, 'QOZLU'), (3.78, 'CHEESCAKE'), (0.04, 'PAKET')],
      '24AAdtSZ36Wr': [
        (2.55, 'YUMURTA'),
        (2.90, 'XAMA'),
        (3.74, 'PENDIR'),
        (3.95, 'VAFLI FINDIQ'),
        (3.38, 'TRUBKA'),
        (1.51, 'RUPER'),
        (10.00, 'CHEESCAKE'),
        (2.30, 'COCA'),
        (0.08, 'PAKET'),
      ],
      '7p4vW1ybWF2a': [(19.9, 'Dast'), (0.10, 'Poşet')],
    };

    for (final entry in cases.entries) {
      final path = 'tool/ocr_${entry.key}.txt';
      final raw = File(path).readAsStringSync();
      final structured = OcrService.preprocessEkassaText(raw);
      final r = StructuredReceiptParser.tryParse(structured);
      // ignore: avoid_print
      print('\n=== ${entry.key} ===');
      // ignore: avoid_print
      print('items: ${r?.items.length} total: ${r?.total} sum: ${r?.items.fold(0.0, (s, i) => s + i.totalPrice)}');
      for (final i in r?.items ?? []) {
        // ignore: avoid_print
        print('  ${i.totalPrice.toStringAsFixed(2)} | q=${i.quantity} u=${i.unitPrice} | ${i.name}');
      }
      for (final exp in entry.value) {
        final match = r?.items.where((i) =>
            (i.totalPrice - exp.$1).abs() < 0.05 &&
            i.name.toUpperCase().contains(exp.$2.toUpperCase()));
        expect(match?.isNotEmpty ?? false, isTrue,
            reason: 'Missing ${exp.$2} @ ${exp.$1} in ${entry.key}');
      }
    }
  });
}
