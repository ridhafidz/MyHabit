import 'dart:convert';

class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final int coins;
  final String avatar;
  final String background;
  final String? profilePhoto;
  final List<String>? purchasedItems;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password = '',
    required this.coins,
    required this.avatar,
    required this.background,
    this.profilePhoto,
    this.purchasedItems,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      coins: (json['coins'] ?? 0).toInt(),
      avatar: json['avatar'] ?? 'default',
      background: json['background'] ?? 'default',
      profilePhoto: json['profilePhoto'],
      purchasedItems: json['purchasedItems'] != null
          ? (json['purchasedItems'] is String
              ? List<String>.from(jsonDecode(json['purchasedItems']))
              : List<String>.from(json['purchasedItems']))
          : [],
    );
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      coins: (map['coins'] ?? 0).toInt(),
      avatar: map['avatar'] ?? 'default',
      background: map['background'] ?? 'default',
      profilePhoto: map['profilePhoto'],
      purchasedItems: map['purchasedItems'] != null
          ? (map['purchasedItems'] is String
              ? List<String>.from(jsonDecode(map['purchasedItems']))
              : List<String>.from(map['purchasedItems']))
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'coins': coins,
      'avatar': avatar,
      'background': background,
      'profilePhoto': profilePhoto,
      'purchasedItems': purchasedItems != null ? jsonEncode(purchasedItems) : [],
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'coins': coins,
      'avatar': avatar,
      'background': background,
      'profilePhoto': profilePhoto,
      'purchasedItems': purchasedItems,
    };
  }
}