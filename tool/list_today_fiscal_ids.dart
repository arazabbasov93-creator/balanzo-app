// Lists fiscal IDs for receipts scanned today (created_at), Baku time UTC+4.
//
// Usage:
//   dart run tool/list_today_fiscal_ids.dart
//
// With auth (required for RLS — use your Balanzo login):
//   SUPABASE_TEST_EMAIL=you@example.com SUPABASE_TEST_PASSWORD=secret \
//     dart run tool/list_today_fiscal_ids.dart
//
// Or with service role:
//   SUPABASE_SERVICE_ROLE_KEY=... dart run tool/list_today_fiscal_ids.dart

import 'dart:convert';
import 'dart:io';

const _url = 'https://mwookghnlhmseayeyycj.supabase.co';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13b29rZ2hubGhtc2VheWV5eWNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzMyMjEsImV4cCI6MjA5NDk0OTIyMX0.lTcGXJ2u5V_jJTzwDQFagCmLE7cRrrRcCPpuAM6E-d8';

DateTime _bakuNow() => DateTime.now().toUtc().add(const Duration(hours: 4));

String _isoUtc(DateTime bakuLocal) =>
    bakuLocal.subtract(const Duration(hours: 4)).toIso8601String();

Future<String?> _signInJwt() async {
  final email = Platform.environment['SUPABASE_TEST_EMAIL'];
  final password = Platform.environment['SUPABASE_TEST_PASSWORD'];
  if (email == null || password == null) return null;

  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$_url/auth/v1/token?grant_type=password'));
    req.headers.set('apikey', _anonKey);
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode({'email': email, 'password': password}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      stderr.writeln('Sign-in failed (${res.statusCode}): $body');
      exit(1);
    }
    return (jsonDecode(body) as Map)['access_token'] as String?;
  } finally {
    client.close();
  }
}

Future<List<Map<String, dynamic>>> _fetch(
  String key,
  String from,
  String to,
) async {
  final uri = Uri.parse('$_url/rest/v1/receipts').replace(
    queryParameters: {
      'select': 'fiscal_id,created_at,store_name,purchase_date,user_id',
      'created_at': 'gte.$from',
      'order': 'created_at.asc',
      'limit': '500',
    },
  );
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set('apikey', _anonKey);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Accept', 'application/json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      stderr.writeln('HTTP ${res.statusCode}: $body');
      exit(1);
    }
    final list = jsonDecode(body) as List;
    final start = DateTime.parse(from).toUtc();
    final end = DateTime.parse(to).toUtc();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).where((r) {
      final created = DateTime.parse(r['created_at'] as String).toUtc();
      return !created.isBefore(start) && created.isBefore(end);
    }).toList();
  } finally {
    client.close();
  }
}

Future<void> main() async {
  final baku = _bakuNow();
  final dayStart = DateTime(baku.year, baku.month, baku.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final from = _isoUtc(dayStart);
  final to = _isoUtc(dayEnd);

  stdout.writeln('Scan date window (Baku): ${dayStart.toIso8601String().split('T').first}');
  stdout.writeln('Filter: created_at (scan/save time), NOT purchase_date');
  stdout.writeln('');

  final jwt = await _signInJwt();
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ?? jwt ?? _anonKey;
  if (jwt != null) {
    stdout.writeln('Using signed-in user session.');
  } else if (Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] != null) {
    stdout.writeln('Using service role key.');
  } else {
    stdout.writeln('No auth — results may be empty due to RLS.');
  }
  stdout.writeln('');

  final rows = await _fetch(key, from, to);

  if (rows.isEmpty) {
    stdout.writeln('No receipts scanned today.');
    exit(0);
  }

  final withFiscal = rows
      .where((r) => (r['fiscal_id'] as String?)?.trim().isNotEmpty == true)
      .toList();

  if (withFiscal.isEmpty) {
    stdout.writeln('${rows.length} receipt(s) scanned today, none with fiscal_id.');
    exit(0);
  }

  stdout.writeln('Fiscal IDs scanned today: ${withFiscal.length}');
  stdout.writeln('');
  for (var i = 0; i < withFiscal.length; i++) {
    final r = withFiscal[i];
    final scanned = DateTime.parse(r['created_at'] as String)
        .toUtc()
        .add(const Duration(hours: 4));
    stdout.writeln('${i + 1}. ${r['fiscal_id']}');
    stdout.writeln('   store: ${r['store_name']}');
    stdout.writeln('   scanned (Baku): ${scanned.toIso8601String().substring(0, 19)}');
    stdout.writeln('   purchase_date (ignored): ${r['purchase_date']}');
  }
}
