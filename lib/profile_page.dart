// file: lib/profile_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'models/user_model.dart';
import 'models/task_model.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  User? _currentUser;
  bool _isLoading = true;
  late AnimationController _animationController;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadUser();
  }

  Future<void> _loadUser({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      setState(() { _isLoading = true; });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('currentUser');
      if (userJson == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final userData = jsonDecode(userJson);
      final user = User.fromMap(userData);
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error memuat pengguna: $e');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _pickAndUpdateAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null && _currentUser != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mengunggah avatar...')));
      }
      try {
        final bytes = await image.readAsBytes();
        
        final file = http.MultipartFile.fromBytes(
          'profilePhoto',
          bytes,
          filename: image.name,
        );

        final updatedRecord = await DatabaseHelper.pb
            .collection('users')
            .update(_currentUser!.id, files: [file]);

        final updatedUser = User.fromRecord(updatedRecord);
        await _updateUserAndRefresh(updatedUser);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avatar diperbarui!')));
        }
      } catch (e) {
        print('Error memperbarui avatar: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui avatar: $e')));
        }
      }
    }
  }
  
  void _showChangeNameDialog() {
    _nameController.text = _currentUser?.name ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ganti Nama'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(hintText: 'Masukkan nama baru'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty && _currentUser != null) {
                final userWithNewName = _currentUser!.copyWith(name: _nameController.text);
                await _updateUserAndRefresh(userWithNewName);
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCustomizationOptions(String title, String? currentSelection, String itemFilter, Function(String) onSave) {
    final items = _currentUser?.purchasedItems
            .where((item) => item.contains(itemFilter))
            .toList() ?? [];
    
    items.insert(0, 'default');

    String? tempSelection = (currentSelection == null || currentSelection.isEmpty) ? 'default' : currentSelection;
    
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Text('Pilih $title'),
                content: Container(
                  width: double.maxFinite,
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return RadioListTile<String>(
                            title: Text(item.replaceAll('_', ' ').capitalize()),
                            value: item,
                            groupValue: tempSelection,
                            onChanged: (value) {
                               setState(() {
                                 tempSelection = value;
                               });
                            });
                      }),
                ),
                actions: [
                   TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
                   ElevatedButton(
                     onPressed: () {
                        if (tempSelection != null) {
                          onSave(tempSelection == 'default' ? '' : tempSelection!);
                        }
                        Navigator.pop(context);
                     }, 
                     child: Text('Terapkan')
                   )
                ],
              );
            },
          );
        });
  }
  
  Future<void> _updateUserAndRefresh(User updatedUser) async {
    try {
      await DatabaseHelper.instance.updateUser(updatedUser);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(updatedUser.toMap()));
      await _loadUser(forceRefresh: true);
    } catch(e) {
      print("Gagal memperbarui pengguna: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan perubahan: $e')));
      }
    }
  }

  void _requestPasswordReset() async {
    if (_currentUser == null) return;
    try {
      await DatabaseHelper.pb.collection('users').requestPasswordReset(_currentUser!.email);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tautan atur ulang kata sandi dikirim ke ${_currentUser!.email}')),
        );
      }
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim tautan atur ulang: $e')),
        );
       }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Akun'),
        content: Text('Apakah Anda yakin ingin menghapus akun? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                if (_currentUser != null) {
                  await DatabaseHelper.instance.deleteAccount(_currentUser!.id);
                  if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              } catch (e) {
                print('Error menghapus akun: $e');
              }
            },
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _navigateToAchievementPage() {
    if (_currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AchievementPage(achievements: _currentUser!.purchasedItems),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF4B0082),
      body: _isLoading || _currentUser == null
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildCustomizationMenus(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        _buildSettingsTile(Icons.emoji_events, 'Galeri Pencapaian', _navigateToAchievementPage),
                        _buildSettingsTile(Icons.edit, 'Ganti Nama', _showChangeNameDialog),
                        _buildSettingsTile(Icons.image, 'Ganti Avatar', _pickAndUpdateAvatar),
                        _buildSettingsTile(Icons.lock, 'Atur Ulang Kata Sandi', _requestPasswordReset),
                        SizedBox(height: 24),
                        _buildDeleteAccountButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    double xpProgress = (_currentUser?.xp ?? 0) / 100.0;
    
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: Color(0xFF6D28D9),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8B5CF6), Color(0xFF4B0082)],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProfileAvatar(),
                  SizedBox(height: 12),
                  Text(
                    _currentUser!.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(_currentUser!.email, style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatChip(Icons.stars, 'Level ${_currentUser!.level}', Colors.cyanAccent),
                      SizedBox(width: 16),
                      _buildStatChip(Icons.monetization_on, '${_currentUser!.coins} Coins', Colors.yellow),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildXpProgressBar(xpProgress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    String? imageUrl;
    final photoFileName = _currentUser?.profilePhoto;
    final avatarFrame = _currentUser?.avatarFrame;

    if (photoFileName != null && photoFileName.isNotEmpty) {
      final recordId = _currentUser!.id;
      final collectionName = 'users';
      imageUrl = '${DatabaseHelper.pb.baseUrl}/api/files/$collectionName/$recordId/$photoFileName';
    }

    BoxDecoration frameDecoration;

    switch (avatarFrame) {
      case 'golden_frame':
        frameDecoration = BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Colors.yellow[600]!, Colors.amber[700]!]),
          boxShadow: [BoxShadow(color: Colors.yellow.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
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
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        );
    }

    return Container(
      padding: EdgeInsets.all(4),
      decoration: frameDecoration,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white24,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Icon(Icons.person, size: 50, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildXpProgressBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        children: [
          Text(
            'Progres Level (${_currentUser?.xp ?? 0}/100 XP)',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationMenus() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kustomisasi',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildCustomizationMenuTile(
            icon: Icons.filter_frames,
            title: 'Bingkai Avatar',
            currentValue: _currentUser?.avatarFrame,
            itemFilter: '_frame',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(avatarFrame: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
          _buildCustomizationMenuTile(
            icon: Icons.palette,
            title: 'Tema Profil',
            currentValue: _currentUser?.profileTheme,
            itemFilter: '_theme',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(profileTheme: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
           _buildCustomizationMenuTile(
            icon: Icons.music_note,
            title: 'Musik Profil',
            currentValue: _currentUser?.profileMusic,
            itemFilter: '_music',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(profileMusic: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
           _buildCustomizationMenuTile(
            icon: Icons.notifications_active,
            title: 'Paket Suara',
            currentValue: _currentUser?.soundPack,
            itemFilter: '_sounds',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(soundPack: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
           _buildCustomizationMenuTile(
            icon: Icons.animation,
            title: 'Animasi Profil',
            currentValue: _currentUser?.profileAnimation,
            itemFilter: '_effects',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(profileAnimation: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
           _buildCustomizationMenuTile(
            icon: Icons.bar_chart,
            title: 'Tema Grafik',
            currentValue: _currentUser?.chartTheme,
            itemFilter: '_charts',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(chartTheme: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
           _buildCustomizationMenuTile(
            icon: Icons.military_tech,
            title: 'Pangkat',
            currentValue: _currentUser?.titleRank,
            itemFilter: 'habit_master',
            onSave: (newValue) {
              final updatedUser = _currentUser!.copyWith(titleRank: newValue);
              _updateUserAndRefresh(updatedUser);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomizationMenuTile({required IconData icon, required String title, String? currentValue, required String itemFilter, required Function(String) onSave}) {
    final displayValue = (currentValue == null || currentValue.isEmpty) ? 'Default' : currentValue.replaceAll('_', ' ').capitalize();
    return Card(
      color: Colors.white.withOpacity(0.15),
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: TextStyle(color: Colors.white70)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayValue, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
        onTap: () {
           _showCustomizationOptions(title, currentValue, itemFilter, onSave);
        },
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      color: Color(0xFF6D28D9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(Icons.warning_amber_rounded),
        label: Text('Hapus Akun'),
        onPressed: _showDeleteAccountDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class AchievementPage extends StatelessWidget {
  final List<String> achievements;

  const AchievementPage({Key? key, required this.achievements}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Galeri Pencapaian'),
        backgroundColor: Color(0xFF6D28D9),
      ),
      backgroundColor: Color(0xFF4B0082),
      body: achievements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield, color: Colors.white30, size: 80),
                  SizedBox(height: 16),
                  Text(
                    'Belum Ada Pencapaian!',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  Text(
                    'Beli item dari market untuk mendapatkannya.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.only(bottom: 10),
                  color: Color(0xFF6D28D9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.emoji_events, color: Colors.yellow, size: 30),
                    title: Text(
                      achievements[index].replaceAll('_', ' ').capitalize(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return "";
    return this.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
