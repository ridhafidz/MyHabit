import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'database_helper.dart';
import 'package:pocketbase/pocketbase.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isPasswordVisible = false;

  Future<void> _login(BuildContext context) async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please fill in all fields';
        });
        return;
      }

      if (!_emailController.text.contains('@') ||
          !_emailController.text.contains('.')) {
        setState(() {
          _errorMessage = 'Please enter a valid email';
        });
        return;
      }

      print('Attempting login for email: ${_emailController.text}');
      final authData = await DatabaseHelper.pb
          .collection('users')
          .authWithPassword(_emailController.text, _passwordController.text);
      print('Authentication successful, record ID: ${authData.record.id}');

      final user = await DatabaseHelper.pb
          .collection('users')
          .getOne(authData.record.id);
      print('User data retrieved: ${jsonEncode(user.data)}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final loggedInUser = {
        'id': user.id,
        'email': user.data['email'],
        'name': user.data['name'] ?? '',
        'coins': user.data['coins'] ?? 0,
        'avatar': user.data['avatar'] ?? 'default',
        'background': user.data['background'] ?? 'default',
        'purchasedItems': user.data['purchasedItems'] is String
            ? user.data['purchasedItems']
            : jsonEncode(user.data['purchasedItems'] ?? []),
      };
      await prefs.setString('currentUser', jsonEncode(loggedInUser));
      print('User data saved to SharedPreferences: $loggedInUser');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(Duration(seconds: 1));
      print('Navigating to /dashboard');
      Navigator.pushReplacementNamed(context, '/dashboard');
      print('Navigation call executed');
    } catch (e) {
      String errorMessage = 'Error during login';
      if (e is ClientException) {
        errorMessage = e.response['message'] ?? 'Invalid email or password';
        if (e.response['data'] != null && e.response['data']['email'] != null) {
          errorMessage = 'Invalid email or password';
        }
        print('ClientException: ${e.toString()}');
        print('Response: ${jsonEncode(e.response)}');
      } else {
        print('Unexpected error: $e');
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    }
  }

  Future<void> _forgotPassword(BuildContext context) async {
    try {
      await DatabaseHelper.pb
          .collection('users')
          .requestPasswordReset(_emailController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String errorMessage = 'Error sending password reset email';
      if (e is ClientException) {
        errorMessage = e.response['message'] ?? 'Failed to send reset email';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B5CF6), Color(0xFF4B0082)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Log In',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text('Log In', style: TextStyle(fontSize: 18)),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => _forgotPassword(context),
                  child: Text(
                    'Forgot the password?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                  child: Text(
                    'Sign Up',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}