import '../models/receipt.dart';

/// Parses canonical OCR output (STORE/DATE/TOTAL/ITEM lines) without AI.
class StructuredReceiptParser {
  static Receipt? tryParse(String text) {
    if (!text.contains('ITEM:')) return null;

    String? store;
    DateTime? date;
    double? total;
    double? vat;
    final items = <ReceiptItem>[];

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line == '---') continue;

      if (line.startsWith('STORE:')) {
        store = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('DATE:')) {
        date = DateTime.tryParse(line.substring(5).trim());
        continue;
      }
      if (line.startsWith('TOTAL:')) {
        final m = RegExp(r'([\d.]+)').firstMatch(line.substring(6));
        if (m != null) total = double.tryParse(m.group(1)!);
        continue;
      }
      if (line.startsWith('VAT:')) {
        final m = RegExp(r'([\d.]+)').firstMatch(line.substring(4));
        if (m != null) vat = double.tryParse(m.group(1)!);
        continue;
      }
      if (!line.startsWith('ITEM:')) continue;

      final body = line.substring(5).trim();
      final parts = body.split('|').map((p) => p.trim()).toList();
      if (parts.length < 4) continue;

      final name = parts[0].trim();
      final qty = _num(parts[1]);
      final unit = _num(parts[2]);
      final itemTotal = _num(parts[3]);
      if (name.isEmpty) continue;
      if (itemTotal < 0) continue;

      items.add(ReceiptItem(
        name: name,
        quantity: qty > 0 ? qty : 1,
        unitPrice: unit >= 0 ? unit : itemTotal,
        totalPrice: itemTotal,
      ));
    }

    if (items.isEmpty) return null;

    final subtotal = items.fold(0.0, (s, i) => s + i.totalPrice);
    return Receipt(
      store: store?.isNotEmpty == true ? store : null,
      date: date,
      items: items,
      subtotal: subtotal,
      vat: vat ?? 0,
      total: total ?? subtotal,
      currency: 'AZN',
    );
  }

  static double _num(String part) {
    final m = RegExp(r'([\d.]+)').firstMatch(part.replaceAll(',', '.'));
    return double.tryParse(m?.group(1) ?? '0') ?? 0;
  }
}
