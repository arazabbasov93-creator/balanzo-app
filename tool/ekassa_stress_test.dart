// Stress-test e-kassa API from terminal.
// Usage: dart run tool/ekassa_stress_test.dart <fiscal_id_or_qr_url>
// Example: dart run tool/ekassa_stress_test.dart "https://monitoring.e-kassa.gov.az/?doc=YOUR_ID"

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const _baseUrl =
    'https://monitoring.e-kassa.gov.az/pks-monitoring/2.0.0/documents';

String? extractDocumentId(String qrValue) {
  final v = qrValue.trim();
  if (v.isEmpty) return null;
  try {
    final uri = Uri.parse(v);
    if (uri.host.contains('e-kassa.gov.az')) {
      final doc = uri.queryParameters['doc'];
      if (doc != null && doc.isNotEmpty) return doc;
    }
    if (uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty) return last;
    }
  } catch (_) {}
  if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v)) return v;
  return null;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/ekassa_stress_test.dart <fiscal_id_or_qr_url>');
    exit(1);
  }

  final raw = args.join(' ');
  final docId = extractDocumentId(raw) ?? raw;
  final url = '$_baseUrl/$docId';

  stdout.writeln('Input:  $raw');
  stdout.writeln('Doc ID: $docId');
  stdout.writeln('GET:    $url');
  stdout.writeln('---');

  final sw = Stopwatch()..start();
  final response = await http
      .get(Uri.parse(url), headers: {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 15));
  sw.stop();

  stdout.writeln('Status:  ${response.statusCode}');
  stdout.writeln('Type:    ${response.headers['content-type']}');
  stdout.writeln('Bytes:   ${response.bodyBytes.length}');
  stdout.writeln('Latency: ${sw.elapsedMilliseconds}ms');
  stdout.writeln('---');

  if (response.statusCode == 200) {
    try {
      final body = utf8.decode(response.bodyBytes);
      final json = jsonDecode(body);
      stdout.writeln('JSON preview (first 500 chars):');
      stdout.writeln(body.length > 500 ? '${body.substring(0, 500)}...' : body);
      if (json is Map) {
        stdout.writeln('Top-level keys: ${json.keys.toList()}');
      }
    } catch (e) {
      stdout.writeln('Body is not JSON: $e');
    }
  } else if (response.statusCode == 209) {
    stdout.writeln('209 = document not found (API returns JPEG placeholder, not JSON)');
  } else {
    stdout.writeln('Body preview: ${utf8.decode(response.bodyBytes, allowMalformed: true).substring(0, 200.clamp(0, response.bodyBytes.length))}');
  }
}
