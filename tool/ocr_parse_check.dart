import 'dart:io';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';

void main() {
  for (final e in [
    ('2vL7 fixture', 'tool/ocr_2vL7E.txt'),
    ('2vL7 live vision', 'tool/ocr_2vL7E_live.txt'),
    ('CaBC fixture', 'tool/ocr_CaBCpw.txt'),
    ('CaBC live vision', 'tool/ocr_CaBCpw_live.txt'),
  ]) {
    final raw = File(e.$2).readAsStringSync();
    final structured = OcrService.preprocessEkassaText(raw);
    final r = StructuredReceiptParser.tryParse(structured);
    stdout.writeln('=== ${e.$1} ===');
    stdout.writeln('items: ${r?.items.length ?? 0}, total: ${r?.total}');
    if (r != null) {
      for (final i in r.items) {
        stdout.writeln('  - ${i.name}: ${i.totalPrice}');
      }
    }
    stdout.writeln('');
  }
}
