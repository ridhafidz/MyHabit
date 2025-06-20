// file: lib/models/user_model.dart

import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

class User {
  final String id;
  final String name;
  final String email;
  final int coins;
  final int level;
  final int xp; // Field baru untuk Experience Points
  final String avatar;
  final String background;
  final String? profilePhoto;
  final List<String> purchasedItems;
  final String? profileAnimation;
  final String? soundPack;
  final String? profileMusic;
  final String? chartTheme;
  final String? progressBar;
  final String? titleRank;
  final String? profileTheme;
  final String? avatarFrame;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.coins,
    required this.level,
    required this.xp, // Ditambahkan ke constructor
    required this.avatar,
    required this.background,
    this.profilePhoto,
    required this.purchasedItems,
    this.profileAnimation,
    this.soundPack,
    this.profileMusic,
    this.chartTheme,
    this.progressBar,
    this.titleRank,
    this.profileTheme,
    this.avatarFrame,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    int? coins,
    int? level,
    int? xp, // Ditambahkan ke copyWith
    String? avatar,
    String? background,
    String? profilePhoto,
    List<String>? purchasedItems,
    String? profileAnimation,
    String? soundPack,
    String? profileMusic,
    String? chartTheme,
    String? progressBar,
    String? titleRank,
    String? profileTheme,
    String? avatarFrame,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      coins: coins ?? this.coins,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      avatar: avatar ?? this.avatar,
      background: background ?? this.background,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      purchasedItems: purchasedItems ?? this.purchasedItems,
      profileAnimation: profileAnimation ?? this.profileAnimation,
      soundPack: soundPack ?? this.soundPack,
      profileMusic: profileMusic ?? this.profileMusic,
      chartTheme: chartTheme ?? this.chartTheme,
      progressBar: progressBar ?? this.progressBar,
      titleRank: titleRank ?? this.titleRank,
      profileTheme: profileTheme ?? this.profileTheme,
      avatarFrame: avatarFrame ?? this.avatarFrame,
    );
  }

  factory User.fromRecord(RecordModel record) {
    final data = record.data;
    return User(
      id: record.id,
      name: data['name'] ?? 'Player',
      email: data['email'] ?? '',
      coins: data['coins'] ?? 0,
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0, // Membaca data XP
      avatar: data['avatar'] ?? 'default',
      background: data['background'] ?? 'default',
      profilePhoto: data['profilePhoto'],
      purchasedItems: List<String>.from(data['purchasedItems'] ?? []),
      profileAnimation: data['profileAnimation'],
      soundPack: data['soundPack'],
      profileMusic: data['profileMusic'],
      chartTheme: data['chartTheme'],
      progressBar: data['progressBar'],
      titleRank: data['titleRank'],
      profileTheme: data['profileTheme'],
      avatarFrame: data['avatarFrame'],
    );
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Player',
      email: map['email'] ?? '',
      coins: map['coins'] ?? 0,
      level: map['level'] ?? 1,
      xp: map['xp'] ?? 0, // Membaca data XP
      avatar: map['avatar'] ?? 'default',
      background: map['background'] ?? 'default',
      profilePhoto: map['profilePhoto'],
      purchasedItems: List<String>.from(map['purchasedItems'] ?? []),
      profileAnimation: map['profileAnimation'],
      soundPack: map['soundPack'],
      profileMusic: map['profileMusic'],
      chartTheme: map['chartTheme'],
      progressBar: map['progressBar'],
      titleRank: map['titleRank'],
      profileTheme: map['profileTheme'],
      avatarFrame: map['avatarFrame'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'coins': coins,
      'level': level,
      'xp': xp, // Menyimpan data XP
      'avatar': avatar,
      'background': background,
      'profilePhoto': profilePhoto,
      'purchasedItems': purchasedItems,
      'profileAnimation': profileAnimation,
      'soundPack': soundPack,
      'profileMusic': profileMusic,
      'chartTheme': chartTheme,
      'progressBar': progressBar,
      'titleRank': titleRank,
      'profileTheme': profileTheme,
      'avatarFrame': avatarFrame,
    };
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) => User.fromMap(json.decode(source));
}
