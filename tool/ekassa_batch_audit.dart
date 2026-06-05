// Batch audit: download e-kassa JPEGs, OCR (saved vision text or live swift), parse, report.
// Usage: dart run tool/ekassa_batch_audit.dart [--ocr]
//   --ocr  run macos vision when tool/ocr_<id>.txt is missing

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:balanzo/services/ocr_service.dart';
import 'package:balanzo/services/structured_receipt_parser.dart';
import 'package:balanzo/services/receipt_ocr_pipeline.dart';

const _base = 'https://monitoring.e-kassa.gov.az/pks-monitoring/2.0.0/documents';

/// Verified expectations (items, total) from government JPEGs / prior audits.
const expected = <String, ({int items, double total})>{
  '24AAdtSZ36Wr4yuE9BoPFSMZe7ZPvoPS1mmYJANykPHm': (items: 9, total: 30.42),
  '24AAdtSZ36Wr': (items: 9, total: 30.42),
  'E7av3BYTEgRVLAQDkZ1y1LEyuJMBkaBs4d33tQXw7yAf': (items: 2, total: 6.33),
  'E7av3BYTEgRV': (items: 2, total: 6.33),
  '5SXTeKsQ8E9znnUWtzPjV7JNrHdNMpasQRcQc9Ubr9Wm': (items: 2, total: 5.05),
  'CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp': (items: 7, total: 62.38),
  '2vL7E5bXRJ3Y': (items: 4, total: 8.87),
  '7p4vW1ybWF2a6jgeD7WAAHXmaey6ZU6mAHriAaj746fS': (items: 2, total: 20.09),
  '7p4vW1ybWF2a': (items: 2, total: 20.09),
};

/// Full fiscal IDs (skip obvious short duplicates when full form listed).
final ids = [
  '24AAdtSZ36Wr4yuE9BoPFSMZe7ZPvoPS1mmYJANykPHm',
  'GaqmqkHKcYdeBoyBi3twrvMnBYNfp9vuZSRGGsAABvdD',
  '3SqhhohgojRd5Sp2N8PenAsUnZPKdnQ8nxNBQbqvR2sE',
  '9NCEbrxc83kmP5McGoLhzKPF9wQGcaJffEYMoBaw91vN',
  'FX6N23EBFrATEnRyRRCAdPsE4oDnW6v3456MKdpRf9Lg',
  '4tTQLtJ6pL5N2iAxhgTPoMr5KtneSzkwmdzhevxthJQQ',
  '7p4vW1ybWF2a6jgeD7WAAHXmaey6ZU6mAHriAaj746fS',
  '5SXTeKsQ8E9znnUWtzPjV7JNrHdNMpasQRcQc9Ubr9Wm',
  '2vL7E5bXRJ3Y',
  'CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp',
  'E7av3BYTEgRVLAQDkZ1y1LEyuJMBkaBs4d33tQXw7yAf',
];

