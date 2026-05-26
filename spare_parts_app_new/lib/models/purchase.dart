import 'purchase_item.dart';

class Purchase {
  final int? id;
  final String supplierName;
  final String? supplierMobile;
  final String invoiceNumber;
  final DateTime purchaseDate;
  final List<PurchaseItem> items;
  final double? discount;
  final double totalAmount;
  final String? notes;
  final String? billImageUrl;
  final String? billPdfUrl;
  final double? dailyAmount;
  final double? remainingAmount;
  final int? createdById;
  final String? createdByName;
  final DateTime? createdAt;

  Purchase({
    this.id,
    required this.supplierName,
    this.supplierMobile,
    required this.invoiceNumber,
    required this.purchaseDate,
    required this.items,
    this.discount,
    required this.totalAmount,
    this.notes,
    this.billImageUrl,
    this.billPdfUrl,
    this.dailyAmount,
    this.remainingAmount,
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
      items: (json['items'] as List? ?? [])
          .map((i) => PurchaseItem.fromJson(i))
          .toList(),
      discount: (json['discount'] as num?)?.toDouble(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      notes: json['notes'],
      billImageUrl: json['billImageUrl'],
      billPdfUrl: json['billPdfUrl'],
      dailyAmount: (json['dailyAmount'] as num?)?.toDouble(),
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
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
      'items': items.map((i) => i.toJson()).toList(),
      'discount': discount,
      'totalAmount': totalAmount,
      'notes': notes,
      'billImageUrl': billImageUrl,
      'billPdfUrl': billPdfUrl,
      'dailyAmount': dailyAmount,
      'remainingAmount': remainingAmount,
    };
  }
}
