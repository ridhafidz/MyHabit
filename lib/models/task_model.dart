class Task {
  String id;
  String userId;
  String title;
  bool isCompleted;
  DateTime? completedAt; // New field for completion timestamp
  String type;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.isCompleted,
    this.completedAt,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'type': type,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      type: map['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Task.fromJson(Map<String, dynamic> json) => Task.fromMap(json);
}