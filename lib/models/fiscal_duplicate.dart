class FiscalDuplicateHit {
  final String receiptId;
  final String storeName;
  final String? purchaseDate;
  final String scannerLabel;

  const FiscalDuplicateHit({
    required this.receiptId,
    required this.storeName,
    this.purchaseDate,
    required this.scannerLabel,
  });
}
