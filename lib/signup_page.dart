// file: lib/signup_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:convert';
import 'database_helper.dart';
// Pastikan path ke model User sudah benar
import 'models/user_model.dart'; 

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeToTerms = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  bool _isLoading = false; // State untuk mengelola indikator loading

  // Fungsi untuk menangani logika pendaftaran
  Future<void> _signUp() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validasi input
      if (_nameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        throw Exception('Please fill in all fields');
      }

      if (!_emailController.text.contains('@') ||
          !_emailController.text.contains('.')) {
        throw Exception('Please enter a valid email');
      }

      if (_passwordController.text.length < 8) {
        throw Exception('Password must be at least 8 characters');
      }

      if (!_agreeToTerms) {
        throw Exception('You must agree to the terms and conditions');
      }

      // === PERBAIKAN: Hanya mengirim field yang memiliki nilai, sisanya biarkan default di DB ===
      final userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'passwordConfirm': _passwordController.text,
        'emailVisibility': true,
        // Data awal untuk pengguna baru
        'coins': 0,
        'level': 1,
        'xp': 0, 
        'purchasedItems': [],
        // Field opsional tidak perlu dikirim jika kosong
      };

      print('Attempting to create user with data: $userData');
      
      // Membuat record pengguna baru di PocketBase
      final record = await DatabaseHelper.pb
          .collection('users')
          .create(body: userData);

      print('User created successfully, record ID: ${record.id}');
      
      // Langsung login setelah berhasil mendaftar untuk mendapatkan sesi
      await DatabaseHelper.pb
          .collection('users')
          .authWithPassword(_emailController.text.trim(), _passwordController.text);
      
      print('User authenticated successfully after signup');

      // Gunakan User.fromRecord untuk membuat objek dari respons
      final newUser = User.fromRecord(record);

      // Simpan data user yang sudah rapi ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(newUser.toMap()));
      print('New user data saved to SharedPreferences: ${jsonEncode(newUser.toMap())}');
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }

    } on ClientException catch (e) {
      print('ClientException: ${jsonEncode(e.response)}');
      String serverMessage = 'An error occurred.';
      if (e.response.containsKey('data') && e.response['data'] is Map && e.response['data'].isNotEmpty) {
        final data = e.response['data'] as Map;
        // Mencari pesan error spesifik dari field yang gagal validasi
        final fieldError = data.values.firstWhere((v) => v is Map && v.containsKey('message'), orElse: () => null);
        if (fieldError != null) {
          serverMessage = fieldError['message'] as String;
        } else {
           serverMessage = e.response['message'] ?? 'Gagal membuat akun.';
        }
      } else if (e.response.containsKey('message')) {
        serverMessage = e.response['message'] as String;
      }
      setState(() {
        _errorMessage = serverMessage;
      });
    } catch (e) {
      print('Unexpected error: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _navigateToLogin() {
    Navigator.pop(context);
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: 'Name',
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: 'Password (min. 8 characters)',
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.white),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8),
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
                        checkColor: Colors.deepPurple,
                      ),
                      Expanded(
                        child: Text(
                          'I agree to the Terms and Conditions',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.redAccent[100], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFFFFF),
                        disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                        foregroundColor: Color(0xFF4B0082),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Color(0xFF4B0082), strokeWidth: 3,)
                          : Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: _isLoading ? null : _navigateToLogin,
                        child: Text(
                          'Log In',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                ],
              ),
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