Future<void> main(List<String> args) async {
  final runOcr = args.contains('--ocr');
  final report = <Map<String, dynamic>>[];

  for (final id in ids) {
    final row = <String, dynamic>{'id': id};
    try {
      final r = await http
          .get(Uri.parse('$_base/$id'))
          .timeout(const Duration(seconds: 25));
      row['http'] = r.statusCode;
      row['bytes'] = r.bodyBytes.length;
      if (r.statusCode != 200) {
        row['error'] = 'HTTP ${r.statusCode}';
        report.add(row);
        continue;
      }
      final jpg = File('tool/ekassa_$id.jpg');
      await jpg.writeAsBytes(r.bodyBytes);

      final card = await http
          .get(Uri.parse('$_base/$id/card'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      row['card_http'] = card.statusCode;
      if (card.statusCode == 200) {
        try {
          final j = jsonDecode(card.body) as Map<String, dynamic>;
          row['card_total'] = j['total'] ?? j['amount'] ?? j['sum'];
          row['card_items'] = (j['items'] as List?)?.length;
        } catch (_) {
          row['card_note'] = 'non-json';
        }
      }

      var ocrPath = _resolveOcrPath(id);
      if (ocrPath == null && runOcr) {
        ocrPath = 'tool/ocr_$id.txt';
        final proc = await Process.run(
          'swift',
          ['tool/macos_vision_ocr.swift', jpg.path],
          workingDirectory: Directory.current.path,
        );
        if (proc.exitCode == 0) {
          await File(ocrPath).writeAsString(proc.stdout as String);
          row['ocr'] = 'live_vision';
        } else {
          row['ocr'] = 'vision_failed: ${proc.stderr}';
          report.add(row);
          continue;
        }
      } else if (ocrPath == null) {
        row['ocr'] =
            'missing — dart run tool/ekassa_batch_audit.dart --ocr';
        report.add(row);
        continue;
      }

      row['ocr_file'] = ocrPath;
      final raw = File(ocrPath).readAsStringSync();
      final structured = OcrService.preprocessEkassaText(raw);
      final parsed = StructuredReceiptParser.tryParse(structured);
      final sum = parsed?.items.fold(0.0, (s, i) => s + i.totalPrice) ?? 0;

      row['store_ocr'] = parsed?.store ?? _grepStore(raw);
      row['items'] = parsed?.items.length ?? 0;
      row['total'] = parsed?.total ?? 0;
      row['items_sum'] = sum;
      row['incomplete'] = parsed != null &&
          ReceiptOcrPipeline.isParseLikelyIncomplete(parsed);

      final exp = expected[id] ??
          expected.entries
              .where((e) => id.startsWith(e.key) || e.key.startsWith(id))
              .map((e) => e.value)
              .firstOrNull;
      row['ocr_vat_lines'] = _countVatMarkers(raw);
      row['ocr_footer_total'] = _grepFooterTotal(raw);

      if (exp != null) {
        row['exp_items'] = exp.items;
        row['exp_total'] = exp.total;
        row['items_ok'] = row['items'] == exp.items;
        row['total_ok'] = ((row['total'] as num) - exp.total).abs() < 0.1;
        row['match'] = row['items_ok'] == true && row['total_ok'] == true;
      } else if (row['ocr_footer_total'] != null) {
        row['exp_total'] = row['ocr_footer_total'];
        row['total_ok'] =
            ((row['total'] as num) - (row['ocr_footer_total'] as num)).abs() <
                0.1;
        row['exp_items'] = row['ocr_vat_lines'];
        row['items_ok'] = row['items'] == row['ocr_vat_lines'];
        row['match'] = row['items_ok'] == true && row['total_ok'] == true;
      }

      if (parsed != null && row['match'] != true) {
        row['parsed_items'] = parsed.items
            .map((i) => '${i.name} | ${i.totalPrice.toStringAsFixed(2)}')
            .toList();
      }
    } catch (e) {
      row['error'] = e.toString();
    }
    report.add(row);
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

String? _resolveOcrPath(String id) {
  final candidates = [
    'tool/ocr_$id.txt',
    if (id.length > 20) 'tool/ocr_${id.substring(0, 12)}.txt',
    if (id.startsWith('24AAdt')) 'tool/ocr_24AAdtSZ36Wr.txt',
    if (id.startsWith('7p4vW1ybWF2a6')) 'tool/ocr_7p4vW1ybWF2a.txt',
    if (id.startsWith('E7av3BYTEgRVLA')) 'tool/ocr_E7av3BYTEgRV.txt',
  ];
  for (final p in candidates) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

String? _grepStore(String raw) {
  for (final line in raw.split('\n')) {
    final m =
        RegExp(r'Object name:\s*(.+)', caseSensitive: false).firstMatch(line);
    if (m != null) return m.group(1)!.trim();
  }
  return null;
}

int _countVatMarkers(String raw) {
  var n = 0;
  for (final line in raw.split('\n')) {
    if (RegExp(r'^\*?\s*(?:VAT|ƏDV)', caseSensitive: false)
        .hasMatch(line.trim())) {
      if (!line.contains('=')) n++;
    }
  }
  return n;
}

double? _grepFooterTotal(String raw) {
  final lines = raw.split('\n').map((l) => l.trim()).toList();
  for (int i = 0; i < lines.length; i++) {
    if (RegExp(r'^Total\.?\s*$', caseSensitive: false).hasMatch(lines[i])) {
      if (i > 0) {
        final v = double.tryParse(lines[i - 1].replaceAll(',', '.'));
        if (v != null && v > 0) return v;
      }
      if (i + 1 < lines.length) {
        final v = double.tryParse(lines[i + 1].replaceAll(',', '.'));
        if (v != null && v > 0) return v;
      }
    }
  }
  return null;
}
