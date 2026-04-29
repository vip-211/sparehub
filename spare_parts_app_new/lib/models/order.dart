class OrderItem {
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final int? minQty;
  final bool isLocked;
  final int? bannerId;
  final int? offerId;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.minQty,
    this.isLocked = false,
    this.bannerId,
    this.offerId,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'],
      productName: json['productName'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      minQty: (json['minQty'] as num?)?.toInt(),
      isLocked: json['isLocked'] ?? false,
      bannerId: json['bannerId'],
      offerId: json['offerId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'minQty': minQty,
      'isLocked': isLocked,
      'bannerId': bannerId,
      'offerId': offerId,
    };
  }
}

class Order {
  final int id;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final int sellerId;
  final String sellerName;
  final double totalAmount;
  final String status;
  final List<OrderItem> items;
  final String createdAt;
  final double? latitude;
  final double? longitude;
  final String? deliveredBy;
  final String? deliveredAt;
  final int pointsRedeemed;
  final int pointsEarned;

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.sellerId,
    required this.sellerName,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.deliveredBy,
    this.deliveredAt,
    this.pointsRedeemed = 0,
    this.pointsEarned = 0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final itemsList = itemsRaw is List
        ? itemsRaw
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList()
        : <OrderItem>[];
    final createdAtVal = json['createdAt'];
    final createdAtStr = createdAtVal is String
        ? createdAtVal
        : (createdAtVal != null
            ? createdAtVal.toString()
            : DateTime.now().toIso8601String());
    return Order(
      id: (json['id'] as num).toInt(),
      customerId: (json['customerId'] as num).toInt(),
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'],
      sellerId: (json['sellerId'] as num?)?.toInt() ?? 0,
      sellerName: json['sellerName'] ?? '',
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: json['status']?.toString() ?? 'PENDING',
      items: itemsList,
      createdAt: createdAtStr,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      deliveredBy: json['deliveredBy'],
      deliveredAt: json['deliveredAt'],
      pointsRedeemed: (json['pointsRedeemed'] as num? ?? 0).toInt(),
      pointsEarned: (json['pointsEarned'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'totalAmount': totalAmount,
      'status': status,
      'items': items.map((i) => i.toJson()).toList(),
      'createdAt': createdAt,
      'latitude': latitude,
      'longitude': longitude,
      'deliveredBy': deliveredBy,
      'deliveredAt': deliveredAt,
    };
  }
}
