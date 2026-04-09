class Category {
  final int id;
  final String name;
  final String? description;
  final String? imagePath;
  final String? imageLink;
  final int displayOrder;
  final int? iconCodePoint;
  final bool showOnHome;
  final bool deleted;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.imagePath,
    this.imageLink,
    this.displayOrder = 0,
    this.iconCodePoint,
    this.showOnHome = true,
    this.deleted = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is int ? json['id'] : (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      imagePath: json['imagePath'],
      imageLink: json['imageLink'],
      displayOrder: (json['displayOrder'] as num? ?? 0).toInt(),
      iconCodePoint: json['iconCodePoint'] != null ? (json['iconCodePoint'] as num).toInt() : null,
      showOnHome: json['showOnHome'] == true || json['showOnHome'] == 1,
      deleted: json['deleted'] == true || json['deleted'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'imageLink': imageLink,
      'displayOrder': displayOrder,
      'iconCodePoint': iconCodePoint,
      'showOnHome': showOnHome ? 1 : 0,
      'deleted': deleted,
    };
  }
}
