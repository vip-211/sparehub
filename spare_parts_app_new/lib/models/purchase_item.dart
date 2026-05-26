class PurchaseItem {
  final int? id;
  final String productName;
  final String? partNumber;
  final int quantity;
  final double costPrice;
  final double? sellingPrice;
  final double? gst;
  final double totalAmount;

  PurchaseItem({
    this.id,
    required this.productName,
    this.partNumber,
    required this.quantity,
    required this.costPrice,
    this.sellingPrice,
    this.gst,
    required this.totalAmount,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      id: json['id'],
      productName: json['productName'] ?? '',
      partNumber: json['partNumber'],
      quantity: json['quantity'] ?? 0,
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: json['sellingPrice']?.toDouble(),
      gst: json['gst']?.toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'partNumber': partNumber,
      'quantity': quantity,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'gst': gst,
      'totalAmount': totalAmount,
    };
  }
}
