class Purchase {
  final int? id;
  final String supplierName;
  final String? supplierMobile;
  final String invoiceNumber;
  final DateTime purchaseDate;
  final String productName;
  final String? partNumber;
  final int quantity;
  final double costPrice;
  final double? sellingPrice;
  final double? gst;
  final double totalAmount;
  final String? notes;
  final String? billImageUrl;
  final String? billPdfUrl;
  final int? createdById;
  final String? createdByName;
  final DateTime? createdAt;

  Purchase({
    this.id,
    required this.supplierName,
    this.supplierMobile,
    required this.invoiceNumber,
    required this.purchaseDate,
    required this.productName,
    this.partNumber,
    required this.quantity,
    required this.costPrice,
    this.sellingPrice,
    this.gst,
    required this.totalAmount,
    this.notes,
    this.billImageUrl,
    this.billPdfUrl,
    this.createdById,
    this.createdByName,
    this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'],
      supplierName: json['supplierName'] ?? '',
      supplierMobile: json['supplierMobile'],
      invoiceNumber: json['invoiceNumber'] ?? '',
      purchaseDate: json['purchaseDate'] != null 
          ? DateTime.parse(json['purchaseDate']) 
          : DateTime.now(),
      productName: json['productName'] ?? '',
      partNumber: json['partNumber'],
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      costPrice: (json['costPrice'] as num? ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble(),
      gst: (json['gst'] as num?)?.toDouble(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      notes: json['notes'],
      billImageUrl: json['billImageUrl'],
      billPdfUrl: json['billPdfUrl'],
      createdById: json['createdById'],
      createdByName: json['createdByName'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'supplierName': supplierName,
      'supplierMobile': supplierMobile,
      'invoiceNumber': invoiceNumber,
      'purchaseDate': purchaseDate.toIso8601String().split('T')[0],
      'productName': productName,
      'partNumber': partNumber,
      'quantity': quantity,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'gst': gst,
      'totalAmount': totalAmount,
      'notes': notes,
      'billImageUrl': billImageUrl,
      'billPdfUrl': billPdfUrl,
    };
  }
}
