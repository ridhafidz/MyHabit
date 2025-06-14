import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'database_helper.dart';
import 'models/user_model.dart';

class MarketPage extends StatefulWidget {
  @override
  _MarketPageState createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  User? _currentUser;
  bool _isLoading = true;
  XFile? _pickedAvatarImage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('currentUser');
      if (userJson == null) {
        Navigator.pushReplacementNamed(context, './login');
        return;
      }
      final userData = jsonDecode(userJson);
      final user = User.fromJson(userData);
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user: $e');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _purchaseItem(String itemId, int cost, {String? avatarUrl}) async {
    if (_currentUser == null || _currentUser!.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough coins')));
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    try {
      String newAvatar = _currentUser!.avatar;
      String newBackground = _currentUser!.background;
      List<String>? newPurchasedItems = [...?_currentUser!.purchasedItems];

      if (itemId == 'star_avatar' || itemId == 'custom_avatar') {
        newAvatar = avatarUrl ?? 'star'; // Use custom URL or default 'star'
        if (itemId == 'custom_avatar' && _pickedAvatarImage != null) {
          // Upload custom avatar
          final fileName = 'avatar_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = await http.MultipartFile.fromPath('avatar', _pickedAvatarImage!.path, filename: fileName);
          final record = await DatabaseHelper.pb.collection('users').update(
            _currentUser!.id,
            files: [file],
            body: {'avatar': fileName}, // Update avatar field with filename
          );
          newAvatar = DatabaseHelper.pb.getFileUrl(record, fileName).toString();
        }
        newPurchasedItems.add(itemId);
      } else if (itemId == 'gold_background') {
        newBackground = 'gold';
        newPurchasedItems.add(itemId);
      }

      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        password: _currentUser!.password,
        coins: _currentUser!.coins - cost,
        avatar: newAvatar,
        background: newBackground,
        profilePhoto: _currentUser!.profilePhoto,
        purchasedItems: newPurchasedItems,
      );

      await dbHelper.updateUser(updatedUser);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(updatedUser.toMap()));

      setState(() {
        _currentUser = updatedUser;
        _pickedAvatarImage = null; // Reset after purchase
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item purchased and applied successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Error purchasing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to purchase item: $e')));
    }
  }

  Future<void> _selectCustomAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedAvatarImage = pickedFile;
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
            colors: _currentUser?.background == 'gold'
                ? [Colors.yellow, Colors.orange]
                : [Color(0xFF8B5CF6), Color(0xFF4B0082)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading || _currentUser == null
                ? Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Market',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${_currentUser!.coins}',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 16,
                            ),
                          ),
                          Icon(Icons.monetization_on, color: Colors.yellow),
                        ],
                      ),
                      SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildItem(
                              'gold_background',
                              'Gold Background',
                              50,
                              avatarUrl: null,
                            ),
                            _buildItem(
                              'star_avatar',
                              'Star Avatar',
                              30,
                              avatarUrl: 'https://example.com/star_avatar.png', // Placeholder URL
                            ),
                            ListTile(
                              title: Text('Custom Avatar', style: TextStyle(color: Colors.white)),
                              subtitle: Text('50 coins', style: TextStyle(color: Colors.white70)),
                              trailing: _pickedAvatarImage == null
                                  ? ElevatedButton(
                                      onPressed: _selectCustomAvatar,
                                      child: Text('Select Image'),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.file(File(_pickedAvatarImage!.path), width: 40, height: 40),
                                        ElevatedButton(
                                          onPressed: () => _purchaseItem('custom_avatar', 50),
                                          child: Text('Buy'),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
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

  Widget _buildItem(String itemId, String name, int cost, {String? avatarUrl}) {
    final isPurchased = _currentUser!.purchasedItems?.contains(itemId) ?? false;
    return Card(
      color: Colors.white.withOpacity(0.2),
      child: ListTile(
        leading: avatarUrl != null ? Image.network(avatarUrl, width: 40, height: 40) : null,
        title: Text(name, style: TextStyle(color: Colors.white)),
        subtitle: Text('$cost coins', style: TextStyle(color: Colors.white70)),
        trailing: isPurchased
            ? Text('Purchased', style: TextStyle(color: Colors.green))
            : ElevatedButton(
                onPressed: () => _purchaseItem(itemId, cost, avatarUrl: avatarUrl),
                child: Text('Buy'),
              ),
      ),
    );
  }
}