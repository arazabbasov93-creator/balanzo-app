import 'package:flutter/foundation.dart';

import '../models/receipt.dart';
import 'category_assignment_service.dart';
import 'category_service.dart';
import 'ekassa_service.dart';
import 'ocr_service.dart';
import 'receipt_parser_service.dart';
import 'structured_receipt_parser.dart';

/// Single entry point for OCR → structured receipt parsing.
/// Used by fiscal-ID fetch, QR scan, photo capture, gallery upload, and refresh.
class ReceiptOcrPipeline {
  /// Extract fiscal document ID from OCR text (English or Azeri labels).
  static String? extractFiscalId(String text) {
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('FISCAL_ID:')) {
        final id = line.substring(10).trim();
        if (id.isNotEmpty) return EkassaService.extractDocumentId(id) ?? id;
      }
    }
    final labeled = RegExp(
      r'(?:Fiskal|Fiscal)\s*(?:İD|ID|Id|id)[:\s]*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    );
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final m = labeled.firstMatch(line);
      if (m != null) {
        return EkassaService.extractDocumentId(m.group(1)!) ?? m.group(1);
      }
    }
    return null;
  }

  /// True when OCR output looks like a government e-kassa receipt.
  static bool isEkassaOcrText(String text) {
    final lower = text.toLowerCase();
    return text.contains('ITEM:') &&
        (lower.contains('fiskal id') ||
            lower.contains('fiscal id') ||
            lower.contains('fiskal i̇d') ||
            lower.contains('object name') ||
            lower.contains('obyektin adı') ||
            lower.contains('say qiym') ||
            lower.contains('quantity price total'));
  }

  /// Parse structured OCR text into a [Receipt].
  ///
  /// [documentId] — known fiscal ID (QR/API fetch). When omitted, extracted from OCR.
  /// [isGovernmentVerified] — true only when receipt JPEG came from e-kassa API.
  static Future<Receipt> parseOcrText(
    String ocrText, {
    String? documentId,
    bool isGovernmentVerified = false,
    bool requireItems = false,
  }) async {
    if (ocrText.trim().isEmpty) {
      throw Exception('Could not read text from receipt image.');
    }

    var parsed =
        StructuredReceiptParser.tryParse(ocrText)?.withCorrectedTotals();

    if (parsed == null || parsed.items.isEmpty) {
      parsed = StructuredReceiptParser.tryParseHeaderOnly(ocrText)
          ?.withCorrectedTotals();
    }

    if ((parsed == null || parsed.items.isEmpty) && ReceiptParserService.isAvailable) {
      parsed = (await ReceiptParserService.parse(ocrText)).withCorrectedTotals();
    }

    if (parsed == null) {
      throw Exception(
        'Could not parse this receipt on device. '
        'Try a clearer photo, scan the e-kassa QR, or enter items manually.',
      );
    }

    if (requireItems && parsed.items.isEmpty && parsed.total <= 0) {
      throw Exception(
        'Could not read line items from this e-kassa receipt. '
        'Try Refresh from e-kassa on the saved receipt, or edit items manually.',
      );
    }

    final docId = documentId ?? extractFiscalId(ocrText);

    final receipt = Receipt(
      store: parsed.store,
      date: parsed.date,
      items: parsed.items,
      subtotal: parsed.subtotal,
      serviceCharge: parsed.serviceCharge,
      vat: parsed.vat,
      total: parsed.total,
      currency: parsed.currency,
      isGovernmentVerified: isGovernmentVerified,
      documentId: docId,
    ).withCorrectedTotals();

    if (isParseLikelyIncomplete(receipt)) {
      debugPrint(
        '[OCR] Partial parse (${receipt.items.length} items, '
        'total=${receipt.total}, sum=${_itemsSum(receipt)}) — showing for edit',
      );
    }

    final categories = await CategoryService.fetchAll();
    return CategoryAssignmentService.assignReceipt(receipt, categories);
  }

  /// Logs when item sum is below receipt total; does not block save sheet.
  static bool isParseLikelyIncomplete(Receipt receipt) {
    if (receipt.items.isEmpty) return receipt.total > 0;
    final sum = _itemsSum(receipt);
    if (sum <= 0) return true;
    if (receipt.total > sum + 0.75 && receipt.total < sum * 4) return true;
    if (receipt.items.length == 1 && receipt.total > sum + 5) return true;
    return false;
  }

  static double _itemsSum(Receipt receipt) =>
      receipt.items.fold(0.0, (s, i) => s + i.totalPrice);

  /// Run on-device OCR on one or more images, then parse with the shared pipeline.
  /// iOS uses Apple Vision; Android uses ML Kit.
  static Future<Receipt> parseImages(
    List<String> imagePaths, {
    String? documentId,
    bool isGovernmentVerified = false,
    bool requireItems = false,
  }) async {
    final ocrText = await OcrService.recognizeMultiple(imagePaths);
    return parseOcrText(
      ocrText,
      documentId: documentId,
      isGovernmentVerified: isGovernmentVerified,
      requireItems: requireItems,
    );
  }
}
