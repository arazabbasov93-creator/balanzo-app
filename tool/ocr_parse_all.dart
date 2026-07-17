import 'dart:io';
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';
import 'package:balanzo/services/receipt_ocr_pipeline.dart';

void main() {
  final files = Directory('tool')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('ocr_') && f.path.endsWith('.txt'))
      .where((f) => !f.path.contains('_live'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final raw = f.readAsStringSync();
    final structured = OcrService.preprocessEkassaText(raw);
    final r = StructuredReceiptParser.tryParse(structured);
    final sum = r?.items.fold(0.0, (s, i) => s + i.totalPrice) ?? 0;
    final footer = _footerTotal(raw);
    final vatN = _vatCount(raw);

    stdout.writeln('=' * 70);
    stdout.writeln(f.path);
    stdout.writeln('store: ${r?.store} | items: ${r?.items.length ?? 0} (vat markers: $vatN)');
    stdout.writeln('parsed total: ${r?.total.toStringAsFixed(2)} | sum: ${sum.toStringAsFixed(2)} | footer: $footer');
    stdout.writeln('incomplete: ${r != null && ReceiptOcrPipeline.isParseLikelyIncomplete(r)}');
    if (r != null) {
      for (final i in r.items) {
        stdout.writeln('  ${i.totalPrice.toStringAsFixed(2)} | ${i.name}');
      }
    } else {
      stdout.writeln('  NO PARSE');
    }
    stdout.writeln('');
  }
}

int _vatCount(String raw) {
  var n = 0;
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (RegExp(r'^\*(?:VAT|ƏDV)', caseSensitive: false).hasMatch(t) &&
        !t.contains('=')) {
      n++;
    }
  }
  return n;
}

double? _footerTotal(String raw) {
  final lines = raw.split('\n').map((l) => l.trim()).toList();
  for (int i = 0; i < lines.length; i++) {
    if (RegExp(r'^Total\.?\s*$', caseSensitive: false).hasMatch(lines[i])) {
      if (i > 0) {
        final v = double.tryParse(lines[i - 1].replaceAll(',', '.'));
        if (v != null && v > 0.5) return v;
      }
    }
    final m = RegExp(r'^Total\.?\s+([\d.,]+)', caseSensitive: false).firstMatch(lines[i]);
    if (m != null) {
      return double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }
  }
  return null;
}
