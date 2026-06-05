/// Format receipt numbers without losing e-kassa precision (e.g. 0.335 kg).
class ReceiptNumbers {
  /// Formats a quantity for storage/display — never rounds to 2 decimals.
  static String formatQuantity(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e9) {
      return v.truncate().toString();
    }
    var s = v.toStringAsFixed(4);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Unit prices on e-kassa receipts are typically 2 decimal places.
  static String formatUnitPrice(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e9) {
      return v.truncate().toString();
    }
    return v.toStringAsFixed(2);
  }

  /// Line total exactly as printed on the receipt.
  static String formatLineTotal(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e9) {
      return v.truncate().toString();
    }
    return v.toStringAsFixed(2);
  }

  /// Parses numeric part after a label like "QTY: 0.335".
  static double parseLabeled(String part) {
    final m = RegExp(r'([\d.,]+)').firstMatch(part.replaceAll(',', '.'));
    return double.tryParse(m?.group(1) ?? '0') ?? 0;
  }
}
