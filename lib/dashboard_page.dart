// file: lib/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models/user_model.dart';
import 'models/task_model.dart';
import 'database_helper.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  User? _currentUser;
  List<Task> _habits = [];
  List<Task> _daily = [];
  List<Task> _todos = [];
  bool _isLoading = true;
  bool _isPageVisible = false;

  late TabController _tabController;
  
  late AnimationController _avatarAnimationController;
  late Animation<double> _avatarAnimation;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _avatarAnimation = CurvedAnimation(
      parent: _avatarAnimationController,
      curve: Curves.easeInOut,
    );
    _avatarAnimationController.forward();
  }

  Future<void> _loadData() async {
    try {
      await _refreshData();
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _refreshData() async {
     if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('currentUser');
    if (userJson == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final userData = jsonDecode(userJson);
      final user = User.fromMap(userData);
      final dbHelper = DatabaseHelper.instance;

      if (DatabaseHelper.pb.authStore.isValid) {
        await _checkAndResetDailies(user, prefs);

        final results = await Future.wait([
          dbHelper.getTasksByType(user.id, 'habits', perPage: 200),
          dbHelper.getTasksByType(user.id, 'daily', perPage: 200),
          dbHelper.getTasksByType(user.id, 'to-do', perPage: 200),
        ]);

        if (mounted) {
          setState(() {
            _currentUser = user;
            _habits = results[0];
            _daily = results[1];
            _todos = results[2];
            _isLoading = false;
          });
        }
      } else {
        await prefs.remove('currentUser');
        await prefs.remove('pb_auth');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error in _refreshData: $e');
       if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _checkAndResetDailies(User user, SharedPreferences prefs) async {
      final lastResetDate = prefs.getString('lastDailyReset_${user.id}') ?? '';
      final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (lastResetDate != currentDate) {
        final dailyTasksToReset = await DatabaseHelper.instance.getTasksByType(
          user.id, 'daily', page: 1, perPage: 1000);

        for (var task in dailyTasksToReset) {
          if (task.isCompleted) {
            task.isCompleted = false;
            task.completedAt = null;
            await DatabaseHelper.instance.updateTask(task);
          }
        }
        await prefs.setString('lastDailyReset_${user.id}', currentDate);
      }
  }

  void _manageSubscriptions(bool isVisible) {
    if (_currentUser == null) return;
    final dbHelper = DatabaseHelper.instance;

    if (!mounted) return;
    _isPageVisible = isVisible;

    if (isVisible) {
      dbHelper.subscribeToUser(_currentUser!.id, (user) {
        if (_isPageVisible && mounted) {
          setState(() => _currentUser = user);
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('currentUser', jsonEncode(user.toMap()));
          });
        }
      });
      dbHelper.subscribeToTasks(_currentUser!.id, '*', (e) async {
        if (_isPageVisible && mounted) {
           await _refreshData();
        }
      });
    } else {
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'habits');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'daily');
      dbHelper.unsubscribeFromTasks(_currentUser!.id, 'to-do');
      dbHelper.unsubscribeFromUser(_currentUser!.id);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        await _updateProfilePhoto(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  Future<void> _updateProfilePhoto(XFile image) async {
    if (_currentUser == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploading photo...')));
    }

    try {
      final bytes = await image.readAsBytes();
      final file = http.MultipartFile.fromBytes('profilePhoto', bytes, filename: image.name);

      final updatedRecord = await DatabaseHelper.pb.collection('users').update(_currentUser!.id, files: [file]);

      final updatedUser = User.fromRecord(updatedRecord);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(updatedUser.toMap()));
      
      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui foto: $e')),
        );
      }
    }
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () => _pickProfileImage(),
      child: AnimatedBuilder(
        animation: _avatarAnimation,
        builder: (context, child) {
          final avatarFrame = _currentUser?.avatarFrame;
          BoxDecoration frameDecoration;

          switch (avatarFrame) {
            case 'golden_frame':
              frameDecoration = BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.yellow[600]!, Colors.amber[700]!]),
                boxShadow: [BoxShadow(color: Colors.yellow.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
              );
              break;
            case 'rainbow_frame':
              frameDecoration = BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red]),
              );
              break;
            default:
              frameDecoration = BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), spreadRadius: 1, blurRadius: 3),
                  ],
              );
          }
          
          String? imageUrl;
          final photoFileName = _currentUser?.profilePhoto;

          if (photoFileName != null && photoFileName.isNotEmpty) {
            final recordId = _currentUser!.id;
            final collectionName = 'users';
            imageUrl = '${DatabaseHelper.pb.baseUrl}/api/files/$collectionName/$recordId/$photoFileName';
          }

          return Transform.scale(
            scale: _avatarAnimation.value * 0.1 + 0.95,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: frameDecoration,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepPurple[200],
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                child: imageUrl == null 
                  ? Icon(Icons.person, size: 24, color: Colors.white) 
                  : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addTask(String dbType, String title) async {
    if (_currentUser == null) return;
    try {
      final newTask = Task(
        id: '',
        title: title,
        userId: _currentUser!.id,
        type: dbType, 
        level: _currentUser!.level,
      );
      await DatabaseHelper.instance.insertTaskWithRecord(_currentUser!.id, newTask, dbType);
      await _refreshData();
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add task: $e')));
      }
    }
  }

  Future<void> _deleteTask(String dbType, int index) async {
     try {
       final taskList = dbType == 'habits' ? _habits : (dbType == 'daily' ? _daily : _todos);
       await DatabaseHelper.instance.deleteTask(taskList[index].id);
       await _refreshData();
     } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
        }
     }
  }

  Future<void> _toggleTaskCompletion(String dbType, int index) async {
    if (_currentUser == null) return;

    try {
      final taskList = dbType == 'habits' ? _habits : (dbType == 'daily' ? _daily : _todos);
      final task = taskList[index];

      if (task.isCompleted) { 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tugas sudah selesai!')));
        return; 
      }
      
      task.isCompleted = true;
      task.completedAt = DateTime.now();
      task.streakCount += 1; 
      
      int newXp = _currentUser!.xp + 5;
      int newLevel = _currentUser!.level;
      int newCoins = _currentUser!.coins + 10;

      if (newXp >= 100) {
        newLevel++;
        newXp -= 100;
        newCoins += 50; 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Naik Level! Anda mencapai Level $newLevel! (+50 Koin)')),
          );
        }
      }
      
      final updatedUser = _currentUser!.copyWith(
        coins: newCoins,
        level: newLevel,
        xp: newXp,
      );

      await Future.wait([
        DatabaseHelper.instance.updateUser(updatedUser),
        DatabaseHelper.instance.updateTask(task),
      ]);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(updatedUser.toMap()));
      
      await _refreshData();
      
    } catch (e) {
      print("Error toggling task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
  }

  void _showAddTaskDialog(String title, String dbType) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addTask(dbType, controller.text);
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
    _tabController.dispose();
    _avatarAnimationController.dispose();
    if (_currentUser != null) {
      DatabaseHelper.instance.unsubscribeFromTasks(_currentUser!.id, 'habits');
      DatabaseHelper.instance.unsubscribeFromTasks(_currentUser!.id, 'daily');
      DatabaseHelper.instance.unsubscribeFromTasks(_currentUser!.id, 'to-do');
      DatabaseHelper.instance.unsubscribeFromUser(_currentUser!.id);
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
              colors: [Color(0xFF8B5CF6), Color(0xFF4B0082)],
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      _buildDashboardHeader(),
                      TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white.withOpacity(0.7),
                        indicatorColor: Colors.yellow,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: 'Habits'),
                          Tab(text: 'Daily'),
                          Tab(text: 'To-do'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTaskListView('Habits', _habits, 'habits'),
                            _buildTaskListView('Daily', _daily, 'daily'),
                            _buildTaskListView('To-do', _todos, 'to-do'),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileAvatar(),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MyHabit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                if (_currentUser != null)
                  Text(
                    _currentUser!.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentUser?.xp ?? 0) / 100.0,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "${_currentUser?.xp ?? 0}/100",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, color: Colors.cyanAccent, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Level ${_currentUser?.level ?? 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentUser?.coins.toString() ?? '0',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.monetization_on, color: Colors.yellow, size: 16),
                    ],
                  ),
                ],
              ),
              SizedBox(width: 12),
              IconButton(
                tooltip: 'Toko',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.store, color: Colors.white, size: 28),
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/market');
                  if (result == true) {
                    await _refreshData();
                  }
                },
              ),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Lihat Profil',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.account_circle, color: Colors.white, size: 28),
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/profile');
                  if (result == true) {
                    await _refreshData();
                  }
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTaskListView(String title, List<Task> tasks, String dbType) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: tasks.length + 1, 
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GestureDetector(
              onTap: () => _showAddTaskDialog(title, dbType),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle, color: Colors.white),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Create new ${title.toLowerCase()}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          );
        }

        final taskIndex = index - 1;
        final task = tasks[taskIndex];
        return Dismissible(
          key: Key(task.id),
          onDismissed: (direction) => _deleteTask(dbType, taskIndex),
          background: Container(
            color: Colors.red,
            child: Icon(Icons.delete, color: Colors.white),
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
                  onTap: () => _toggleTaskCompletion(dbType, taskIndex),
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: task.isCompleted ? Colors.greenAccent : Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: Colors.white,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (task.streakCount > 0)
                        Text(
                          'Streak: ${task.streakCount}',
                          style: TextStyle(color: Colors.yellow, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () => _deleteTask(dbType, taskIndex),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
