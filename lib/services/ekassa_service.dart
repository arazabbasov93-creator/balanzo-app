import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/receipt.dart';
import 'receipt_ocr_pipeline.dart';

class EkassaService {
  static const _baseUrl =
      'https://monitoring.e-kassa.gov.az/pks-monitoring/2.0.0/documents';

  /// Extracts the document ID from a QR code value, full URL, or bare ID.
  static String? extractDocumentId(String qrValue) {
    final v = qrValue.trim();
    if (v.isEmpty) return null;

    final docParam = RegExp(r'[?&]doc=([A-Za-z0-9_-]+)', caseSensitive: false)
        .firstMatch(v);
    if (docParam != null) return docParam.group(1);

    try {
      final uri = Uri.parse(v);
      if (uri.host.contains('e-kassa.gov.az')) {
        final doc = uri.queryParameters['doc'];
        if (doc != null && doc.isNotEmpty) return doc;
      }
    } catch (_) {}

    if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v)) {
      // Product barcodes (EAN/UPC) are digits-only and shorter than fiscal IDs.
      if (RegExp(r'^\d+$').hasMatch(v) && v.length <= 14) return null;
      if (v.length < 8) return null;
      if (!RegExp(r'[A-Za-z]').hasMatch(v) && v.length < 20) return null;
      return v;
    }
    return null;
  }

  /// Picks the first raw scan value that contains an e-kassa document ID.
  static String? pickDocumentIdFromRawValues(Iterable<String> rawValues) {
    for (final raw in rawValues) {
      final v = raw.trim();
      if (v.isEmpty) continue;
      if (extractDocumentId(v) != null) return v;
    }
    return null;
  }

  static Future<String> fetchReceiptImagePath(String documentId) async {
    final docId = extractDocumentId(documentId) ?? documentId;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(docId)) {
      throw Exception('Invalid fiscal document ID');
    }

    final response = await http
        .get(Uri.parse('$_baseUrl/$docId'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404 || response.statusCode == 209) {
      throw Exception(
        'Receipt not found in e-kassa system. Try manual photo scan instead.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'e-kassa API error ${response.statusCode} for document $docId',
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Empty response from e-kassa');
    }
    if (!contentType.contains('image') && bytes.length < 500) {
      try {
        final err = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final code = err['code'] ?? err['statusCode'];
        if (code == 209 || code == '209') {
          throw Exception(
            'Receipt not found in e-kassa system. Try manual photo scan instead.',
          );
        }
      } catch (e) {
        if (e is Exception) rethrow;
      }
      throw Exception('Unexpected response from e-kassa');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ekassa_$docId.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// QR → government JPEG → Apple Vision OCR (iOS) → structured parse.
  static Future<Receipt> fetchAndParse(String qrOrDocumentId) async {
    final docId = extractDocumentId(qrOrDocumentId);
    if (docId == null || docId.isEmpty) {
      throw Exception('Could not read fiscal document ID from QR or input.');
    }

    final imagePath = await fetchReceiptImagePath(docId);
    try {
      final parsed = await ReceiptOcrPipeline.parseImages(
        [imagePath],
        documentId: docId,
        isGovernmentVerified: true,
        requireItems: true,
      );
      debugPrint('[Ekassa] Parsed: ${jsonEncode(parsed.toJson())}');
      return parsed;
    } finally {
      try {
        await File(imagePath).delete();
      } catch (_) {}
    }
  }
}
