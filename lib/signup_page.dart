import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:convert';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final pb = PocketBase('http://127.0.0.1:8090'); // Replace with your PocketBase URL
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeToTerms = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  Future<void> _signUp(BuildContext context) async {
    try {
      // Validate input
      if (_nameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please fill in all fields';
        });
        return;
      }

      if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
        setState(() {
          _errorMessage = 'Please enter a valid email';
        });
        return;
      }

      if (_passwordController.text.length < 8) {
        setState(() {
          _errorMessage = 'Password must be at least 8 characters';
        });
        return;
      }

      if (!_agreeToTerms) {
        setState(() {
          _errorMessage = 'Please agree to terms';
        });
        return;
      }

      // Create a new user in PocketBase
      final userData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'passwordConfirm': _passwordController.text,
        'emailVisibility': true,
        'coins': 0,
        'background': 'default',
        'purchasedItems': jsonEncode([]),
        // Removed 'avatar' field; set default in PocketBase schema
      };

      // Create the user in the 'users' collection
      final record = await pb.collection('users').create(body: userData);

      // Authenticate the user after signup
      await pb.collection('users').authWithPassword(
        _emailController.text,
        _passwordController.text,
      );

      // Save user data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final loggedInUser = {
        'id': record.id,
        'name': record.data['name'],
        'email': record.data['email'],
        'coins': record.data['coins'],
        'avatar': record.data['avatar'] ?? 'default', // Fallback if not set
        'background': record.data['background'],
        'purchasedItems': record.data['purchasedItems'],
      };
      await prefs.setString('currentUser', jsonEncode(loggedInUser));

      // Navigate to dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      // Enhanced error handling
      String errorMessage = 'Error during signup';
      if (e is ClientException) {
        errorMessage = 'Failed to create user: ${e.toString()}';
        errorMessage += '\nDetails: ${jsonEncode(e.response)}';
        print('ClientException: $e'); // Log to console for debugging
      } else {
        errorMessage = 'Unexpected error: $e';
        print('Error: $e'); // Log to console for debugging
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
                  'Sign Up',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 16),
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
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      fillColor: MaterialStateProperty.all(Colors.white),
                      checkColor: Colors.purple,
                    ),
                    Expanded(
                      child: Text(
                        'I agree to receive promotional materials and offers',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _signUp(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: Text(
                    'Log In',
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}