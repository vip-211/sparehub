class User {
  final int id;
  final String email;
  final String? name;
  final String? phone;
  final String token;
  final List<String> roles;
  final String? address;
  final String? shopImagePath;
  final String? status;
  final bool phoneVerified;
  final double? latitude;
  final double? longitude;

  User({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    required this.token,
    required this.roles,
    this.address,
    this.shopImagePath,
    this.status,
    this.phoneVerified = false,
    this.latitude,
    this.longitude,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      name: json['name'],
      phone: json['phone'],
      token: json['token'] as String,
      roles: (json['roles'] as List).map((e) => e.toString()).toList(),
      address: json['address'],
      shopImagePath: json['shopImagePath'],
      status: json['status'],
      phoneVerified: json['phoneVerified'] == true || json['phone_verified'] == 1,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'token': token,
      'roles': roles,
      'address': address,
      'shopImagePath': shopImagePath,
      'status': status,
      'phoneVerified': phoneVerified,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
