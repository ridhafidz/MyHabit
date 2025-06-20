import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'database_helper.dart';
import 'package:pocketbase/pocketbase.dart';
// Pastikan path ke model User sudah benar
import 'models/user_model.dart'; 

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isPasswordVisible = false;
  bool _isLoading = false; // State untuk mengelola indikator loading

  // Fungsi untuk menangani logika login
  Future<void> _login() async {
    // Memeriksa apakah widget masih ada di tree sebelum menjalankan logika
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validasi input sederhana
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw Exception('Please fill in all fields');
      }

      if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
        throw Exception('Please enter a valid email');
      }

      print('Attempting login for email: ${_emailController.text}');
      
      // Melakukan otentikasi dengan PocketBase
      final authData = await DatabaseHelper.pb
          .collection('users')
          .authWithPassword(_emailController.text.trim(), _passwordController.text.trim());
      
      print('Authentication successful, record ID: ${authData.record!.id}');

      // Membuat objek User dari RecordModel menggunakan factory constructor
      final userModel = User.fromRecord(authData.record!);

      // Menyimpan data user ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Hapus data lama sebelum menyimpan yang baru
      await prefs.setString('currentUser', jsonEncode(userModel.toMap()));
      print('User data saved to SharedPreferences: ${jsonEncode(userModel.toMap())}');
      
      // Gunakan 'mounted' check sebelum navigasi untuk keamanan
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
        // Pindah ke halaman dashboard setelah berhasil login
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on ClientException catch (e) {
      // Menangani error spesifik dari PocketBase (misal: email/password salah)
      print('ClientException: ${e.toString()}');
      setState(() {
        _errorMessage = e.response['message'] ?? 'Invalid email or password';
      });
    } catch (e) {
      // Menangani error lainnya
      print('Unexpected error: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      // Pastikan state loading kembali ke false setelah semua proses selesai
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk menangani lupa password
  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email to reset password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await DatabaseHelper.pb
          .collection('users')
          .requestPasswordReset(_emailController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent. Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending reset email: $e');
      String errorMessage = 'Failed to send reset email.';
      if (e is ClientException) {
        errorMessage = e.response['message'] ?? errorMessage;
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk navigasi ke halaman pendaftaran
  void _navigateToSignUp() {
    // Pastikan rute '/signup' sudah terdaftar di MaterialApp
    Navigator.pushNamed(context, '/signup');
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
          // Gunakan SingleChildScrollView untuk mencegah error overflow di layar kecil
          child: SingleChildScrollView(
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
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
                      prefixIcon: Icon(Icons.lock_outline),
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
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.redAccent[100], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login, // Tombol disable saat loading
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6D28D9),
                        disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: _isLoading 
                          ? CircularProgressIndicator(color: Colors.white, strokeWidth: 3,) 
                          : Text('Log In', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: _isLoading ? null : _navigateToSignUp,
                        child: Text(
                          'Sign Up',
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
