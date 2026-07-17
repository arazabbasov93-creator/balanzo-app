/// Normalizes product names for restock grouping across receipt variants.
class ProductNameNormalizer {
  static final _fuelTokens = {
    'benzin', 'benz', 'fuel', 'yanacaq', 'nafta', 'dizel', 'diesel', 'ai-92',
    'ai-95', 'ai-98', 'super', 'premium', 'socar', 'azpetrol',
  };

  static String normalize(String raw) {
    var s = raw.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return raw.trim();

    final tokens = s.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return s;

    // Fuel: collapse station-specific labels to a single series key.
    if (tokens.any((t) => _fuelTokens.contains(t)) ||
        RegExp(r'ai[- ]?\d{2}').hasMatch(s)) {
      return 'fuel';
    }

    // Drop trailing quantity/size noise (e.g. "0.5L", "1kg").
    final filtered = tokens
        .where((t) => !RegExp(r'^\d+([.,]\d+)?(l|kg|ml|g|əd|ed)?$').hasMatch(t))
        .toList();
    if (filtered.isNotEmpty) {
      return filtered.take(4).join(' ');
    }
    return tokens.take(4).join(' ');
  }

  /// Token Jaccard similarity 0..1 for fuzzy merge.
  static double similarity(String a, String b) {
    final na = normalize(a).split(' ').toSet();
    final nb = normalize(b).split(' ').toSet();
    if (na.isEmpty || nb.isEmpty) return 0;
    final inter = na.intersection(nb).length;
    final union = na.union(nb).length;
    return inter / union;
  }

  /// Pick canonical display name (longest original) for a cluster.
  static String canonicalName(Iterable<String> originals) {
    return originals.reduce(
      (best, next) => next.trim().length > best.trim().length ? next : best,
    );
  }
}
