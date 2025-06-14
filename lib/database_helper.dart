import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/task_model.dart';
import 'models/user_model.dart';

class DatabaseHelper {
  static DatabaseHelper? _databaseHelper;
  static late PocketBase pb;
  static bool _isInitialized = false;
  final Map<String, void Function(RecordSubscriptionEvent)> _userCallbacks = {};
  final Map<String, void Function(RecordSubscriptionEvent)> _taskCallbacks = {};

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
      print('DatabaseHelper initialized successfully');
    } catch (e) {
      print('Error initializing DatabaseHelper: $e');
      throw Exception('Failed to initialize PocketBase: $e');
    }
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<String> insertTask(String userId, Task task, String type) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) {
        throw Exception('User not authenticated');
      }
      final body = {
        'user_id': userId,
        'title': task.title,
        'isCompleted': task.isCompleted,
        'completedAt': task.completedAt?.toIso8601String(),
        'type': type.toLowerCase(),
      };
      print('Inserting task with body: $body');
      final record = await pb.collection('tasks').create(body: body);
      return record.id;
    } catch (e) {
      print('Error inserting task: $e');
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    await _ensureInitialized();
    try {
      final body = {
        'title': task.title,
        'isCompleted': task.isCompleted,
        'completedAt': task.completedAt?.toIso8601String(),
        'type': task.type,
      };
      print('Updating task with body: $body');
      await pb.collection('tasks').update(task.id, body: body);
      print('Task updated successfully: id=${task.id}');
    } catch (e) {
      print('Error updating task: $e');
      throw Exception('Failed to update task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) {
        throw Exception('User not authenticated');
      }
      print('Deleting task: id=$taskId');
      await pb.collection('tasks').delete(taskId);
      print('Task deleted successfully: id=$taskId');
    } catch (e) {
      print('Error deleting task: $e');
      throw Exception('Failed to delete task: $e');
    }
  }

  Future<void> updateUser(User user) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) {
        throw Exception('User not authenticated');
      }
      final body = {
        'name': user.name,
        'email': user.email,
        'coins': user.coins,
        'avatar': user.avatar,
        'background': user.background,
        'purchasedItems': jsonEncode(user.purchasedItems),
      };
      print('Sending updateUser request: id=${user.id}, body=$body');
      final record = await pb.collection('users').update(user.id, body: body);
      print(
        'updateUser response: id=${record.id}, coins=${record.data['coins']}',
      );
    } catch (e) {
      print('Error in updateUser: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteAccount(String userId) async {
    await _ensureInitialized();
    try {
      if (!pb.authStore.isValid) {
        throw Exception('User not authenticated');
      }
      print('Deleting user account: id=$userId');
      await pb.collection('users').delete(userId);
      pb.authStore.clear();
      print('User account deleted and auth cleared: id=$userId');
    } catch (e) {
      print('Error deleting account: $e');
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
      if (!pb.authStore.isValid) {
        throw Exception('User not authenticated');
      }
      final result = await pb
          .collection('tasks')
          .getList(
            page: page,
            perPage: perPage,
            filter: 'user_id = "$userId" && type = "$type"',
            sort: '-created',
          );
      final tasks =
          result.items.map((record) {
            return Task.fromMap({'id': record.id, ...record.data});
          }).toList();
      print('Fetched tasks: type=$type, userId=$userId, count=${tasks.length}');
      return tasks;
    } catch (e) {
      print('Error fetching tasks: type=$type, error=$e');
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  void subscribeToUser(String userId, Function(User) onUpdate) {
    _userCallbacks[userId] = (RecordSubscriptionEvent event) async {
      await _ensureInitialized();
      try {
        if (event.record == null) {
          print('Subscription event with null record for user $userId');
          return;
        }
        print(
          'Subscription event received: action=${event.action}, record=${event.record!.toJson()}',
        );
        final user = User.fromJson({
          'id': event.record!.id,
          ...event.record!.data,
          'profilePhoto':
              event.record!.data['profilePhoto'] != null
                  ? pb
                      .getFileUrl(
                        event.record!,
                        event.record!.data['profilePhoto'],
                      )
                      .toString()
                  : null,
        });
        print(
          'Subscription update for user ${user.id}: coins=${user.coins}, purchasedItems=${user.purchasedItems}',
        );
        onUpdate(user);
      } catch (e) {
        print(
          'Error in subscribeToUser callback: $e, record data=${event.record?.data}',
        );
        // Attempt to reconnect
        unsubscribeFromUser(userId);
        Future.delayed(Duration(seconds: 5), () {
          if (_userCallbacks.containsKey(userId)) {
            print('Re-subscribing to user $userId after error');
            subscribeToUser(userId, onUpdate);
          }
        });
      }
    };

    try {
      pb.collection('users').subscribe(userId, _userCallbacks[userId]!);
    } catch (e) {
      print('Error subscribing to user $userId: $e');
      Future.delayed(Duration(seconds: 5), () {
        if (_userCallbacks.containsKey(userId)) {
          print('Retrying subscription to user $userId');
          subscribeToUser(userId, onUpdate);
        }
      });
    }
  }

  Future<void> subscribeToTasks(
    String userId,
    String type,
    Function(List<Task>) onUpdate,
  ) async {
    await _ensureInitialized();
    final key = '$userId-$type';
    _taskCallbacks[key] = (RecordSubscriptionEvent event) async {
      try {
        final records = await pb
            .collection('tasks')
            .getList(
              filter: 'user_id = "$userId" && type = "$type"',
              sort: '-created',
            );
        final tasks =
            records.items
                .map(
                  (record) => Task.fromMap({'id': record.id, ...record.data}),
                )
                .toList();
        print(
          'Subscription update for tasks: type=$type, count=${tasks.length}',
        );
        onUpdate(tasks);
      } catch (e) {
        print('Error in subscribeToTasks callback: $e');
        // Attempt to reconnect
        unsubscribeFromTasks(userId, type);
        Future.delayed(Duration(seconds: 5), () {
          if (_taskCallbacks.containsKey(key)) {
            print('Re-subscribing to tasks $key after error');
            subscribeToTasks(userId, type, onUpdate);
          }
        });
      }
    };

    try {
      pb.collection('tasks').subscribe('*', _taskCallbacks[key]!);
    } catch (e) {
      print('Error subscribing to tasks $key: $e');
      Future.delayed(Duration(seconds: 5), () {
        if (_taskCallbacks.containsKey(key)) {
          print('Retrying subscription to tasks $key');
          subscribeToTasks(userId, type, onUpdate);
        }
      });
    }
  }

  void unsubscribeFromTasks(String userId, String type) {
    final key = '$userId-$type';
    if (_taskCallbacks.containsKey(key)) {
      try {
        pb.collection('tasks').unsubscribe();
        _taskCallbacks.remove(key);
        print('Unsubscribed from tasks: $key');
      } catch (e) {
        print('Error unsubscribing from tasks $key: $e');
      }
    }
  }

  void unsubscribeFromUser(String userId) {
    if (_userCallbacks.containsKey(userId)) {
      try {
        pb.collection('users').unsubscribe(userId);
        _userCallbacks.remove(userId);
        print('Unsubscribed from user: $userId');
      } catch (e) {
        print('Error unsubscribing from user $userId: $e');
      }
    }
  }

  static DatabaseHelper get instance => DatabaseHelper();
}
