// Saves e-kassa receipt JPEG for inspection.
// Usage: dart run tool/ekassa_download.dart 7p4vW1ybWF2a

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final id = args.isEmpty ? '7p4vW1ybWF2a' : args.first;
  final url =
      'https://monitoring.e-kassa.gov.az/pks-monitoring/2.0.0/documents/$id';
  final r = await http.get(Uri.parse(url));
  final out = File('tool/ekassa_$id.jpg');
  await out.writeAsBytes(r.bodyBytes);
  stdout.writeln('${r.statusCode} ${r.headers['content-type']} ${r.bodyBytes.length} bytes → ${out.path}');
}
