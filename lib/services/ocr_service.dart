import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'crash_service.dart';
import '../utils/receipt_numbers.dart';

class OcrService {
  static const _visionChannel = MethodChannel('com.mycompany.balanzo/vision_ocr');
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<String> recognizeText(String imagePath) async {
    try {
      if (Platform.isIOS) {
        final visionText = await _recognizeWithAppleVision(imagePath);
        if (visionText != null && visionText.trim().isNotEmpty) {
          return visionText;
        }
      }
      return await _recognizeWithMlKit(imagePath);
    } catch (e, stack) {
      await CrashService.log(e, stack, context: 'ocr_extraction');
      rethrow;
    }
  }

  /// Apple Vision on iOS — same engine as macOS dev fixtures; better on e-kassa JPEGs.
  static Future<String?> _recognizeWithAppleVision(String imagePath) async {
    try {
      final text = await _visionChannel.invokeMethod<String>('recognizeText', {
        'path': imagePath,
      });
      return text;
    } catch (e) {
      debugPrint('[OCR] Apple Vision failed, falling back to ML Kit: $e');
      return null;
    }
  }

  static Future<String> _recognizeWithMlKit(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);

    // ML Kit (Android + iOS fallback): sort lines top-to-bottom, left-to-right within row.
    final allLines = <_OcrLine>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim().isNotEmpty
            ? line.text.trim()
            : line.elements.map((e) => e.text).join(' ').trim();
        if (text.isEmpty) continue;
        allLines.add(_OcrLine(
          top: line.boundingBox.top,
          left: line.boundingBox.left,
          text: text,
        ));
      }
    }

    allLines.sort((a, b) {
      final dy = a.top.compareTo(b.top);
      if (dy != 0) return dy;
      return a.left.compareTo(b.left);
    });
    return allLines.map((l) => l.text).join('\n');
  }

  static Future<String> recognizeMultiple(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return '';
    final sections = await Future.wait(imagePaths.map(recognizeText));
    final stitched = _stitch(sections);
    final cleaned = _removeDotLines(stitched);

    // Try e-kassa path first (government fiscal receipts with Say Qiymət header)
    final ekassaResult = _preprocessEkassa(cleaned);
    if (ekassaResult != cleaned) return ekassaResult;

    // Never run the generic qty×price parser on e-kassa — it misreads address/barcode noise.
    if (_isEkassaReceiptText(cleaned)) {
      final lines =
          cleaned.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      return _formatEkassaStructured(lines: lines, items: const []);
    }

    // Non-e-kassa receipt: extract structure using universal price-formula approach
    final lines = cleaned.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return _extractReceiptStructure(lines);
  }

  /// Exposed for unit tests (simulated OCR text).
  static String preprocessEkassaText(String raw) => _preprocessEkassa(raw);

  static String _extractReceiptStructure(List<String> lines) {
    // Price formula pattern: 2x8,00=16,00 or 2 X 8.00 = 16.00 or 1 % 3,00 = 3,00
    final priceRe = RegExp(
      r'(\d+[\.,]?\d*)\s*[xX%]\s*(\d+[\.,]\d+)\s*[=]?\s*(\d+[\.,]\d+)',
    );

    final priceIndices = <int>{};
    for (int i = 0; i < lines.length; i++) {
      if (priceRe.hasMatch(lines[i])) priceIndices.add(i);
    }

    final items = <String>[];
    for (final pi in priceIndices.toList()..sort()) {
      final priceMatch = priceRe.firstMatch(lines[pi])!;
      final qty = priceMatch.group(1)!.replaceAll(',', '.');
      final unitPrice = priceMatch.group(2)!.replaceAll(',', '.');
      final total = priceMatch.group(3)!.replaceAll(',', '.');

      String name = 'UNKNOWN';
      for (int j = pi - 1; j >= 0 && j >= pi - 3; j--) {
        final candidate = lines[j].trim();
        if (priceIndices.contains(j)) continue;
        if (candidate.length < 2) continue;
        if (RegExp(r'^[\d\s\.,\-\*\+\/\%\=]+$').hasMatch(candidate)) continue;
        name = candidate.replaceAll(RegExp(r'^\d+[\.\s]+'), '').trim();
        break;
      }

      items.add('ITEM: $name | QTY: $qty | UNIT: $unitPrice | TOTAL: $total');
    }

    String? storeName;
    final firstPriceIndex = priceIndices.isEmpty
        ? lines.length
        : priceIndices.reduce((a, b) => a < b ? a : b);
    for (int i = 0; i < firstPriceIndex; i++) {
      final line = lines[i].trim();
      if (line.length >= 3 &&
          line == line.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(line) &&
          !RegExp(r'^\d').hasMatch(line) &&
          !RegExp(r'^\W+$').hasMatch(line)) {
        storeName = line;
      }
    }

    String? date;
    final dateRe = RegExp(r'(\d{2})[./](\d{2})[./](\d{4})');
    for (final line in lines) {
      final m = dateRe.firstMatch(line);
      if (m != null) {
        date = '${m.group(3)}-${m.group(2)}-${m.group(1)}';
        break;
      }
    }

    double? total = _extractLabeledTotal(lines);
    if (total == null && items.isNotEmpty) {
      total = items.fold<double>(0, (sum, item) {
        final m = RegExp(r'TOTAL:\s*([\d.]+)').firstMatch(item);
        return sum + (double.tryParse(m?.group(1) ?? '0') ?? 0);
      });
    }

    // Detect service charge: look for a line containing a percentage followed by
    // or preceded by a monetary amount. Universal pattern - works in any language.
    double? serviceCharge;
    double? serviceChargeRate;
    final serviceRateRe = RegExp(r'(\d+)\s*%');
    final serviceAmountRe = RegExp(r'(\d+[.,]\d+)');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final rateMatch = serviceRateRe.firstMatch(line);
      if (rateMatch != null) {
        final rate = double.tryParse(rateMatch.group(1)!);
        if (rate != null && rate >= 1 && rate <= 25) {
          final amountMatch = serviceAmountRe.firstMatch(
            line.replaceFirst(rateMatch.group(0)!, ''),
          );
          if (amountMatch != null) {
            serviceCharge = double.tryParse(
              amountMatch.group(1)!.replaceAll(',', '.'),
            );
            serviceChargeRate = rate;
          } else if (i + 1 < lines.length) {
            final nextMatch = serviceAmountRe.firstMatch(lines[i + 1].trim());
            if (nextMatch != null) {
              serviceCharge = double.tryParse(
                nextMatch.group(1)!.replaceAll(',', '.'),
              );
              serviceChargeRate = rate;
            }
          }
        }
      }
    }

    // If no explicit service charge found but total > items sum, treat diff as implied charge
    if (serviceCharge == null && total != null) {
      final itemsSum = items.fold<double>(0, (sum, item) {
        final m = RegExp(r'TOTAL:\s*([\d.]+)').firstMatch(item);
        return sum + (double.tryParse(m?.group(1) ?? '0') ?? 0);
      });
      final diff = total - itemsSum;
      if (diff > 0.01 && itemsSum > 0 && diff / itemsSum < 0.30) {
        serviceCharge = double.parse(diff.toStringAsFixed(2));
      }
    }

    final buffer = StringBuffer();
    if (storeName != null) buffer.writeln('STORE: $storeName');
    if (date != null) buffer.writeln('DATE: $date');
    if (total != null) buffer.writeln('TOTAL: $total AZN');
    if (serviceCharge != null) {
      final rateStr = serviceChargeRate != null ? ' (${serviceChargeRate.toInt()}%)' : '';
      buffer.writeln('SERVICE_CHARGE: $serviceCharge$rateStr');
    }
    buffer.writeln('---');
    for (final item in items) {
      buffer.writeln(item);
    }
    return buffer.toString();
  }

  // Removes separator lines and standalone item-number prefix lines (e.g. "1." "2.")
  // that confuse the AI parser by breaking name/price line pairing.
  static String _removeDotLines(String text) {
    final itemNumRe = RegExp(r'^\d+\.$');
    final lines = text.split('\n');
    final filtered = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return true;
      // Remove standalone item number lines like "1." "2." "3."
      if (itemNumRe.hasMatch(trimmed)) return false;
      // Remove lines that are only dots or >50% dot characters
      final dotCount = trimmed.split('').where((c) => c == '.').length;
      return dotCount / trimmed.length <= 0.5;
    });
    return filtered.join('\n');
  }

  // ── Multi-photo stitch ─────────────────────────────────────────────────────
  // Only removes lines at the physical overlap boundary between photos.
  // Identical items within a single photo are preserved.
  static String _stitch(List<String> sections) {
    final pages = sections
        .map((s) => s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList())
        .toList();
    if (pages.isEmpty) return '';
    final result = List<String>.from(pages.first);
    for (int i = 1; i < pages.length; i++) {
      result.addAll(pages[i].skip(_overlapSize(pages[i - 1], pages[i])));
    }
    return result.join('\n');
  }

  static int _overlapSize(List<String> prev, List<String> curr) {
    final max = prev.length < curr.length ? prev.length : curr.length;
    for (int size = max.clamp(0, 20); size >= 1; size--) {
      final tail = prev.sublist(prev.length - size).map((l) => l.toLowerCase()).toList();
      final head = curr.sublist(0, size).map((l) => l.toLowerCase()).toList();
      if (_listEq(tail, head)) return size;
    }
    return 0;
  }

  static bool _listEq(List<String> a, List<String> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Azerbaijani e-kassa pre-processor ─────────────────────────────────────
  //
  // ML Kit reads multi-column receipts in column order, not row order.
  // All item names land in one block; all prices land in a separate block
  // after the "Say Qiymət Cəmi" header. Long names also have their
  // continuation lines appear out of sequence in the names block.
  //
  // Strategy:
  //   1. Split at item table header (Azeri or English variants)
  //   2. Extract price rows reliably from the clean numerical prices block
  //   3. Extract item names from the names block (grouped by *ƏDV: markers)
  //   4. Zip by position and emit canonical ITEM rows for AI parser
  //
  static String _preprocessEkassa(String raw) {
    final rawLines =
        raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (rawLines.isEmpty) return raw;

    final lines = _mergeSplitDecimalLines(rawLines);

    var tableIdx = _findEkassaTableHeader(lines);
    final isEkassa = _isEkassaReceiptText(raw, tableIdx: tableIdx);
    if (!isEkassa) return raw;

    String normNum(String l) => l
        .replaceAll(RegExp(r'\bl\.'), '1.')
        .replaceAll(',', '.');

    if (tableIdx < 0) {
      final priceLine = _findFirstPriceTripleLine(lines, normNum);
      if (priceLine > 0) tableIdx = priceLine - 1;
    }

    final labeledTotal = _extractLabeledTotal(lines);
    final vatCount = _countVatMarkers(lines);

    // Price-anchored: one item per price row, name scanned backward (robust on iPhone OCR).
    final priceAnchored = _extractPriceAnchoredItems(lines, tableIdx, normNum);

    final rowOrder = _extractVatBlockRowOrder(lines, tableIdx, normNum);
    final rowItems = _recoverOrphanEkassaItems(
      rowOrder,
      lines,
      tableIdx,
      normNum,
      labeledTotal,
    );

    final candidates = <List<({String name, double qty, double unit, double total})>>[
      priceAnchored,
      rowItems,
      _extractVatMarkerColumnStack(lines, tableIdx, normNum),
      _extractLooseEkassaItems(lines, normNum),
      _extractStackedLinePrices(lines, normNum),
      _extractInlineEkassaItemsAnywhere(lines, normNum),
    ];

    if (tableIdx >= 0) {
      candidates.addAll([
        _extractAzeriColumnStack(lines, tableIdx, normNum),
        _extractSplitColumnEkassaItems(lines, tableIdx, normNum),
        _extractInlineEkassaItems(lines, tableIdx, normNum),
      ]);
    }

    final best = _pickBestEkassaItems(candidates, labeledTotal, vatCount);
    if (best.isNotEmpty) {
      return _formatEkassaStructured(lines: lines, items: best);
    }

    if (labeledTotal != null ||
        _extractEkassaStore(lines).isNotEmpty ||
        _extractEkassaDate(lines).isNotEmpty) {
      final loose = _extractLooseEkassaItems(lines, normNum);
      if (loose.isNotEmpty) {
        return _formatEkassaStructured(lines: lines, items: loose);
      }
      return _formatEkassaStructured(lines: lines, items: const []);
    }

    return raw;
  }

  static bool _isEkassaReceiptText(String raw, {int? tableIdx}) {
    final lower = raw.toLowerCase();
    final headerIdx = tableIdx ?? _findEkassaTableHeader(
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList(),
    );
    return headerIdx >= 0 ||
        lower.contains('fiskal id') ||
        lower.contains('fiscal id') ||
        lower.contains('object name') ||
        lower.contains('obyektin adı') ||
        lower.contains('e-kassa.gov.az');
  }

  static List<String> _mergeSplitDecimalLines(List<String> lines) {
    final out = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (RegExp(r'^\d+\.\d$').hasMatch(l) && RegExp(r'^\d$').hasMatch(next)) {
          out.add('$l$next');
          i++;
          continue;
        }
        if (RegExp(r'^\d+\.\d$').hasMatch(l) && next == '0') {
          out.add('${l}0');
          i++;
          continue;
        }
      }
      out.add(l);
    }
    return out;
  }

  static int _countVatMarkers(List<String> lines) {
    var count = 0;
    for (final l in lines) {
      if (_isEkassaFooterLine(l.trim())) break;
      if (_isEkassaVatLine(l)) count++;
    }
    return count;
  }

  /// Primary strategy: one product name block per *VAT/*ƏDV marker, prices after table header.
  static List<({String name, double qty, double unit, double total})> _extractVatMarkerColumnStack(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    final names = _extractNamesByVatMarkers(lines, tableIdx);
    if (names.isEmpty) return [];

    var priceStart = tableIdx;
    if (priceStart < 0) {
      final firstPrice = _findFirstPriceTripleLine(lines, normNum);
      priceStart = firstPrice > 0 ? firstPrice - 1 : -1;
    }
    if (priceStart < 0) return [];

    final prices = _extractEkassaPriceRows(lines, priceStart, normNum);
    return _zipEkassaNamesAndPrices(names, prices);
  }

  static List<String> _extractNamesByVatMarkers(List<String> lines, int tableIdx) {
    final productStart = tableIdx >= 0
        ? _findProductSectionStart(lines, tableIdx)
        : _findProductSectionStart(lines, lines.length);
    final nameEnd = tableIdx >= 0 ? tableIdx : lines.length;

    final names = <String>[];
    var block = <String>[];

    void flushBlock() {
      final name = _joinNameLines(block);
      if (name.isNotEmpty) names.add(name);
      block = [];
    }

    for (int i = productStart; i < nameEnd; i++) {
      final l = lines[i];
      if (_isEkassaVatLine(l)) {
        flushBlock();
        continue;
      }
      if (_isLikelyAddressOrMetadata(l) || _isNameSkipLine(l)) {
        flushBlock();
        continue;
      }
      if (RegExp(r'^[\d\s.,]+$').hasMatch(l)) continue;
      block.add(l);
    }
    flushBlock();
    return names;
  }

  static bool _isNameSkipLine(String l) {
    return RegExp(
      r'^(Object|Obyektin|Product|Məhsulun|Quantity|Price|Total|Say|Qiymət|Cəmi|Sale receipt|Satış|Cashier|Kassir|Date|Tarix|Time|Vaxt|\(\s*(kg|pc|eded|pc\.)\s*\)$)',
      caseSensitive: false,
    ).hasMatch(l);
  }

  static String _joinNameLines(List<String> lines) {
    if (lines.isEmpty) return '';
    final joined = lines.join(' ');
    return _cleanEkassaProductName(joined);
  }

  static List<({String name, double qty, double unit, double total})> _extractAzeriColumnStack(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    final productStart = _findProductSectionStart(lines, tableIdx);
    final names = _extractEkassaProductNames(lines, productStart, tableIdx);
    final prices = _extractEkassaPriceRows(lines, tableIdx, normNum);
    return _zipEkassaNamesAndPrices(names, prices);
  }

  static int _findProductSectionStart(List<String> lines, int tableIdx) {
    var start = 0;
    for (int i = 0; i < tableIdx; i++) {
      if (RegExp(r'Satış çeki|Sale receipt', caseSensitive: false).hasMatch(lines[i])) {
        start = i + 1;
      }
      if (RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(lines[i])) {
        start = i + 1;
      }
    }
    return start;
  }

  static List<String> _extractEkassaProductNames(
    List<String> lines,
    int from,
    int to,
  ) {
    bool isVatMarker(String l) =>
        l.startsWith('*') ||
        (l.length < 25 &&
            (l.contains('18%') ||
                RegExp(r'\b(ƏDV|VAT)\b', caseSensitive: false).hasMatch(l)));

    final skipRe = RegExp(
      r'^(Obyektin|Object|Vergi|Taxpayer|MƏHDUD|VÖEN|Satış|Sale|Kassir|Cashier|NKA|NMQ|Fiskal|Fiscal|www\.|Növbə|Tarix|Vaxt|Date|Time|Məhsulun|Product|Quantity|Price|Say|Qiymət|Cəmi)',
      caseSensitive: false,
    );

    final names = <String>[];
    var buf = '';
    for (int i = from; i < to; i++) {
      final l = lines[i];
      if (_isLikelyAddressOrMetadata(l)) {
        if (buf.isNotEmpty) {
          names.add(_cleanEkassaProductName(buf));
          buf = '';
        }
        continue;
      }
      if (isVatMarker(l)) {
        if (buf.isNotEmpty) {
          names.add(_cleanEkassaProductName(buf));
          buf = '';
        }
        continue;
      }
      if (skipRe.hasMatch(l)) continue;
      if (RegExp(r'^[\d\s.,]+$').hasMatch(l)) continue;
      if (RegExp(r'^\d{10,}$').hasMatch(l.replaceAll(' ', ''))) continue;
      buf = buf.isEmpty ? l : '$buf $l';
    }
    if (buf.isNotEmpty && !_isLikelyAddressOrMetadata(buf)) {
      names.add(_cleanEkassaProductName(buf));
    }
    return names.where((n) => n.length >= 2 && n.length <= 80).toList();
  }

  static List<({double qty, double unit, double total})> _extractEkassaPriceRows(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    return _collectProductPriceRows(lines, tableIdx, normNum)
        .map((r) => (qty: r.qty, unit: r.unit, total: r.total))
        .toList();
  }

  static List<({String name, double qty, double unit, double total})> _zipEkassaNamesAndPrices(
    List<String> names,
    List<({double qty, double unit, double total})> prices,
  ) {
    if (prices.isEmpty) return [];

    var alignedNames =
        names.map(_cleanEkassaProductName).where((n) => n.length >= 2).toList();
    if (alignedNames.length > prices.length) {
      alignedNames = _alignNamesToPrices(alignedNames, prices.length);
    }

    final items = <({String name, double qty, double unit, double total})>[];
    final n = alignedNames.length < prices.length ? alignedNames.length : prices.length;
    for (int i = 0; i < n; i++) {
      items.add((
        name: alignedNames[i],
        qty: prices[i].qty,
        unit: prices[i].unit,
        total: prices[i].total,
      ));
    }
    for (int i = n; i < prices.length; i++) {
      items.add((
        name: 'Məhsul ${i + 1}',
        qty: prices[i].qty,
        unit: prices[i].unit,
        total: prices[i].total,
      ));
    }
    return items.where(_isValidEkassaItem).toList();
  }

  /// Picks the best contiguous window of [count] product names.
  static List<String> _alignNamesToPrices(List<String> names, int count) {
    if (names.length <= count) return names;
    var best = names.sublist(0, count);
    var bestScore = -999;
    for (int i = 0; i <= names.length - count; i++) {
      final window = names.sublist(i, i + count);
      final score = window.fold<int>(0, (s, n) => s + _nameAlignmentScore(n));
      if (score > bestScore) {
        bestScore = score;
        best = window;
      }
    }
    return best;
  }

  static int _nameAlignmentScore(String name) {
    if (RegExp(r'^Məhsul \d+$').hasMatch(name)) return 0;
    if (_isLikelyAddressOrMetadata(name)) return -20;
    if (name.length < 3) return 1;
    var score = 5;
    if (name.length >= 6) score += 2;
    if (RegExp(r'[A-Za-zƏÖÜĞŞİÇəöüğşıç]{3,}').hasMatch(name)) score += 3;
    return score;
  }

  /// Strips barcodes, times, dates, VAT markers, and OCR junk from product names.
  static String _cleanEkassaProductName(String raw) {
    var name = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(
      RegExp(r'^\*?\s*VAT[:\s-]*(?:18%|exempt[^\s,]*)\s*', caseSensitive: false),
      '',
    );
    name = name.replaceAll(
      RegExp(r'\s*\*?\s*VAT[:\s-]*(?:18%|exempt[^\s,]*)\s*', caseSensitive: false),
      ' ',
    );
    name = name.replaceAll(RegExp(r'^18%\s*'), '');
    name = name.replaceAll(RegExp(r'^\d{2}:\d{2}:\d{2}\s*'), '');
    name = name.replaceAll(RegExp(r'\bDate:\s*\d{2}:\d{2}:\d{2}\b', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'^\d{6}\s+Date:', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s+\d{10,}\s*$'), '');
    name = name.replaceAll(RegExp(r'\(\s*\d+\s*ədəd\s*\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(\s*\d+\s*eded\s*\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s+\(\s*\)\s*$'), '');
    name = name.replaceAll(RegExp(r'\(\s*(kg|pc|eded)\s*\)\s*$', caseSensitive: false), '');
    return name.trim();
  }

  static bool _isVatOrUnitNoiseLine(String l) {
    final t = l.trim();
    if (RegExp(r'^\*?\s*(?:VAT|ƏDV)', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'^\d{1,2}\s*%\s*$').hasMatch(t)) return true;
    if (RegExp(r'^18%\s*$').hasMatch(t)) return true;
    if (RegExp(r'^\(\s*(kg|pc|eded)\s*\)$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    return false;
  }

  static bool _hasVatNoiseName(String name) {
    return RegExp(r'(?:^|\s)(?:VAT|ƏDV|18%)', caseSensitive: false).hasMatch(name.trim());
  }

  /// Primary e-kassa strategy: match each price row to the nearest name above it.
  static List<({String name, double qty, double unit, double total})>
      _extractPriceAnchoredItems(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    final allPrices = _collectProductPriceRows(lines, tableIdx, normNum);
    if (allPrices.isEmpty) return [];

    final minLine = tableIdx >= 0 ? tableIdx + 1 : 0;
    final items = <({String name, double qty, double unit, double total})>[];

    for (final pr in allPrices) {
      var name = _findNameNearPriceLine(lines, pr.lineIdx, minLine);
      name = _cleanEkassaProductName(name);
      if (name.isEmpty || _isLikelyAddressOrMetadata(name)) continue;
      if (_hasVatNoiseName(name)) {
        name = _cleanEkassaProductName(
          name.replaceAll(
            RegExp(r'(?:^|\s)(?:VAT|ƏDV|18%)[^\w]*', caseSensitive: false),
            ' ',
          ),
        );
      }
      if (name.isEmpty) continue;

      final item = (
        name: name,
        qty: pr.qty,
        unit: pr.unit,
        total: pr.total,
      );
      if (!_isValidEkassaItem(item)) continue;

      final dup = items.any(
        (i) =>
            (i.total - item.total).abs() < 0.02 &&
            (i.unit - item.unit).abs() < 0.02 &&
            (i.qty - item.qty).abs() < 0.02 &&
            i.name.toLowerCase() == item.name.toLowerCase(),
      );
      if (dup) continue;

      items.add(item);
    }
    return items;
  }

  static List<({String name, double qty, double unit, double total})> _pickBestEkassaItems(
    List<List<({String name, double qty, double unit, double total})>> candidates,
    double? labeledTotal,
    int vatMarkerCount,
  ) {
    List<({String name, double qty, double unit, double total})>? best;
    var bestScore = -1e9;

    for (final list in candidates) {
      final valid = list.where(_isValidEkassaItem).toList();
      if (valid.isEmpty) continue;

      final sum = valid.fold(0.0, (s, i) => s + i.total);
      var score = valid.length * 20.0;
      if (vatMarkerCount > 0) {
        score -= (valid.length - vatMarkerCount).abs() * 15;
        if (valid.length == vatMarkerCount) score += 40;
        if (valid.length >= vatMarkerCount && valid.length <= vatMarkerCount + 2) {
          score += 20;
        }
      }
      if (labeledTotal != null && labeledTotal > 0) {
        score -= (sum - labeledTotal).abs() * 50;
        if ((sum - labeledTotal).abs() <= 0.05) score += 80;
        if ((sum - labeledTotal).abs() <= 0.15) score += 40;
        // Reject clearly incomplete or inflated item sets when grand total is known.
        if (sum < labeledTotal * 0.75) score -= 400;
        if (sum > labeledTotal * 1.15) score -= 400;
        if (valid.length == 1 && labeledTotal > sum + 5) score -= 400;
        if (valid.length == 1 && sum > labeledTotal + 5) score -= 400;
      }
      for (final item in valid) {
        if (_isLikelyAddressOrMetadata(item.name)) score -= 100;
        if (_hasVatNoiseName(item.name)) score -= 150;
        if (item.name.length > 60) score -= 30;
        if (RegExp(r'^Məhsul \d+$').hasMatch(item.name)) score -= 25;
        if (_isOcrNameFragment(item.name)) score -= 60;
      }
      final names = valid.map((i) => i.name.trim().toLowerCase()).toList();
      if (names.length != names.toSet().length) score -= 100;
      if (names.length == names.toSet().length && valid.length >= 2) score += 30;

      if (score > bestScore) {
        bestScore = score;
        best = valid;
      }
    }
    return best ?? [];
  }

  static bool _isLikelyAddressOrMetadata(String text) {
    return RegExp(
      r'KÜÇƏ|KUCƏ|RAYON|BAKI|AZ1052|AZ1033|NƏRİMANOV|NERIMANOV|TƏBRİZ|TEBRIZ|ÜNVAN|UNVAN|VÖEN|TIN:|1502989081|1503168422|1500072561|KƏSİŞMƏ|KESISME|ÇƏMƏNZƏMİNLİ|CƏMİYYƏTİ|CƏMİYYƏTI|SƏHMDAR|SEHMDAR|SAHMDAR|IBRAHIMZAD|EMIN\s+\d|YUSİF|VAZiR|ev\.\d|^\d+LI$|^OĞLU$|^OGLU$|m\.\-$',
      caseSensitive: false,
    ).hasMatch(text);
  }

  /// Row-order e-kassa: each product block ends with a *VAT/*ƏDV line.
  static List<({String name, double qty, double unit, double total})> _extractVatBlockRowOrder(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    var start = tableIdx >= 0 ? tableIdx + 1 : 0;
    while (start < lines.length && _isTableHeaderFragment(lines[start])) {
      start++;
    }

    final items = <({String name, double qty, double unit, double total})>[];
    var blockStart = start;

    for (int i = start; i < lines.length; i++) {
      if (!_isEkassaVatLine(lines[i])) continue;
      if (i > blockStart) {
        items.addAll(
          _parseEkassaProductBlocks(
            lines.sublist(blockStart, i),
            normNum,
          ),
        );
      }
      blockStart = i + 1;
    }
    return items;
  }

  /// One VAT block may contain several products when OCR drops *VAT lines.
  static List<({String name, double qty, double unit, double total})>
      _parseEkassaProductBlocks(
    List<String> block,
    String Function(String) normNum,
  ) {
    if (block.isEmpty) return [];

    final subBlocks = <List<String>>[];
    var current = <String>[];
    for (final raw in block) {
      final l = raw.trim();
      if (_isEkassaVatLine(l)) {
        if (current.isNotEmpty) subBlocks.add(current);
        current = [];
        continue;
      }
      final embedded = _splitLineOnEmbeddedVat(l);
      if (embedded.length > 1) {
        for (var i = 0; i < embedded.length; i++) {
          final part = embedded[i].trim();
          if (part.isEmpty) continue;
          if (i > 0 && current.isNotEmpty) {
            subBlocks.add(current);
            current = [];
          }
          current.add(part);
        }
      } else {
        current.add(raw);
      }
    }
    if (current.isNotEmpty) subBlocks.add(current);

    final items = <({String name, double qty, double unit, double total})>[];
    for (final sb in subBlocks.isEmpty ? [block] : subBlocks) {
      items.addAll(_parseEkassaProductBlockSequential(sb, normNum));
    }
    return items;
  }

  static List<String> _splitLineOnEmbeddedVat(String line) {
    return line
        .split(RegExp(
          r'\*?\s*VAT[:\s-]*(?:18%|exempt\b[^\s]*)',
          caseSensitive: false,
        ))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Emits one item per price row; names accumulate until each price line.
  static List<({String name, double qty, double unit, double total})>
      _parseEkassaProductBlockSequential(
    List<String> block,
    String Function(String) normNum,
  ) {
    final tripleRe = RegExp(
      r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final pairRe = RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$');
    final inlinePriceEnd = RegExp(
      r'(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final singleQtyRe = RegExp(r'^(\d+(?:\.\d+)?)$');
    final singleMoneyRe = RegExp(r'^(\d+(?:\.\d+)?)$');

    final items = <({String name, double qty, double unit, double total})>[];
    var nameParts = <String>[];
    double? pendingQty;
    ({double qty, double unit, double total})? pendingPrice;

    void emit({
      required double qty,
      required double unit,
      required double total,
    }) {
      var name = _cleanEkassaProductName(nameParts.join(' '));
      final splitNames = _splitEmbeddedProductNames(name);
      if (splitNames.length > 1) {
        name = splitNames.last;
      }
      if (name.isEmpty) {
        pendingPrice = (qty: qty, unit: unit, total: total);
        nameParts = [];
        pendingQty = null;
        return;
      }
      final item = (name: name, qty: qty, unit: unit, total: total);
      if (_isValidEkassaItem(item)) items.add(item);
      nameParts = [];
      pendingQty = null;
      pendingPrice = null;
    }

    void flushPendingPriceWithName() {
      if (pendingPrice == null) return;
      var name = _cleanEkassaProductName(nameParts.join(' '));
      if (name.isEmpty) return;
      final p = pendingPrice!;
      final item = (name: name, qty: p.qty, unit: p.unit, total: p.total);
      if (_isValidEkassaItem(item)) items.add(item);
      nameParts = [];
      pendingPrice = null;
      pendingQty = null;
    }

    bool tryEmitStacked(int i) {
      if (i + 2 >= block.length) return false;
      final a = normNum(block[i].trim());
      final b = normNum(block[i + 1].trim());
      final c = normNum(block[i + 2].trim());
      final qm = singleQtyRe.firstMatch(a);
      final um = singleMoneyRe.firstMatch(b);
      final tm = singleMoneyRe.firstMatch(c);
      if (qm == null || um == null || tm == null) return false;
      final row = (
        qty: double.parse(qm.group(1)!),
        unit: double.parse(um.group(1)!),
        total: double.parse(tm.group(1)!),
      );
      if (!_isValidEkassaPriceRow(row)) return false;
      emit(qty: row.qty, unit: row.unit, total: row.total);
      return true;
    }

    /// SUNMI OCR: unit price, qty, product name, repeat of unit as line total.
    /// Returns index of last consumed line, or null if pattern not matched.
    int? tryEmitUnitQtyNameTotal(int i) {
      final unitStr = normNum(block[i].trim());
      final um = singleMoneyRe.firstMatch(unitStr);
      if (um == null) return null;
      if (i + 1 >= block.length) return null;
      final qtyStr = normNum(block[i + 1].trim());
      final qm = singleQtyRe.firstMatch(qtyStr);
      if (qm == null) return null;
      final qty = double.parse(qm.group(1)!);
      if (qty != qty.roundToDouble() || qty < 1 || qty > 99) return null;
      final unit = double.parse(um.group(1)!);
      final name = _findNextProductNameInBlock(block, i + 2, normNum);
      if (name == null) return null;
      for (var j = i + 2; j < block.length && j <= i + 6; j++) {
        final t = normNum(block[j].trim());
        if (singleMoneyRe.hasMatch(t) && (double.parse(t) - unit).abs() <= 0.02) {
          nameParts = [name];
          emit(qty: qty, unit: unit, total: double.parse(t));
          return j;
        }
      }
      return null;
    }

    for (var i = 0; i < block.length; i++) {
      if (tryEmitStacked(i)) {
        i += 2;
        continue;
      }
      final unitQtyEnd = tryEmitUnitQtyNameTotal(i);
      if (unitQtyEnd != null) {
        i = unitQtyEnd;
        continue;
      }

      if (i + 1 < block.length) {
        final a = normNum(block[i].trim());
        final b = normNum(block[i + 1].trim());
        final ma = singleMoneyRe.firstMatch(a);
        final mb = singleMoneyRe.firstMatch(b);
        if (ma != null && mb != null) {
          final qty = double.parse(a);
          final total = double.parse(b);
          if (qty < 10 &&
              qty > 0 &&
              total > qty &&
              _findNextProductNameInBlock(block, i + 2, normNum) != null) {
            final impliedUnit = total / qty;
            if (impliedUnit >= 1 &&
                impliedUnit <= 500 &&
                (qty * impliedUnit - total).abs() <= 0.12) {
              emit(qty: qty, unit: impliedUnit, total: total);
              i += 1;
              continue;
            }
          }
        }
      }

      final raw = block[i];
      final l = normNum(raw.trim());
      if (l.isEmpty) continue;
      if (_isEkassaVatLine(l)) continue;
      if (RegExp(r'^\(\s*(kg|pc|eded)\s*\)$', caseSensitive: false).hasMatch(l)) {
        continue;
      }
      if (_isNameSkipLine(l)) continue;

      final m3 = tripleRe.firstMatch(l);
      if (m3 != null) {
        final inlineName = _cleanEkassaProductName(l.substring(0, m3.start).trim());
        if (inlineName.isNotEmpty) nameParts.add(inlineName);
        emit(
          qty: double.parse(m3.group(1)!),
          unit: double.parse(m3.group(2)!),
          total: double.parse(m3.group(3)!),
        );
        continue;
      }

      final m2 = pairRe.firstMatch(l);
      if (m2 != null) {
        var qty = pendingQty ?? 1.0;
        final unit = double.parse(m2.group(1)!);
        final total = double.parse(m2.group(2)!);
        // OCR: qty and total on two lines before product name (e.g. 0.85 / 3.40 / SAVUSKI).
        if (pendingQty == null &&
            unit < total &&
            unit > 0 &&
            unit < 10 &&
            _findNextProductNameInBlock(block, i + 1, normNum) != null) {
          final impliedUnit = total / unit;
          if (impliedUnit >= 1 &&
              impliedUnit <= 500 &&
              (unit * impliedUnit - total).abs() <= 0.12) {
            emit(qty: unit, unit: impliedUnit, total: total);
            continue;
          }
        }
        if (pendingQty == null &&
            i + 1 < block.length &&
            singleQtyRe.hasMatch(normNum(block[i + 1].trim()))) {
          final nextQty = double.parse(
            singleQtyRe.firstMatch(normNum(block[i + 1].trim()))!.group(1)!,
          );
          final qtyMatches = (nextQty * unit - total).abs() <= 0.2;
          if (qtyMatches && unit > total + 0.5) {
            final currentName = _cleanEkassaProductName(nameParts.join(' '));
            final nameAfterQty = _findNextProductNameInBlock(block, i + 2, normNum);
            final shouldDefer = nameAfterQty != null &&
                (currentName.isEmpty ||
                    nameAfterQty.length > currentName.length + 2);
            if (shouldDefer) {
              nameParts = [];
              pendingPrice = (qty: nextQty, unit: unit, total: total);
              pendingQty = null;
              i++;
              continue;
            }
            qty = nextQty;
            i++;
          } else if ((unit - total).abs() <= 0.05) {
            qty = nextQty;
            i++;
          }
        }
        emit(qty: qty, unit: unit, total: total);
        continue;
      }

      if (singleQtyRe.hasMatch(l)) {
        pendingQty = double.parse(l);
        continue;
      }

      final inline = inlinePriceEnd.firstMatch(l);
      if (inline != null && inline.start > 0) {
        nameParts.add(_cleanEkassaProductName(l.substring(0, inline.start)));
        emit(
          qty: double.parse(inline.group(1)!),
          unit: double.parse(inline.group(2)!),
          total: double.parse(inline.group(3)!),
        );
        continue;
      }

      if (RegExp(r'^[\d\s.,]+$').hasMatch(l)) continue;
      if (_isLikelyAddressOrMetadata(l)) continue;

      for (final part in _splitLineOnEmbeddedVat(l)) {
        if (part.isNotEmpty) nameParts.add(part);
      }
      if (pendingPrice != null) {
        flushPendingPriceWithName();
      }
    }

    flushPendingPriceWithName();

    return items;
  }

  static String? _findNextProductNameInBlock(
    List<String> block,
    int startIdx,
    String Function(String) normNum,
  ) {
    final pairRe = RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$');
    for (var j = startIdx; j < block.length && j <= startIdx + 5; j++) {
      final l = normNum(block[j].trim());
      if (l.isEmpty) continue;
      if (_isEkassaVatLine(l)) break;
      if (pairRe.hasMatch(l)) break;
      if (RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$')
          .hasMatch(l)) {
        break;
      }
      if (RegExp(r'^(\d+(?:\.\d+)?)$').hasMatch(l)) continue;
      if (RegExp(r'^\(\s*(kg|pc|eded)\s*\)$', caseSensitive: false).hasMatch(l)) {
        continue;
      }
      if (_isNameSkipLine(l) || _isBarcodeOrSkuLine(l)) continue;
      if (RegExp(r'^[\d\s.,]+$').hasMatch(l)) continue;
      final name = _cleanEkassaProductName(l);
      if (name.length >= 4 && !_isOcrNameFragment(name)) return name;
    }
    return null;
  }

  static List<String> _splitEmbeddedProductNames(String raw) {
    return raw
        .split(RegExp(
          r'\*?\s*VAT[:\s-]*(?:18%|exempt\b[^\s,]*)',
          caseSensitive: false,
        ))
        .map(_cleanEkassaProductName)
        .where((n) => n.length >= 2)
        .toList();
  }

  static List<({String name, double qty, double unit, double total, int lineIdx})>
      _collectProductPriceRows(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    final triple = RegExp(
      r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final pair = RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$');
    final qtyRe = RegExp(r'^(\d+(?:\.\d+)?)$');
    final moneyRe = RegExp(r'^(\d+(?:\.\d+)?)$');
    final rows = <({String name, double qty, double unit, double total, int lineIdx})>[];

    final start = tableIdx >= 0 ? tableIdx + 1 : 0;
    for (int i = start; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) {
        if (rows.isNotEmpty) break;
        continue;
      }

      final m3 = triple.firstMatch(l);
      if (m3 != null) {
        final row = (
          qty: double.parse(m3.group(1)!),
          unit: double.parse(m3.group(2)!),
          total: double.parse(m3.group(3)!),
        );
        if (_isValidEkassaPriceRow(row)) {
          rows.add((
            name: '',
            qty: row.qty,
            unit: row.unit,
            total: row.total,
            lineIdx: i,
          ));
        }
        continue;
      }

      final m2 = pair.firstMatch(l);
      if (m2 != null) {
        final unit = double.parse(m2.group(1)!);
        final total = double.parse(m2.group(2)!);

        // OCR: qty on line after unit/total pair (e.g. 14.0 10.0 / 0.715).
        if (i + 1 < lines.length) {
          final next = normNum(lines[i + 1]);
          final qmNext = qtyRe.firstMatch(next);
          if (qmNext != null) {
            final qty = double.parse(qmNext.group(1)!);
            final row = (qty: qty, unit: unit, total: total);
            if (_isValidEkassaPriceRow(row) && unit > total + 0.5) {
              rows.add((
                name: '',
                qty: row.qty,
                unit: row.unit,
                total: row.total,
                lineIdx: i + 1,
              ));
              i++;
              continue;
            }
          }
        }

        // Skip pair duplicate of stacked qty/unit/total ending on this line.
        if (rows.isNotEmpty &&
            (rows.last.total - total).abs() < 0.02 &&
            i - rows.last.lineIdx <= 3) {
          continue;
        }

        var qty = 1.0;
        if (i > 0 && qtyRe.hasMatch(normNum(lines[i - 1]))) {
          qty = double.parse(qtyRe.firstMatch(normNum(lines[i - 1]))!.group(1)!);
        }
        final row = (qty: qty, unit: unit, total: total);
        if (_isValidEkassaPriceRow(row)) {
          rows.add((
            name: '',
            qty: row.qty,
            unit: row.unit,
            total: row.total,
            lineIdx: i,
          ));
        }
        continue;
      }

      // Unit and total on consecutive lines (Poşet 0.10 / 0.10 / 1 / name).
      if (moneyRe.hasMatch(l) && i + 1 < lines.length) {
        final b = normNum(lines[i + 1]);
        if (moneyRe.hasMatch(b)) {
          var qty = 1.0;
          var lineIdx = i + 1;
          if (i + 2 < lines.length && qtyRe.hasMatch(normNum(lines[i + 2]))) {
            qty = double.parse(qtyRe.firstMatch(normNum(lines[i + 2]))!.group(1)!);
            lineIdx = i + 2;
          }
          final row = (
            qty: qty,
            unit: double.parse(moneyRe.firstMatch(l)!.group(1)!),
            total: double.parse(moneyRe.firstMatch(b)!.group(1)!),
          );
          if (_isValidEkassaPriceRow(row)) {
            rows.add((
              name: '',
              qty: row.qty,
              unit: row.unit,
              total: row.total,
              lineIdx: lineIdx,
            ));
            i = lineIdx;
            continue;
          }
        }
      }

      if (i + 2 < lines.length) {
        final a = normNum(lines[i]);
        final b = normNum(lines[i + 1]);
        final c = normNum(lines[i + 2]);
        final qm = qtyRe.firstMatch(a);
        final um = moneyRe.firstMatch(b);
        final tm = moneyRe.firstMatch(c);
        if (qm != null && um != null && tm != null) {
          final row = (
            qty: double.parse(qm.group(1)!),
            unit: double.parse(um.group(1)!),
            total: double.parse(tm.group(1)!),
          );
          if (_isValidEkassaPriceRow(row)) {
            rows.add((
              name: '',
              qty: row.qty,
              unit: row.unit,
              total: row.total,
              lineIdx: i,
            ));
            i += 2;
          }
        }
      }
    }
    return rows;
  }

  static bool _priceRowUsed(
    ({double qty, double unit, double total}) row,
    List<({String name, double qty, double unit, double total})> items,
  ) {
    for (final item in items) {
      if ((item.total - row.total).abs() > 0.02) continue;
      if ((item.qty - row.qty).abs() > 0.02) continue;
      if ((item.unit - row.unit).abs() > 0.02) continue;
      return true;
    }
    return false;
  }

  static bool _isOcrNameFragment(String l) {
    final t = l.trim();
    if (t.length < 4 && RegExp(r'[)=|]').hasMatch(t)) return true;
    if (RegExp(r'^[a-z]{1,4}[=)]', caseSensitive: false).hasMatch(t)) return true;
    return false;
  }

  static bool _isBarcodeOrSkuLine(String l) {
    final t = l.trim();
    if (RegExp(r'^\(\s*\d{8,}\s*\)$').hasMatch(t)) return true;
    if (RegExp(r'^\d{10,}$').hasMatch(t.replaceAll(' ', ''))) return true;
    return false;
  }

  static String _findNameBeforePriceLine(
    List<String> lines,
    int priceLineIdx,
    int minLine,
  ) {
    final buf = <String>[];
    for (int i = priceLineIdx - 1; i >= minLine; i--) {
      final l = lines[i].trim();
      if (l.isEmpty) continue;
      if (_isEkassaFooterLine(l)) break;
      if (_isVatOrUnitNoiseLine(l)) continue;
      if (_isNameSkipLine(l)) continue;
      if (_isLikelyAddressOrMetadata(l)) break;
      if (_isBarcodeOrSkuLine(l)) continue;
      if (_isOcrNameFragment(l)) continue;
      if (_isEkassaFooterLabelName(l)) continue;
      if (RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$').hasMatch(l)) break;
      if (RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$')
          .hasMatch(l)) {
        break;
      }
      if (RegExp(r'^\d+$').hasMatch(l)) continue;
      if (RegExp(r'^[\d\s.,]+$').hasMatch(l)) continue;
      buf.insert(0, l);
      if (buf.length >= 4) break;
    }
    return _cleanEkassaProductName(buf.join(' '));
  }

  static String _findNameAfterPriceLine(
    List<String> lines,
    int priceLineIdx,
  ) {
    for (int i = priceLineIdx + 1; i < lines.length && i <= priceLineIdx + 5; i++) {
      final l = lines[i].trim();
      if (l.isEmpty) continue;
      if (_isEkassaFooterLine(l)) break;
      if (_isEkassaVatLine(l) || _isVatOrUnitNoiseLine(l)) continue;
      if (_isNameSkipLine(l)) continue;
      if (_isBarcodeOrSkuLine(l)) continue;
      if (_isOcrNameFragment(l)) continue;
      if (RegExp(r'^\d+$').hasMatch(l)) continue;
      if (RegExp(r'^(\d+(?:\.\d+)?)$').hasMatch(l)) continue;
      if (RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$').hasMatch(l)) continue;
      if (RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$')
          .hasMatch(l)) {
        continue;
      }
      if (_isLikelyAddressOrMetadata(l)) continue;
      final name = _cleanEkassaProductName(l);
      if (name.length >= 2) return name;
    }
    return '';
  }

  /// Match product name to price row — handles both name-before-price and price-before-name layouts.
  static String _findNameNearPriceLine(
    List<String> lines,
    int priceLineIdx,
    int minLine,
  ) {
    final back = _findNameBeforePriceLine(lines, priceLineIdx, minLine);
    final forward = _findNameAfterPriceLine(lines, priceLineIdx);

    if (forward.isNotEmpty && back.isNotEmpty) {
      final backLine = _lineIndexOfName(lines, back, priceLineIdx, minLine, upward: true);
      final fwdLine =
          _lineIndexOfName(lines, forward, priceLineIdx, minLine, upward: false);
      if (backLine != null && fwdLine != null) {
        final backDist = priceLineIdx - backLine;
        final fwdDist = fwdLine - priceLineIdx;
        return backDist <= fwdDist ? back : forward;
      }
      return back;
    }
    if (forward.isNotEmpty) return forward;
    return back;
  }

  static int? _lineIndexOfName(
    List<String> lines,
    String name,
    int fromLine,
    int minLine, {
    required bool upward,
  }) {
    final needle = name.toLowerCase();
    if (upward) {
      for (int i = fromLine - 1; i >= minLine; i--) {
        if (lines[i].toLowerCase().contains(needle)) return i;
      }
    } else {
      for (int i = fromLine + 1; i < lines.length && i <= fromLine + 6; i++) {
        if (lines[i].toLowerCase().contains(needle)) return i;
      }
    }
    return null;
  }

  static List<({String name, double qty, double unit, double total})>
      _recoverOrphanEkassaItems(
    List<({String name, double qty, double unit, double total})> items,
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
    double? labeledTotal,
  ) {
    if (items.isEmpty) return items;

    final allPrices = _collectProductPriceRows(lines, tableIdx, normNum);
    final minLine = tableIdx >= 0 ? tableIdx + 1 : 0;
    final recovered = List<({String name, double qty, double unit, double total})>.from(items);

    for (final pr in allPrices) {
      final row = (qty: pr.qty, unit: pr.unit, total: pr.total);
      if (_priceRowUsed(row, recovered)) continue;

      final name = _findNameNearPriceLine(lines, pr.lineIdx, minLine);
      if (name.isEmpty) continue;

      final item = (name: name, qty: pr.qty, unit: pr.unit, total: pr.total);
      if (!_isValidEkassaItem(item)) continue;
      recovered.add(item);
    }

    recovered.sort((a, b) {
      final ia = allPrices.indexWhere((p) => (p.total - a.total).abs() < 0.02);
      final ib = allPrices.indexWhere((p) => (p.total - b.total).abs() < 0.02);
      return ia.compareTo(ib);
    });

    if (labeledTotal != null && labeledTotal > 0) {
      final sum = recovered.fold(0.0, (s, i) => s + i.total);
      if (sum - labeledTotal > 0.5) {
        return items;
      }
    }

    return recovered;
  }

  static bool _isTableHeaderFragment(String l) {
    final t = l.trim();
    if (RegExp(r'^\*{3,}$').hasMatch(t)) return true;
    return RegExp(
      r'^(Product|Quantity|Price|Total|Məhsul|Say|Qiymət|Cəmi)$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool _isValidEkassaPriceRow(({double qty, double unit, double total}) p) {
    if (p.qty <= 0 || p.qty > 999) return false;
    if (p.unit < 0 || p.unit > 500) return false;
    if (p.total < 0 || p.total > 500) return false;
    if (p.total == 0 && p.unit == 0 && p.qty >= 1) return true;
    if (p.total <= 0) return false;
    if (p.unit <= 0) return false;
    // OCR often duplicates unit price into qty column (e.g. 2.9 2.9 8.41).
    if ((p.qty - p.unit).abs() < 0.02 && p.qty >= 1.5) return false;
    final expected = p.qty * p.unit;
    return (p.total - expected).abs() <= 0.12;
  }

  static bool _isValidEkassaItem(({String name, double qty, double unit, double total}) item) {
    if (item.name.trim().length < 2 || item.name.length > 80) return false;
    if (_isLikelyAddressOrMetadata(item.name)) return false;
    if (_hasVatNoiseName(item.name)) return false;
    if (_isEkassaFooterLabelName(item.name)) return false;
    if (item.total == 0 && item.unit == 0 && item.qty >= 1) return true;
    return _isValidEkassaPriceRow((qty: item.qty, unit: item.unit, total: item.total));
  }

  static int _findFirstPriceTripleLine(
    List<String> lines,
    String Function(String) normNum,
  ) {
    final triple = RegExp(
      r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    for (int i = 0; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) continue;
      final m = triple.firstMatch(l);
      if (m == null) continue;
      final row = (
        qty: double.parse(m.group(1)!),
        unit: double.parse(m.group(2)!),
        total: double.parse(m.group(3)!),
      );
      if (_isValidEkassaPriceRow(row)) return i;
    }
    return -1;
  }

  /// Finds price rows anywhere on the receipt when the table header OCR fails.
  static List<({String name, double qty, double unit, double total})> _extractLooseEkassaItems(
    List<String> lines,
    String Function(String) normNum,
  ) {
    final triple = RegExp(
      r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final pair = RegExp(r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$');
    final prices = <({double qty, double unit, double total})>[];
    var firstPriceIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) {
        if (prices.isNotEmpty) break;
        continue;
      }
      if (_isEkassaVatLine(l)) continue;

      final m3 = triple.firstMatch(l);
      if (m3 != null) {
        final row = (
          qty: double.parse(m3.group(1)!),
          unit: double.parse(m3.group(2)!),
          total: double.parse(m3.group(3)!),
        );
        if (_isValidEkassaPriceRow(row)) {
          if (firstPriceIdx < 0) firstPriceIdx = i;
          prices.add(row);
        }
        continue;
      }

      final m2 = pair.firstMatch(l);
      if (m2 != null) {
        final unit = double.parse(m2.group(1)!);
        final total = double.parse(m2.group(2)!);
        if (unit > 0 && total > 0 && (unit - total).abs() <= 0.05) {
          final row = (qty: 1.0, unit: unit, total: total);
          if (_isValidEkassaPriceRow(row)) {
            if (firstPriceIdx < 0) firstPriceIdx = i;
            prices.add(row);
          }
        }
      }
    }

    if (prices.isEmpty) return [];

    final nameEnd = firstPriceIdx > 0 ? firstPriceIdx : lines.length;
    final names = _extractEkassaProductNames(lines, 0, nameEnd);
    return _zipEkassaNamesAndPrices(names, prices);
  }

  /// OCR sometimes splits qty / unit / total onto separate lines.
  static List<({String name, double qty, double unit, double total})> _extractStackedLinePrices(
    List<String> lines,
    String Function(String) normNum,
  ) {
    final qtyRe = RegExp(r'^(\d+(?:\.\d+)?)$');
    final moneyRe = RegExp(r'^(\d+(?:\.\d+)?)$');
    final prices = <({double qty, double unit, double total})>[];
    var firstPriceIdx = -1;

    for (int i = 0; i < lines.length - 2; i++) {
      final a = normNum(lines[i]);
      final b = normNum(lines[i + 1]);
      final c = normNum(lines[i + 2]);
      if (_isEkassaFooterLine(a) || _isEkassaFooterLine(b)) break;

      final qm = qtyRe.firstMatch(a);
      if (qm == null) continue;
      final um = moneyRe.firstMatch(b);
      final tm = moneyRe.firstMatch(c);
      if (um == null || tm == null) continue;

      final row = (
        qty: double.parse(qm.group(1)!),
        unit: double.parse(um.group(1)!),
        total: double.parse(tm.group(1)!),
      );
      if (!_isValidEkassaPriceRow(row)) continue;
      if (firstPriceIdx < 0) firstPriceIdx = i;
      prices.add(row);
      i += 2;
    }

    if (prices.isEmpty) return [];
    final nameEnd = firstPriceIdx > 0 ? firstPriceIdx : lines.length;
    final names = _extractEkassaProductNames(lines, 0, nameEnd);
    return _zipEkassaNamesAndPrices(names, prices);
  }

  static int _findEkassaTableHeader(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final n = lines[i].toLowerCase();
      if (n.contains('say') && (n.contains('qiym') || n.contains('cəmi'))) return i;
      if (n.contains('product') &&
          n.contains('quantity') &&
          n.contains('price') &&
          n.contains('total')) {
        return i;
      }
    }
    // Split English header: "Quantity Price Total" / "Product"
    for (int i = 0; i < lines.length - 1; i++) {
      final a = lines[i].toLowerCase();
      final b = lines[i + 1].toLowerCase();
      if (a.contains('quantity') &&
          a.contains('price') &&
          a.contains('total') &&
          b.contains('product')) {
        return i;
      }
      if (a.contains('məhsul') && b.contains('say')) return i;
    }
    for (int i = 0; i < lines.length - 1; i++) {
      final pair = '${lines[i]} ${lines[i + 1]}'.toLowerCase();
      if (pair.contains('product') &&
          pair.contains('quantity') &&
          pair.contains('price') &&
          pair.contains('total')) {
        return i;
      }
      if (pair.contains('say') && (pair.contains('qiym') || pair.contains('cəmi'))) {
        return i;
      }
    }
    return -1;
  }

  static List<({String name, double qty, double unit, double total})>
      _extractInlineEkassaItemsAnywhere(
    List<String> lines,
    String Function(String) normNum,
  ) {
    final priceEnd = RegExp(
      r'(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final items = <({String name, double qty, double unit, double total})>[];

    for (int i = 0; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) {
        if (items.isNotEmpty) break;
        continue;
      }
      if (_isEkassaVatLine(l)) continue;

      final m = priceEnd.firstMatch(l);
      if (m == null) continue;

      final name = _cleanEkassaProductName(l.substring(0, m.start).trim());
      if (name.length < 2 || name.length > 80) continue;
      if (_isLikelyAddressOrMetadata(name)) continue;

      final item = (
        name: name,
        qty: double.parse(m.group(1)!),
        unit: double.parse(m.group(2)!),
        total: double.parse(m.group(3)!),
      );
      if (_isValidEkassaItem(item)) items.add(item);
    }
    return items;
  }

  static bool _isEkassaFooterLine(String l) => RegExp(
        r'^(Cəmi\b|Total\b|Ödəniş|Payment|Nağd|Cashless|Cash\b|Paid|Bonus|Geri|Change|VAT refund|Total tax|VAT 18)',
        caseSensitive: false,
      ).hasMatch(l);

  static bool _isEkassaVatLine(String l) {
    final t = l.trim();
    if (t.length > 40) return false;
    if (RegExp(r'=\s*\d', caseSensitive: false).hasMatch(t)) return false;
    if (RegExp(r'^\*?\s*(?:VAT|ƏDV)[:\s-]', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^\*?\s*(?:VAT|ƏDV)-exempt', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // SUNMI receipts use *Trade markup: 18% per line item (not *VAT:).
    if (RegExp(r'^\*?\s*Trade\s+markup', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    return false;
  }

  static bool _isEkassaFooterLabelName(String name) {
    return RegExp(
      r'^(?:Prepayment|Credit|Bonus|Cashless|Cash|Paid|Change|Payment|Nisyə|Avans):?$',
      caseSensitive: false,
    ).hasMatch(name.trim());
  }

  /// English e-kassa: "Dəst (...) 1 19.99 19.99" on one line.
  static List<({String name, double qty, double unit, double total})> _extractInlineEkassaItems(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    final priceEnd = RegExp(
      r'(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final items = <({String name, double qty, double unit, double total})>[];

    for (int i = tableIdx + 1; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) break;
      if (_isEkassaVatLine(l)) continue;

      final m = priceEnd.firstMatch(l);
      if (m == null) continue;

      final name = _cleanEkassaProductName(l.substring(0, m.start).trim());
      if (name.length < 2 || name.length > 80) continue;
      if (_isLikelyAddressOrMetadata(name)) continue;

      final item = (
        name: name,
        qty: double.parse(m.group(1)!),
        unit: double.parse(m.group(2)!),
        total: double.parse(m.group(3)!),
      );
      if (_isValidEkassaItem(item)) items.add(item);
    }
    return items;
  }

  static List<({String name, double qty, double unit, double total})> _extractSplitColumnEkassaItems(
    List<String> lines,
    int tableIdx,
    String Function(String) normNum,
  ) {
    final mRe3 = RegExp(
      r'(\d+(?:\.\d{1,3})?)\s+(\d+(?:\.\d{1,3})?)\s+(\d+(?:\.\d{1,3})?)\s*$',
    );
    final mRe2 = RegExp(r'(\d+(?:\.\d{1,3})?)\s+(\d+(?:\.\d{1,3})?)\s*$');
    final eRe3 = RegExp(r'\)\s+(\d+)\s+(\d+\.\d{2})\s+(\d+\.\d{2})');
    final eRe2 = RegExp(r'\)\s+(\d+)\s+(\d+\.\d{2})\s*$');

    final prices = <({double qty, double unit, double total})>[];

    for (int i = tableIdx + 1; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) break;

      final em3 = eRe3.firstMatch(l);
      if (em3 != null) {
        prices.add((
          qty: double.parse(em3.group(1)!),
          unit: double.parse(em3.group(2)!),
          total: double.parse(em3.group(3)!),
        ));
        continue;
      }
      final em2 = eRe2.firstMatch(l);
      if (em2 != null) {
        final nextVal = i + 1 < lines.length ? double.tryParse(normNum(lines[i + 1])) : null;
        final qty = double.parse(em2.group(1)!);
        final unit = double.parse(em2.group(2)!);
        prices.add((qty: qty, unit: unit, total: nextVal ?? qty * unit));
        if (nextVal != null) i++;
        continue;
      }
      final mm3 = mRe3.firstMatch(l);
      if (mm3 != null) {
        prices.add((
          qty: double.parse(mm3.group(1)!),
          unit: double.parse(mm3.group(2)!),
          total: double.parse(mm3.group(3)!),
        ));
        continue;
      }
      final mm2 = mRe2.firstMatch(l);
      if (mm2 != null) {
        final nextVal = i + 1 < lines.length ? double.tryParse(normNum(lines[i + 1])) : null;
        final qty = double.parse(mm2.group(1)!);
        final unit = double.parse(mm2.group(2)!);
        prices.add((qty: qty, unit: unit, total: nextVal ?? qty * unit));
        if (nextVal != null) i++;
      }
    }

    if (prices.isEmpty) return [];

    bool isVatMarker(String l) =>
        l.startsWith('*') ||
        (l.length < 25 &&
            (l.contains('18%') ||
                RegExp(r'\bazad\b', caseSensitive: false).hasMatch(l)));

    final skipRe = RegExp(
      r'^(Obyektin|Object|Vergi\s|Taxpayer|MƏHDUD|VÖEN|Satış|Sale|Kassir|Cashier|NKA|NMQ|Fiskal|Fiscal|www\.|Növbə|Shift|Geri|Cəmi|Total|Ödəniş|Payment|Nağ|Cash|Bonus|Nisyə|Avans|Prepayment|Credit|[-*]{3,}|\d{2}\.\d{2}\.\d{4}|\d{2}:\d{2}:\d{2}|Tarix|Vaxt|Date|Time|Məhsulun|Product|Quantity|Price|Obyekt)',
      caseSensitive: false,
    );

    final names = <String>[];
    var buf = '';
    for (int i = 0; i < tableIdx; i++) {
      final l = lines[i];
      if (_isLikelyAddressOrMetadata(l)) {
        buf = '';
        continue;
      }
      if (isVatMarker(l)) {
        if (buf.isNotEmpty) {
          names.add(buf);
          buf = '';
        }
      } else if (!skipRe.hasMatch(l)) {
        buf = buf.isEmpty ? l : '$buf $l';
      }
    }
    if (buf.isNotEmpty && !_isLikelyAddressOrMetadata(buf)) names.add(buf);

    return _zipEkassaNamesAndPrices(
      names.where((n) => n.length <= 80).toList(),
      prices.where(_isValidEkassaPriceRow).toList(),
    );
  }

  static String _formatEkassaStructured({
    required List<String> lines,
    required List<({String name, double qty, double unit, double total})> items,
  }) {
    final store = _extractEkassaStore(lines);
    final date = _extractEkassaDate(lines);
    var total = _extractLabeledTotal(lines);
    total ??= items.fold<double>(0, (s, i) => s + i.total);

    final sb = StringBuffer();
    if (store.isNotEmpty) sb.writeln('STORE: $store');
    if (date.isNotEmpty) sb.writeln('DATE: $date');
    if (total > 0) sb.writeln('TOTAL: ${ReceiptNumbers.formatLineTotal(total)} AZN');
    final fiscalId = _extractEkassaFiscalId(lines);
    if (fiscalId.isNotEmpty) sb.writeln('FISCAL_ID: $fiscalId');
    sb.writeln('---');
    for (final item in items) {
      final cleanName = item.name.replaceAll(RegExp(r'\s+'), ' ').trim();
      sb.writeln(
        'ITEM: $cleanName | QTY: ${ReceiptNumbers.formatQuantity(item.qty)} | '
        'UNIT: ${ReceiptNumbers.formatUnitPrice(item.unit)} | '
        'TOTAL: ${ReceiptNumbers.formatLineTotal(item.total)}',
      );
    }
    return sb.toString();
  }

  static String _extractEkassaStore(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      final az = RegExp(r'Obyektin adı:\s*(.+)$', caseSensitive: false).firstMatch(l);
      if (az != null && az.group(1)!.trim().isNotEmpty) return az.group(1)!.trim();

      final en = RegExp(r'Object name:\s*(.+)$', caseSensitive: false).firstMatch(l);
      if (en != null && en.group(1)!.trim().isNotEmpty) return en.group(1)!.trim();

      if (RegExp(r'^Object name:?\s*$', caseSensitive: false).hasMatch(l) &&
          i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.isNotEmpty && !_isEkassaFooterLine(next)) return next;
      }
      if (RegExp(r'^Obyektin adı:?\s*$', caseSensitive: false).hasMatch(l) &&
          i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.isNotEmpty) return next;
      }
    }
    return '';
  }

  static String _extractEkassaDate(List<String> lines) {
    for (final l in lines) {
      final d = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(l);
      if (d != null) return '${d.group(3)}-${d.group(2)}-${d.group(1)}';
    }
    return '';
  }

  static String _extractEkassaFiscalId(List<String> lines) {
    final labeled = RegExp(
      r'(?:Fiskal|Fiscal)\s*(?:İD|ID|Id|id)[:\s]*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    );
    for (final l in lines) {
      final m = labeled.firstMatch(l.trim());
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  /// Reads receipt total from Cəmi/Total lines — never from change/cash paid.
  static double? _extractLabeledTotal(List<String> lines) {
    final exclude = RegExp(
      r'^(?:Geri|Change|Paid\s*cash|Cashless|Nağdsız|Nağd\s*ödənilib|Ödəniş\s*tipi|Bonus|Avans|Nisyə|VAT\s+refund|Cash\s*$|Qalıq|Ödənilib)',
      caseSensitive: false,
    );
    final labeled = RegExp(
      r'^(?:Cəmi|Total)\b[^0-9]*(\d+[.,]\d+)',
      caseSensitive: false,
    );
    final labelOnly = RegExp(r'^(?:Cəmi|Total)\.?\s*$', caseSensitive: false);

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].trim();
      if (exclude.hasMatch(l)) continue;
      if (RegExp(r'qaytarılıb|returned', caseSensitive: false).hasMatch(l)) continue;

      final m = labeled.firstMatch(l);
      if (m != null) {
        return double.tryParse(m.group(1)!.replaceAll(',', '.'));
      }
      if (labelOnly.hasMatch(l)) {
        double? before;
        double? after;
        if (i > 0) {
          final b = RegExp(r'^(\d+[.,]\d+)').firstMatch(lines[i - 1].trim());
          if (b != null) {
            before = double.tryParse(b.group(1)!.replaceAll(',', '.'));
          }
        }
        if (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (!exclude.hasMatch(next)) {
            final a = RegExp(r'^(\d+[.,]\d+)').firstMatch(next);
            if (a != null) {
              after = double.tryParse(a.group(1)!.replaceAll(',', '.'));
            }
          }
        }
        // English e-kassa often puts the grand total on the line BEFORE "Total".
        if (before != null && (after == null || before >= after)) return before;
        if (after != null) return after;
        continue;
      }
    }

    // Footer block: grand total is often the largest standalone amount near "Total"
    // (smaller lines may be VAT-exempt / VAT 18% subtotals).
    final totalIdx = lines.indexWhere(
      (l) => RegExp(r'^(?:Cəmi|Total)\.?\s*$', caseSensitive: false).hasMatch(l.trim()),
    );
    if (totalIdx >= 0) {
      final amounts = <double>[];
      for (int i = totalIdx; i < lines.length && i < totalIdx + 12; i++) {
        final l = lines[i].trim();
        if (RegExp(r'Payment type|Ödəniş|Paid cash|Nağd', caseSensitive: false).hasMatch(l)) {
          break;
        }
        if (RegExp(r'qaytarılıb|Change|Paid', caseSensitive: false).hasMatch(l)) continue;
        final solo = RegExp(r'^(\d+[.,]\d+)$').firstMatch(l);
        if (solo != null) {
          final v = double.tryParse(solo.group(1)!.replaceAll(',', '.'));
          if (v != null && v > 0 && v < 500) amounts.add(v);
        }
      }
      if (amounts.isNotEmpty) {
        return amounts.reduce((a, b) => a > b ? a : b);
      }
    }

    return null;
  }

  static Future<void> close() async => _recognizer.close();
}

class _OcrLine {
  final double top;
  final double left;
  final String text;
  const _OcrLine({required this.top, this.left = 0, required this.text});
}
