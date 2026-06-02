import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'crash_service.dart';

class OcrService {
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<String> recognizeText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await _recognizer.processImage(inputImage);

      // ML Kit's result.text uses internal block ordering which is column-order
      // on multi-column receipts — wrong for parsing. Instead, extract all lines
      // with their Y coordinates and sort top-to-bottom for true reading order.
      final allLines = <_OcrLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final top = line.boundingBox.top;
          final text = line.elements.map((e) => e.text).join(' ');
          allLines.add(_OcrLine(top: top, text: text));
        }
      }

      // Sort by Y position (top to bottom)
      allLines.sort((a, b) => a.top.compareTo(b.top));

      return allLines.map((l) => l.text).join('\n');
    } catch (e, stack) {
      await CrashService.log(e, stack, context: 'ocr_extraction');
      rethrow;
    }
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
    final candidates = <List<({String name, double qty, double unit, double total})>>[];

    candidates.add(_extractVatMarkerColumnStack(lines, tableIdx, normNum));
    candidates.add(_extractLooseEkassaItems(lines, normNum));
    candidates.add(_extractStackedLinePrices(lines, normNum));
    candidates.add(_extractInlineEkassaItemsAnywhere(lines, normNum));

    if (tableIdx >= 0) {
      candidates.add(_extractAzeriColumnStack(lines, tableIdx, normNum));
      candidates.add(_extractSplitColumnEkassaItems(lines, tableIdx, normNum));
      candidates.add(_extractInlineEkassaItems(lines, tableIdx, normNum));
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
    final triple = RegExp(
      r'^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$',
    );
    final prices = <({double qty, double unit, double total})>[];

    for (int i = tableIdx + 1; i < lines.length; i++) {
      final l = normNum(lines[i]);
      if (_isEkassaFooterLine(l)) break;

      final m = triple.firstMatch(l);
      if (m == null) continue;

      final row = (
        qty: double.parse(m.group(1)!),
        unit: double.parse(m.group(2)!),
        total: double.parse(m.group(3)!),
      );
      if (_isValidEkassaPriceRow(row)) prices.add(row);
    }
    return prices;
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

  /// Strips barcodes, times, dates, and OCR junk from product names.
  static String _cleanEkassaProductName(String raw) {
    var name = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
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
      var score = valid.length * 15.0;
      if (labeledTotal != null && labeledTotal > 0) {
        score -= (sum - labeledTotal).abs() * 50;
        if ((sum - labeledTotal).abs() <= 0.05) score += 30;
      }
      if (vatMarkerCount > 0) {
        score -= (valid.length - vatMarkerCount).abs() * 25;
        if (valid.length == vatMarkerCount) score += 40;
      }
      for (final item in valid) {
        if (_isLikelyAddressOrMetadata(item.name)) score -= 100;
        if (item.name.length > 60) score -= 30;
        if (RegExp(r'^Məhsul \d+$').hasMatch(item.name)) score -= 5;
      }

      if (score > bestScore) {
        bestScore = score;
        best = valid;
      }
    }
    return best ?? [];
  }

  static bool _isLikelyAddressOrMetadata(String text) {
    return RegExp(
      r'KÜÇƏ|KUCƏ|RAYON|BAKI|AZ1052|AZ1033|NƏRİMANOV|NERIMANOV|TƏBRİZ|TEBRIZ|ÜNVAN|UNVAN|VÖEN|TIN:|1502989081|1503168422|1500072561|KƏSİŞMƏ|KESISME|ÇƏMƏNZƏMİNLİ|CƏMİYYƏTİ|CƏMİYYƏTI|SƏHMDAR|SEHMDAR|ev\.\d',
      caseSensitive: false,
    ).hasMatch(text);
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
    final qtyRe = RegExp(r'^(\d+)$');
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
    for (int i = 0; i < lines.length - 2; i++) {
      final window = lines.sublist(i, (i + 5).clamp(0, lines.length)).join(' ').toLowerCase();
      if (window.contains('product') &&
          window.contains('quantity') &&
          window.contains('total')) {
        return i;
      }
      if (window.contains('məhsul') && window.contains('say')) return i;
    }
    for (int i = 0; i < lines.length - 1; i++) {
      final pair = '${lines[i]} ${lines[i + 1]}'.toLowerCase();
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

  static bool _isEkassaVatLine(String l) =>
      RegExp(r'^\*.*(VAT|ƏDV|exempt)', caseSensitive: false).hasMatch(l.trim());

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
    if (total > 0) sb.writeln('TOTAL: ${total.toStringAsFixed(2)} AZN');
    sb.writeln('---');
    for (final item in items) {
      final cleanName = item.name.replaceAll(RegExp(r'\s+'), ' ').trim();
      sb.writeln(
        'ITEM: $cleanName | QTY: ${item.qty.toStringAsFixed(2)} | UNIT: ${item.unit.toStringAsFixed(2)} | TOTAL: ${item.total.toStringAsFixed(2)}',
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
      if (labelOnly.hasMatch(l) && i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (exclude.hasMatch(next)) continue;
        final n = RegExp(r'^(\d+[.,]\d+)').firstMatch(next);
        if (n != null) {
          return double.tryParse(n.group(1)!.replaceAll(',', '.'));
        }
      }
    }
    return null;
  }

  static Future<void> close() async => _recognizer.close();
}

class _OcrLine {
  final double top;
  final String text;
  const _OcrLine({required this.top, required this.text});
}
