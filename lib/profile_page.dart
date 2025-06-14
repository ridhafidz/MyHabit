import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/user_model.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  User? _currentUser;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('currentUser');
      if (userJson == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final userData = jsonDecode(userJson);
      final user = User.fromJson(userData);
      setState(() {
        _currentUser = user;
        _animationController.forward(from: 0.0); // Trigger animation on update
      });
    } catch (e) {
      print('Error loading user: $e');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _currentUser?.background == 'gold'
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
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _animation.value * 1.1 + 0.9,
                            child: CircleAvatar(
                              radius: 50,
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
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Name: ${_currentUser!.name}',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Email: ${_currentUser!.email}',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Coins: ${_currentUser!.coins}',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8B5CF6),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Back to Dashboard',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}