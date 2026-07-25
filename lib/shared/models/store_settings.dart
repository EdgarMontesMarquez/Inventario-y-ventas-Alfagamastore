class StoreSettings {
  final String storeName;
  final String nit;
  final String phone;
  final String address;
  final String receiptFooter;
  final String currencySymbol;
  final bool soundOnScan;
  final bool autoPrintReceipt;

  const StoreSettings({
    required this.storeName,
    required this.nit,
    required this.phone,
    required this.address,
    required this.receiptFooter,
    required this.currencySymbol,
    required this.soundOnScan,
    required this.autoPrintReceipt,
  });

  StoreSettings copyWith({
    String? storeName,
    String? nit,
    String? phone,
    String? address,
    String? receiptFooter,
    String? currencySymbol,
    bool? soundOnScan,
    bool? autoPrintReceipt,
  }) {
    return StoreSettings(
      storeName: storeName ?? this.storeName,
      nit: nit ?? this.nit,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      soundOnScan: soundOnScan ?? this.soundOnScan,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
    );
  }
}
