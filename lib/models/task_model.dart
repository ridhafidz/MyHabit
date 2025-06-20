// file: lib/models/task_model.dart

import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

class Task {
  String id;
  String userId;
  String title;
  bool isCompleted;
  DateTime? completedAt;
  String type;
  int streakCount;
  List<String> achievementBadges;
  int level;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    required this.type,
    this.streakCount = 0,
    this.achievementBadges = const [],
    required this.level,
  });

  // PERBAIKAN: Memastikan toMap tidak mengirim ID saat membuat record baru.
  // ID dibuat oleh database, bukan oleh aplikasi.
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'type': type,
      'streakCount': streakCount,
      'achievementBadges': achievementBadges,
      'level': level,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      // Menambahkan pengecekan .isNotEmpty untuk keamanan tambahan
      completedAt:
          map['completedAt'] != null && map['completedAt'].isNotEmpty
              ? DateTime.parse(map['completedAt'])
              : null,
      type: map['type'] ?? '',
      streakCount: (map['streakCount'] ?? 0).toInt(),
      achievementBadges: List<String>.from(map['achievementBadges'] ?? []),
      level: (map['level'] ?? 1).toInt(),
    );
  }

  // PERBAIKAN: Menambahkan factory fromRecord untuk konsistensi
  factory Task.fromRecord(RecordModel record) {
    final data = record.data;
    // Menambahkan ID dari record ke dalam map sebelum membuat objek Task
    data['id'] = record.id;
    return Task.fromMap(data);
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}
