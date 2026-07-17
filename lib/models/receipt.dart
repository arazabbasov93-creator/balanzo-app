class ReceiptItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? categoryId;
  final String? categoryName;
  final String? unit;
  final bool quantityLowConfidence;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.categoryId,
    this.categoryName,
    this.unit,
    this.quantityLowConfidence = false,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    final rawQty = json['quantity'];
    final qty = rawQty is num ? rawQty.toDouble() : null;
    final lowConf = json['quantity_low_confidence'] == true ||
        (qty == null && json.containsKey('quantity'));
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      quantity: qty ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['category_id'] as String?,
      categoryName: json['category'] as String?,
      unit: json['unit'] as String?,
      quantityLowConfidence: lowConf,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        if (categoryId != null) 'category_id': categoryId,
        if (unit != null) 'unit': unit,
        if (quantityLowConfidence) 'quantity_low_confidence': true,
      };

  ReceiptItem copyWith({
    String? name,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? categoryId,
    String? categoryName,
    String? unit,
    bool? quantityLowConfidence,
  }) =>
      ReceiptItem(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        unit: unit ?? this.unit,
        quantityLowConfidence: quantityLowConfidence ?? this.quantityLowConfidence,
      );
}

class Receipt {
  final String? store;
  final DateTime? date;
  final List<ReceiptItem> items;
  final double subtotal;
  final double? serviceCharge;
  final double? discountTotal;
  final double vat;
  final double total;
  final String? currency;
  final bool isGovernmentVerified;
  final String? documentId;
  final int? sequenceNumber;

  const Receipt({
    this.store,
    this.date,
    required this.items,
    required this.subtotal,
    this.serviceCharge,
    this.discountTotal,
    required this.vat,
    required this.total,
    this.currency,
    this.isGovernmentVerified = false,
    this.documentId,
    this.sequenceNumber,
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
        serviceCharge: (json['service_charge'] is num &&
                (json['service_charge'] as num).toDouble() > 0)
            ? (json['service_charge'] as num).toDouble()
            : null,
        discountTotal: (json['discount_total'] is num &&
                (json['discount_total'] as num).toDouble() > 0)
            ? (json['discount_total'] as num).toDouble()
            : null,
        vat: (json['vat'] as num?)?.toDouble() ?? 0.0,
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        currency: _parseCurrency(json['currency']),
        sequenceNumber: (json['sequence_number'] as num?)?.toInt(),
      );

  static String? _parseCurrency(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() => {
        'store': store,
        'date': date?.toIso8601String().split('T').first,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'service_charge': serviceCharge ?? 0.0,
        'discount_total': discountTotal ?? 0.0,
        'vat': vat,
        'total': total,
        'currency': currency,
        if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      };

  Receipt withCorrectedTotals() {
    final itemsSum = items.fold(0.0, (s, i) => s + i.totalPrice);
    if (itemsSum <= 0) return this;

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
        discountTotal: discountTotal,
        vat: vat,
        total: total,
        currency: currency,
        isGovernmentVerified: isGovernmentVerified,
        documentId: documentId,
        sequenceNumber: sequenceNumber,
      );
    }

    final looksLikeChangeOrCash =
        total > itemsSum * 1.35 && total > itemsSum + 1.0;
    if (looksLikeChangeOrCash) {
      final correctedTotal =
          itemsSum + (serviceCharge ?? 0) - (discountTotal ?? 0);
      return Receipt(
        store: store,
        date: date,
        items: items,
        subtotal: itemsSum,
        serviceCharge: serviceCharge,
        discountTotal: discountTotal,
        vat: vat,
        total: correctedTotal,
        currency: currency,
        isGovernmentVerified: isGovernmentVerified,
        documentId: documentId,
        sequenceNumber: sequenceNumber,
      );
    }

    return this;
  }
}
