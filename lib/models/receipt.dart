class ReceiptItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? categoryId;
  final String? categoryName;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.categoryId,
    this.categoryName,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
        totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
        categoryId: json['category_id'] as String?,
        categoryName: json['category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        if (categoryId != null) 'category_id': categoryId,
      };

  ReceiptItem copyWith({
    String? name,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? categoryId,
    String? categoryName,
  }) =>
      ReceiptItem(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
      );
}

class Receipt {
  final String? store;
  final DateTime? date;
  final List<ReceiptItem> items;
  final double subtotal;
  final double? serviceCharge;
  final double vat;
  final double total;
  final String currency;
  final bool isGovernmentVerified;
  final String? documentId; // e-kassa fiscal document ID

  const Receipt({
    this.store,
    this.date,
    required this.items,
    required this.subtotal,
    this.serviceCharge,
    required this.vat,
    required this.total,
    this.currency = 'AZN',
    this.isGovernmentVerified = false,
    this.documentId,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        store: json['store'] as String?,
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String)
            : null,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        serviceCharge: (json['service_charge'] is num && (json['service_charge'] as num).toDouble() > 0)
            ? (json['service_charge'] as num).toDouble()
            : null,
        vat: (json['vat'] as num?)?.toDouble() ?? 0.0,
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'AZN',
      );

  Map<String, dynamic> toJson() => {
        'store': store,
        'date': date?.toIso8601String().split('T').first,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'service_charge': serviceCharge ?? 0.0,
        'vat': vat,
        'total': total,
        'currency': currency,
      };

  /// Fixes OCR mistakes like using change/cash-paid as receipt total.
  /// Keeps government receipt total when line items are incomplete.
  Receipt withCorrectedTotals() {
    final itemsSum = items.fold(0.0, (s, i) => s + i.totalPrice);
    if (itemsSum <= 0) return this;

    // Parsed items incomplete — keep receipt header total (e-kassa grand total).
    final ekassaReceipt =
        isGovernmentVerified || (documentId != null && documentId!.isNotEmpty);
    if (ekassaReceipt &&
        total > itemsSum + 0.5 &&
        total < itemsSum * 3) {
      return Receipt(
        store: store,
        date: date,
        items: items,
        subtotal: itemsSum,
        serviceCharge: serviceCharge,
        vat: vat,
        total: total,
        currency: currency,
        isGovernmentVerified: isGovernmentVerified,
        documentId: documentId,
      );
    }

    final looksLikeChangeOrCash =
        total > itemsSum * 1.35 && total > itemsSum + 1.0;
    if (looksLikeChangeOrCash) {
      final correctedTotal = itemsSum + (serviceCharge ?? 0);
      return Receipt(
        store: store,
        date: date,
        items: items,
        subtotal: itemsSum,
        serviceCharge: serviceCharge,
        vat: vat,
        total: correctedTotal,
        currency: currency,
        isGovernmentVerified: isGovernmentVerified,
        documentId: documentId,
      );
    }

    return this;
  }
}
