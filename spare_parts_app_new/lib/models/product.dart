class Product {
  final int id;
  final String name;
  final String partNumber;
  final String? rackNumber;
  final double mrp;
  final double sellingPrice; // General/Default price
  final double wholesalerPrice;
  final double retailerPrice;
  final double mechanicPrice;
  final int stock;
  final int wholesalerId;
  final String? imagePath;
  final String? imageLink;
  final String? description;
  final bool enabled;
  final int? categoryId;
  final String? categoryName;
  final String? categoryImagePath;
  final String? categoryImageLink;

  Product({
    required this.id,
    required this.name,
    required this.partNumber,
    this.rackNumber,
    required this.mrp,
    required this.sellingPrice,
    required this.wholesalerPrice,
    required this.retailerPrice,
    required this.mechanicPrice,
    required this.stock,
    required this.wholesalerId,
    this.imagePath,
    this.imageLink,
    this.description,
    this.enabled = true,
    this.categoryId,
    this.categoryName,
    this.categoryImagePath,
    this.categoryImageLink,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      partNumber: json['partNumber'] ?? '',
      rackNumber: json['rackNumber'],
      mrp: (json['mrp'] as num? ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] as num? ?? 0).toDouble(),
      wholesalerPrice:
          (json['wholesalerPrice'] as num? ?? json['sellingPrice'] as num? ?? 0)
              .toDouble(),
      retailerPrice:
          (json['retailerPrice'] as num? ?? json['sellingPrice'] as num? ?? 0)
              .toDouble(),
      mechanicPrice:
          (json['mechanicPrice'] as num? ?? json['sellingPrice'] as num? ?? 0)
              .toDouble(),
      stock: json['stock'] ?? 0,
      wholesalerId: json['wholesalerId'] ?? 0,
      imagePath: json['imagePath'],
      imageLink: json['imageLink'],
      description: json['description'],
      enabled: json['enabled'] is bool
          ? json['enabled']
          : (json['enabled'] ?? 1) == 1,
      categoryId: json['categoryId'] is int
          ? json['categoryId']
          : (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName'],
      categoryImagePath: json['categoryImagePath'],
      categoryImageLink: json['categoryImageLink'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'partNumber': partNumber,
      'rackNumber': rackNumber,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'wholesalerPrice': wholesalerPrice,
      'retailerPrice': retailerPrice,
      'mechanicPrice': mechanicPrice,
      'stock': stock,
      'wholesalerId': wholesalerId,
      'imagePath': imagePath,
      'imageLink': imageLink,
      'description': description,
      'enabled': enabled ? 1 : 0,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryImagePath': categoryImagePath,
      'categoryImageLink': categoryImageLink,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? partNumber,
    String? rackNumber,
    double? mrp,
    double? sellingPrice,
    double? wholesalerPrice,
    double? retailerPrice,
    double? mechanicPrice,
    int? stock,
    int? wholesalerId,
    String? imagePath,
    String? description,
    bool? enabled,
    int? categoryId,
    String? categoryName,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      partNumber: partNumber ?? this.partNumber,
      rackNumber: rackNumber ?? this.rackNumber,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalerPrice: wholesalerPrice ?? this.wholesalerPrice,
      retailerPrice: retailerPrice ?? this.retailerPrice,
      mechanicPrice: mechanicPrice ?? this.mechanicPrice,
      stock: stock ?? this.stock,
      wholesalerId: wholesalerId ?? this.wholesalerId,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}
