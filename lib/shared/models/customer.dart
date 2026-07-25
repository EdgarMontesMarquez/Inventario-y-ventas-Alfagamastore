class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String documentType; // 'CC' | 'NIT' | 'CE' | 'Pasaporte'
  final String documentId;
  final double totalPurchases;
  final double activeCreditBalance;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.documentType = 'CC',
    this.documentId = '',
    required this.totalPurchases,
    required this.activeCreditBalance,
    required this.createdAt,
  });
}
