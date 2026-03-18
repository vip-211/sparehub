class Category {
  final int id;
  final String name;
  final String? description;
  final String? imagePath;
  final String? imageLink;
  final bool deleted;
  final int? parentId;
  final List<Category> subCategories;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.imagePath,
    this.imageLink,
    this.deleted = false,
    this.parentId,
    this.subCategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is int ? json['id'] : (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      imagePath: json['imagePath'],
      imageLink: json['imageLink'],
      deleted: json['deleted'] == true || json['deleted'] == 1,
      parentId: json['parent'] != null
          ? (json['parent']['id'] as num?)?.toInt()
          : (json['parentId'] as num?)?.toInt(),
      subCategories: json['subCategories'] != null
          ? (json['subCategories'] as List)
              .map((e) => Category.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'imageLink': imageLink,
      'deleted': deleted,
      'parentId': parentId,
      'subCategories': subCategories.map((e) => e.toJson()).toList(),
    };
  }
}
