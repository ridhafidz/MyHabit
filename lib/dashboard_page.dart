import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'models/user_model.dart';
import 'models/task_model.dart';
import 'database_helper.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  User? _currentUser;
  List<Task> _habits = [];
  List<Task> _daily = [];
  List<Task> _todos = [];
  int _habitsPage = 1;
  int _dailyPage = 1;
  int _todosPage = 1;
  bool _hasMoreHabits = true;
  bool _hasMoreDaily = true;
  bool _hasMoreTodos = true;
  bool _isPageVisible = false;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _avatarAnimationController;
  late Animation<double> _avatarAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _avatarAnimation = CurvedAnimation(parent: _avatarAnimationController, curve: Curves.easeInOut);
    _avatarAnimationController.forward();
  }

  Future<void> _loadData() async {
    try {
      await _refreshData();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _currentUser = null;
        _habits = [];
        _daily = [];
        _todos = [];
      });
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _refreshData({bool loadMore = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('currentUser');
    if (userJson == null) {
      setState(() {
        _currentUser = null;
        _habits = [];
        _daily = [];
        _todos = [];
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final userData = jsonDecode(userJson);
      final user = User.fromMap(userData);
      final dbHelper = DatabaseHelper.instance;

      if (DatabaseHelper.pb.authStore.isValid) {
        setState(() {
          _currentUser = user;
          _avatarAnimationController.forward(from: 0.0);
        });

        final lastResetDate = prefs.getString('lastDailyReset_${user.id}') ?? '';
        final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (lastResetDate != currentDate) {
          final dailyTasks = await dbHelper.getTasksByType(
            user.id,
            'daily',
            page: 1,
            perPage: 100,
          );
          for (var task in dailyTasks) {
            task.isCompleted = false;
            task.completedAt = null;
            await dbHelper.updateTask(task);
          }
          await prefs.setString('lastDailyReset_${user.id}', currentDate);
          print('Daily tasks reset for user ${user.id} on $currentDate');
        }

        final newHabits = await dbHelper.getTasksByType(
          user.id,
          'habits',
          page: _habitsPage,
          perPage: 20,
        );
        final newDaily = await dbHelper.getTasksByType(
          user.id,
          'daily',
          page: _dailyPage,
          perPage: 20,
        );
        final newTodos = await dbHelper.getTasksByType(
          user.id,
          'todos',
          page: _todosPage,
          perPage: 20,
        );

        setState(() {
          if (loadMore) {
            _habits.addAll(newHabits);
            _daily.addAll(newDaily);
            _todos.addAll(newTodos);
          } else {
            _habits = newHabits;
            _daily = newDaily;
            _todos = newTodos;
          }
          _hasMoreHabits = newHabits.length == 20;
          _hasMoreDaily = newDaily.length == 20;
          _hasMoreTodos = newTodos.length == 20;
        });
      } else {
        await prefs.remove('currentUser');
        await prefs.remove('pb_auth');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error in _refreshData: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      setState(() {
        _currentUser = null;
        _habits = [];
        _daily = [];
        _todos = [];
      });
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreHabits || _hasMoreDaily || _hasMoreTodos) {
        setState(() {
          if (_hasMoreHabits) _habitsPage++;
          if (_hasMoreDaily) _dailyPage++;
          if (_hasMoreTodos) _todosPage++;
        });
        _refreshData(loadMore: true);
      }
    }
  }

  void _manageSubscriptions(bool isVisible) {
    if (_currentUser == null) return;
    final dbHelper = DatabaseHelper.instance;

    setState(() {
      _isPageVisible = isVisible;
    });

    if (isVisible) {
      print('Subscribing to user and tasks for user ${_currentUser!.id}');
      dbHelper.subscribeToUser(_currentUser!.id, (user) {
        if (_isPageVisible) {
          print(
            'Before subscription update: local coins=${_currentUser!.coins}, subscription coins=${user.coins}',
          );
          setState(() {
            _currentUser = user;
            _avatarAnimationController.forward(from: 0.0);
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('currentUser', jsonEncode(user.toMap()));
            });
          });
        }
      });
      dbHelper.subscribeToTasks(_currentUser!.id, 'habits', (tasks) {
        if (_isPageVisible) {
          setState(() {
            _habits = tasks;
            _habitsPage = 1;
            _hasMoreHabits = tasks.length == 20;
          });
        }
      });
      dbHelper.subscribeToTasks(_currentUser!.id, 'daily', (tasks) {
        if (_isPageVisible) {
          setState(() {
            _daily = tasks;
            _dailyPage = 1;
            _hasMoreDaily = tasks.length == 20;
          });
        }
      });
      dbHelper.subscribeToTasks(_currentUser!.id, 'todos', (tasks) {
        if (_isPageVisible) {
          setState(() {
            _todos = tasks;
            _todosPage = 1;
            _hasMoreTodos = tasks.length == 20;
          });
        }
      });
    } else {
      print('Unsubscribing from user and tasks for user ${_currentUser!.id}');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'habits');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'daily');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'todos');
      dbHelper.unsubscribeFromUser(_currentUser!.id);
    }
  }

  Future<void> _addTask(String type, String title) async {
    if (_currentUser == null || _currentUser!.id.isEmpty) {
      print('No user logged in');
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    final newTask = Task(
      id: '',
      title: title,
      isCompleted: false,
      userId: _currentUser!.id,
      type: type,
    );

    try {
      print(
        'Inserting task: type=$type, title=$title, userId=${_currentUser!.id}',
      );
      await dbHelper.insertTask(_currentUser!.id, newTask, type.toLowerCase());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task added successfully')));
    } catch (e) {
      print('Error adding task: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add task: $e')));
    }
  }

  Future<void> _deleteTask(String type, int index) async {
    if (_currentUser == null || _currentUser!.id.isEmpty) return;

    final dbHelper = DatabaseHelper.instance;
    try {
      final task =
          type == 'habits'
              ? _habits[index]
              : type == 'daily'
              ? _daily[index]
              : _todos[index];
      await dbHelper.deleteTask(task.id);
    } catch (e) {
      print('Error deleting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
    }
  }

  Future<void> _toggleTaskCompletion(String type, int index) async {
    if (_currentUser == null || _currentUser!.id.isEmpty) {
      print('No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please log in to update tasks')));
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    try {
      final task =
          type == 'habits'
              ? _habits[index]
              : type == 'daily'
              ? _daily[index]
              : _todos[index];

      print(
        'Before toggle: Task=${task.title}, isCompleted=${task.isCompleted}, '
        'completedAt=${task.completedAt}, User coins=${_currentUser!.coins}',
      );

      if (task.isCompleted) {
        final now = DateTime.now();
        final completedDate = task.completedAt;
        if (completedDate != null) {
          final isSameDay =
              now.year == completedDate.year &&
              now.month == completedDate.month &&
              now.day == completedDate.day;
          if (isSameDay) {
            print(
              'Cannot uncomplete task on the same day: completedAt=$completedDate',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot uncomplete task until tomorrow')),
            );
            return;
          }
        }
      }

      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;

      if (task.isCompleted) {
        final newCoinCount = _currentUser!.coins + 10;
        print('Awarding 10 coins: ${_currentUser!.coins} -> $newCoinCount');

        final updatedUser = User(
          id: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          password: _currentUser!.password,
          coins: newCoinCount,
          avatar: _currentUser!.avatar,
          background: _currentUser!.background,
          profilePhoto: _currentUser!.profilePhoto,
          purchasedItems: _currentUser!.purchasedItems,
        );

        await dbHelper.updateUser(updatedUser);
        print('User updated in database: coins=$newCoinCount');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUser', jsonEncode(updatedUser.toMap()));
        print('SharedPreferences updated: coins=$newCoinCount');

        setState(() {
          _currentUser = updatedUser;
          _avatarAnimationController.forward(from: 0.0);
        });
      }

      await dbHelper.updateTask(task);
      print(
        'Task updated in database: isCompleted=${task.isCompleted}, '
        'completedAt=${task.completedAt}',
      );

      setState(() {
        if (type == 'habits') {
          _habits[index] = task;
        } else if (type == 'daily') {
          _daily[index] = task;
        } else {
          _todos[index] = task;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task updated successfully')));
    } catch (e) {
      print('Error in toggleTaskCompletion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task or coins: $e')),
      );
    }
  }

  void _showAddTaskDialog(String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $type'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addTask(type.toLowerCase(), controller.text);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _avatarAnimationController.dispose();
    if (_currentUser != null) {
      final dbHelper = DatabaseHelper.instance;
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'habits');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'daily');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'todos');
      dbHelper.unsubscribeFromUser(_currentUser!.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VisibilityDetector(
        key: Key('dashboard-visibility'),
        onVisibilityChanged: (info) {
          _manageSubscriptions(info.visibleFraction > 0);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  _currentUser?.background == 'gold'
                      ? [Colors.yellow, Colors.orange]
                      : [Color(0xFF8B5CF6), Color(0xFF4B0082)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _currentUser == null
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/profile');
                              },
                              child: AnimatedBuilder(
                                animation: _avatarAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _avatarAnimation.value * 1.1 + 0.9,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white,
                                      backgroundImage: _currentUser!.avatar.startsWith('http')
                                          ? NetworkImage(_currentUser!.avatar)
                                          : null,
                                      onBackgroundImageError: _currentUser!.avatar.startsWith('http')
                                          ? (exception, stackTrace) {
                                              print('Image load error: $exception');
                                            }
                                          : null,
                                      child: _currentUser!.avatar.startsWith('http') ? null : Icon(
                                        Icons.person,
                                        color: _currentUser!.avatar == 'star' ? Colors.yellow : Colors.purple,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MyHabit',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _currentUser?.name ?? 'Player',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.settings, color: Colors.white),
                              onPressed: () {
                                Navigator.pushNamed(context, '/settings');
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.store, color: Colors.white),
                              onPressed: () async {
                                final result = await Navigator.pushNamed(
                                  context,
                                  '/market',
                                );
                                if (result == true) {
                                  await _refreshData();
                                }
                              },
                            ),
                            Text(
                              _currentUser?.coins.toString() ?? '0',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 16,
                              ),
                            ),
                            Icon(Icons.monetization_on, color: Colors.yellow),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Habits',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '+ ${_habits.length} Tasks',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            controller: _scrollController,
                            children: [
                              GestureDetector(
                                onTap: () => _showAddTaskDialog('Habits'),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          'Create new habit',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ..._habits.asMap().entries.map((entry) {
                                final index = entry.key;
                                final task = entry.value;
                                return Dismissible(
                                  key: Key(task.id),
                                  onDismissed: (direction) => _deleteTask('habits', index),
                                  background: Container(
                                    color: Colors.red,
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 16),
                                  ),
                                  child: Container(
                                    margin: EdgeInsets.only(top: 8),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleTaskCompletion('habits', index),
                                          child: Icon(
                                            task.isCompleted
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              color: Colors.white,
                                              decoration: task.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteTask('habits', index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (_hasMoreHabits)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              SizedBox(height: 16),
                              Text(
                                'Daily',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => _showAddTaskDialog('Daily'),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          'Add daily task',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ..._daily.asMap().entries.map((entry) {
                                final index = entry.key;
                                final task = entry.value;
                                return Dismissible(
                                  key: Key(task.id),
                                  onDismissed: (direction) => _deleteTask('daily', index),
                                  background: Container(
                                    color: Colors.red,
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 16),
                                  ),
                                  child: Container(
                                    margin: EdgeInsets.only(top: 8),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleTaskCompletion('daily', index),
                                          child: Icon(
                                            task.isCompleted
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              color: Colors.white,
                                              decoration: task.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteTask('daily', index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (_hasMoreDaily)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              SizedBox(height: 16),
                              Text(
                                'To-do',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => _showAddTaskDialog('Todos'),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          'Add to-do',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ..._todos.asMap().entries.map((entry) {
                                final index = entry.key;
                                final task = entry.value;
                                return Dismissible(
                                  key: Key(task.id),
                                  onDismissed: (direction) => _deleteTask('todos', index),
                                  background: Container(
                                    color: Colors.red,
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 16),
                                  ),
                                  child: Container(
                                    margin: EdgeInsets.only(top: 8),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleTaskCompletion('todos', index),
                                          child: Icon(
                                            task.isCompleted
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              color: Colors.white,
                                              decoration: task.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteTask('todos', index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (_hasMoreTodos)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}