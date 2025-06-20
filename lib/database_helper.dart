// file: lib/database_helper.dart

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/task_model.dart';
import 'models/user_model.dart';

class DatabaseHelper {
  static DatabaseHelper? _databaseHelper;
  static late PocketBase pb;
  static bool _isInitialized = false;

  final Map<String, Future<void> Function()> _userUnsubscribeFuncs = {};
  final Map<String, Future<void> Function()> _taskUnsubscribeFuncs = {};

  DatabaseHelper._createInstance();

  factory DatabaseHelper() {
    _databaseHelper ??= DatabaseHelper._createInstance();
    return _databaseHelper!;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = AsyncAuthStore(
        save: (String data) async => prefs.setString('pb_auth', data),
        initial: prefs.getString('pb_auth'),
      );
      pb = PocketBase('http://127.0.0.1:8090', authStore: store);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize PocketBase: $e');
    }
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<RecordModel> insertTaskWithRecord(String userId, Task task, String type) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) throw Exception('User not authenticated');
      
      final body = task.toMap();
      body['user_id'] = userId;
      body['type'] = type.toLowerCase();
      
      final record = await pb.collection('tasks').create(body: body);
      return record;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    await _ensureInitialized();
    try {
      final body = task.toMap();
      await pb.collection('tasks').update(task.id, body: body);
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) throw Exception('User not authenticated');
      await pb.collection('tasks').delete(taskId);
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }

  // === PERBAIKAN: Mengatasi error null safety pada parameter 'files' ===
  Future<RecordModel> updateUser(User user, {List<http.MultipartFile>? files}) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) throw Exception('User not authenticated');
      
      final body = user.toMap();
      
      // Menggunakan `files ?? []` untuk memberikan daftar kosong jika `files` bernilai null.
      final record = await pb.collection('users').update(user.id, body: body, files: files ?? []);
      return record;
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
  
  Future<void> deleteAccount(String userId) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) throw Exception('User not authenticated');
      await pb.collection('users').delete(userId);
      pb.authStore.clear();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<List<Task>> getTasksByType(
    String userId,
    String type, {
    int page = 1,
    int perPage = 20,
  }) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) throw Exception('User not authenticated');
      final result = await pb.collection('tasks').getList(
            page: page,
            perPage: perPage,
            filter: 'user_id = "$userId" && type = "$type"',
            sort: '-created',
          );
      
      final tasks = result.items.map((record) {
          final data = record.data;
          data['id'] = record.id;
          return Task.fromMap(data);
        }).toList();
        
      return tasks;
    } catch (e) {
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  Future<void> subscribeToUser(String userId, Function(User) onUpdate) async {
    await _ensureInitialized();
    await unsubscribeFromUser(userId); 

    try {
      final unsubscribe = await pb.collection('users').subscribe(userId, (event) {
        if (event.record != null) {
          final data = event.record!.data;
          data['id'] = event.record!.id;
          onUpdate(User.fromMap(data));
        }
      });
      _userUnsubscribeFuncs[userId] = unsubscribe;
    } catch(e) {
      print('Error subscribing to user $userId: $e');
    }
  }

  Future<void> subscribeToTasks(String userId, String type, Function(dynamic) onUpdate) async {
    await _ensureInitialized();
    final key = '$userId-$type';
    await unsubscribeFromTasks(userId, type);

    try {
      final unsubscribe = await pb.collection('tasks').subscribe('*', (event) {
         if (event.record != null && event.record!.data['user_id'] == userId) {
            onUpdate(event);
         }
      });
      _taskUnsubscribeFuncs[key] = unsubscribe;
    } catch(e) {
        print('Error subscribing to tasks with key $key: $e');
    }
  }

  Future<void> unsubscribeFromTasks(String userId, String type) async {
    final key = '$userId-$type';
    if (_taskUnsubscribeFuncs.containsKey(key)) {
      try {
        await _taskUnsubscribeFuncs[key]!();
        _taskUnsubscribeFuncs.remove(key);
      } catch (e) {
        print('Error unsubscribing from tasks $key: $e');
      }
    }
  }

  Future<void> unsubscribeFromUser(String userId) async {
    if (_userUnsubscribeFuncs.containsKey(userId)) {
      try {
        await _userUnsubscribeFuncs[userId]!();
        _userUnsubscribeFuncs.remove(userId);
      } catch (e) {
        print('Error unsubscribing from user $userId: $e');
      }
    }
  }

  static DatabaseHelper get instance => DatabaseHelper();
}
