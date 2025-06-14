import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models/user_model.dart';
import 'database_helper.dart';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? _currentUser;
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isPageVisible = false;
  XFile? _pickedImage;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      await DatabaseHelper.initialize();
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('currentUser');
      if (userJson == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userData = jsonDecode(userJson);
      final user = User.fromJson(userData);

      if (DatabaseHelper.pb.authStore.isValid) {
        setState(() {
          _currentUser = user;
        });
      } else {
        await prefs.remove('currentUser');
        await prefs.remove('pb_auth');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error loading user: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load user data: $e')));
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _manageSubscriptions(bool isVisible) {
    if (_currentUser == null) return;
    final dbHelper = DatabaseHelper.instance;

    setState(() {
      _isPageVisible = isVisible;
    });

    if (isVisible) {
      dbHelper.subscribeToUser(_currentUser!.id, (user) {
        if (_isPageVisible) {
          setState(() {
            _currentUser = user;
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('currentUser', jsonEncode(user.toJson()));
            });
          });
        }
      });
    } else {
      dbHelper.unsubscribeFromUser(_currentUser!.id);
    }
  }

  Future<void> _updatePassword() async {
    if (_currentUser == null || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Password cannot be empty';
      });
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    if (!DatabaseHelper.pb.authStore.isValid) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        password: _passwordController.text,
        coins: _currentUser!.coins,
        avatar: _currentUser!.avatar,
        background: _currentUser!.background,
        profilePhoto: _currentUser!.profilePhoto,
        purchasedItems: _currentUser!.purchasedItems,
      );

      await dbHelper.updateUser(updatedUser);
      await DatabaseHelper.pb
          .collection('users')
          .authWithPassword(_currentUser!.email, _passwordController.text);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Password updated')));
      setState(() {
        _errorMessage = null;
        _passwordController.clear();
      });
    } catch (e) {
      print('Error updating password: $e');
      setState(() {
        _errorMessage = 'Failed to update password: $e';
      });
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (_currentUser == null) return;
    final dbHelper = DatabaseHelper.instance;

    setState(() {
      _isLoading = true;
    });

    try {
      String fileUrl;
      final fileName =
          'profile_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String fileNameFromResponse;

      bool isWeb = identical(0, 0.0);

      if (isWeb) {
        final bytes = await pickedFile.readAsBytes();
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse(
            'http://127.0.0.1:8090/api/collections/users/records/${_currentUser!.id}',
          ),
        );
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePhoto',
            bytes,
            filename: fileName,
          ),
        );
        request.headers['Authorization'] = DatabaseHelper.pb.authStore.token;

        final response = await request.send();
        if (response.statusCode != 200) {
          throw Exception('Failed to upload image: ${response.statusCode}');
        }

        final responseData = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseData);
        fileNameFromResponse = jsonData['profilePhoto'];
        fileUrl =
            DatabaseHelper.pb
                .getFileUrl(
                  RecordModel.fromJson(jsonData),
                  fileNameFromResponse,
                )
                .toString();
      } else {
        final file = await http.MultipartFile.fromPath(
          'profilePhoto',
          pickedFile.path,
          filename: fileName,
        );
        final record = await DatabaseHelper.pb
            .collection('users')
            .update(_currentUser!.id, files: [file]);
        fileNameFromResponse = record.data['profilePhoto'];
        fileUrl =
            DatabaseHelper.pb
                .getFileUrl(record, fileNameFromResponse)
                .toString();
      }

      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        password: _currentUser!.password,
        coins: _currentUser!.coins,
        avatar: _currentUser!.avatar,
        background: _currentUser!.background,
        profilePhoto: fileUrl,
        purchasedItems: _currentUser!.purchasedItems,
      );

      await dbHelper.updateUser(updatedUser);
      final prefs = await SharedPreferences.getInstance();
      final record = await DatabaseHelper.pb
          .collection('users')
          .getOne(_currentUser!.id);
      final userFromDb = User.fromJson({
        'id': record.id,
        ...record.data,
        'profilePhoto': fileUrl,
      });
      await prefs.setString('currentUser', jsonEncode(userFromDb.toJson()));

      setState(() {
        _currentUser = userFromDb;
        _pickedImage = pickedFile;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      print(
        'Error uploading profile photo: $e, currentUser=${_currentUser?.toJson()}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (_currentUser == null) return;
    final dbHelper = DatabaseHelper.instance;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      String fileUrl;
      final fileName =
          'avatar_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String fileNameFromResponse;

      bool isWeb = identical(0, 0.0);

      if (isWeb) {
        final bytes = await pickedFile.readAsBytes();
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse(
            'http://127.0.0.1:8090/api/collections/users/records/${_currentUser!.id}',
          ),
        );
        request.files.add(
          http.MultipartFile.fromBytes('avatar', bytes, filename: fileName),
        );
        request.headers['Authorization'] = DatabaseHelper.pb.authStore.token;

        final response = await request.send();
        if (response.statusCode != 200) {
          throw Exception('Failed to upload avatar: ${response.statusCode}');
        }

        final responseData = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseData);
        fileNameFromResponse = jsonData['avatar'];
        fileUrl =
            DatabaseHelper.pb
                .getFileUrl(
                  RecordModel.fromJson(jsonData),
                  fileNameFromResponse,
                )
                .toString();
      } else {
        final file = await http.MultipartFile.fromPath(
          'avatar',
          pickedFile.path,
          filename: fileName,
        );
        final record = await DatabaseHelper.pb
            .collection('users')
            .update(
              _currentUser!.id,
              files: [file],
              body: {'avatar': fileName}, // Update avatar field
            );
        fileNameFromResponse = record.data['avatar'];
        fileUrl =
            DatabaseHelper.pb
                .getFileUrl(record, fileNameFromResponse)
                .toString();
      }

      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        password: _currentUser!.password,
        coins: _currentUser!.coins,
        avatar: fileUrl,
        background: _currentUser!.background,
        profilePhoto: _currentUser!.profilePhoto,
        purchasedItems: _currentUser!.purchasedItems,
      );

      await dbHelper.updateUser(updatedUser);
      final prefs = await SharedPreferences.getInstance();
      final record = await DatabaseHelper.pb
          .collection('users')
          .getOne(_currentUser!.id);
      final userFromDb = User.fromJson({
        'id': record.id,
        ...record.data,
        'avatar': fileUrl,
      });
      await prefs.setString('currentUser', jsonEncode(userFromDb.toJson()));

      setState(() {
        _currentUser = userFromDb;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar updated')));
    } catch (e) {
      print(
        'Error uploading avatar: $e, currentUser=${_currentUser?.toJson()}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload avatar: $e')));
    } finally {
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    if (_currentUser == null) return;

    final dbHelper = DatabaseHelper.instance;
    try {
      await dbHelper.deleteAccount(_currentUser!.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUser');
      await prefs.remove('pb_auth');
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Error deleting account: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VisibilityDetector(
        key: Key('settings-visibility'),
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
              child:
                  _currentUser == null
                      ? Center(child: CircularProgressIndicator())
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),
                          ListTile(
                            leading: Icon(Icons.person, color: Colors.white),
                            title: Text(
                              'Change Avatar',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing:
                                _isUploadingAvatar
                                    ? CircularProgressIndicator()
                                    : ElevatedButton(
                                      onPressed: _uploadAvatar,
                                      child: Text('Upload'),
                                    ),
                          ),
                          ListTile(
                            leading: Icon(Icons.photo, color: Colors.white),
                            title: Text(
                              'Change Profile Photo',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing:
                                _isLoading
                                    ? CircularProgressIndicator()
                                    : ElevatedButton(
                                      onPressed: _uploadProfilePhoto,
                                      child: Text('Upload'),
                                    ),
                          ),
                          ListTile(
                            leading: Icon(Icons.lock, color: Colors.white),
                            title: Text(
                              'Change Password',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
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
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: _updatePassword,
                              child: Text('Update'),
                            ),
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          Spacer(),
                          ElevatedButton(
                            onPressed: _deleteAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              minimumSize: Size(double.infinity, 50),
                            ),
                            child: Text(
                              'Delete Account',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF8B5CF6),
                              minimumSize: Size(double.infinity, 50),
                            ),
                            child: Text(
                              'Back to Dashboard',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
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

  @override
  void dispose() {
    _passwordController.dispose();
    if (_currentUser != null) {
      final dbHelper = DatabaseHelper.instance;
      dbHelper.unsubscribeFromUser(_currentUser!.id);
    }
    super.dispose();
  }
}
