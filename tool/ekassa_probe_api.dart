import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const base = 'https://monitoring.e-kassa.gov.az/pks-monitoring/2.0.0';
const ids = ['2vL7E5bXRJ3Y', 'CaBCpwD37fLQ9rHpwLJ2aSRkLiTBjtAuYy6BGFKAi1fp'];

Future<void> probe(String path) async {
  final url = '$base$path';
  final r = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
  stdout.writeln('=== $path ===');
  stdout.writeln('HTTP ${r.statusCode} ${r.headers['content-type']}');
  final body = r.body;
  if (body.length > 2500) {
    stdout.writeln('${body.substring(0, 2500)}...');
  } else {
    stdout.writeln(body);
  }
  stdout.writeln('');
}

Future<void> main() async {
  for (final id in ids) {
    for (final suffix in ['/card', '/aiCategories', '']) {
      await probe('/documents/$id$suffix');
    }
  }
}
