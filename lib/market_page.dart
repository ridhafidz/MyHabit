// file: lib/market_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'database_helper.dart';
import 'models/user_model.dart';

class MarketPage extends StatefulWidget {
  @override
  _MarketPageState createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  User? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = 'all';

  // === PERUBAHAN: Mengembalikan daftar item statis ===
  final Map<String, Map<String, dynamic>> marketItems = {
    'avatar_frames': {
      'Golden Frame': {'id': 'golden_frame', 'cost': 100, 'icon': Icons.filter_frames},
      'Rainbow Frame': {'id': 'rainbow_frame', 'cost': 150, 'icon': Icons.filter_frames},
    },
    'profile_themes': {
      'Minimalist Theme': {'id': 'minimalist_theme', 'cost': 50, 'icon': Icons.palette},
      'Dark Mode Premium': {'id': 'dark_mode_premium', 'cost': 150, 'icon': Icons.palette},
    },
    'sound_packs': {
      'Notification Sounds': {'id': 'notification_sounds', 'cost': 60, 'icon': Icons.music_note},
      'Completion Sounds': {'id': 'completion_sounds', 'cost': 70, 'icon': Icons.music_note},
    },
    'titles_ranks': {
      'Habit Master': {'id': 'habit_master', 'cost': 100, 'icon': Icons.military_tech},
      'Streak Legend': {'id': 'streak_legend', 'cost': 120, 'icon': Icons.military_tech},
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('currentUser');
      if (userJson == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final userData = jsonDecode(userJson);
      if (mounted) {
        setState(() {
          _currentUser = User.fromMap(userData);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data pengguna.')));
      }
    }
  }

  Future<void> _purchaseItem(String itemId, int cost) async {
    if (_currentUser == null || _currentUser!.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Koin tidak cukup')));
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    try {
      final newPurchasedItems = List<String>.from(_currentUser!.purchasedItems)..add(itemId);

      final updatedUser = _currentUser!.copyWith(
        coins: _currentUser!.coins - cost,
        purchasedItems: newPurchasedItems,
      );

      await dbHelper.updateUser(updatedUser);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', jsonEncode(updatedUser.toMap()));

      await _loadUser();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item berhasil dibeli!')),
      );
    } catch (e) {
      print('Error purchasing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membeli item: $e')));
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
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.white))
              : _currentUser == null
                ? Center(child: Text('Gagal memuat data pengguna.', style: TextStyle(color: Colors.white)))
                : Column(
                    children: [
                      _buildHeader(),
                      _buildCategorySelector(),
                      Expanded(child: _buildItemsGrid()),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, true),
          ),
          Text('Market', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
                SizedBox(width: 8),
                Text(
                  '${_currentUser!.coins}',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip('all', 'All Items'),
          ...marketItems.keys.map((category) => _buildCategoryChip(category, category.replaceAll('_', ' ').capitalize())).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    bool isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: Colors.white.withOpacity(0.2),
        selectedColor: Color(0xFFE9D5FF), 
        labelStyle: TextStyle(
          color: isSelected ? Color(0xFF4B0082) : Color(0xFF4B0082),
          fontWeight: FontWeight.bold
        ),
        checkmarkColor: Color(0xFF4B0082),
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? Color(0xFFC084FC) : Colors.transparent,
            width: 1.5,
          )
        ),
      ),
    );
  }

  Widget _buildItemsGrid() {
    Map<String, Map<String, dynamic>> filteredItems = {};
    if (_selectedCategory == 'all') {
      filteredItems = marketItems;
    } else if (marketItems.containsKey(_selectedCategory)) {
      filteredItems = {_selectedCategory: marketItems[_selectedCategory]!};
    }

    List<MapEntry<String, dynamic>> allItems = [];
    filteredItems.forEach((category, items) {
      items.forEach((itemName, itemData) {
        allItems.add(MapEntry(itemName, {...itemData, 'category': category}));
      });
    });

    if (allItems.isEmpty) {
      return Center(
        child: Text('Tidak ada item di kategori ini.', style: TextStyle(color: Colors.white70)),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final entry = allItems[index];
        return _buildItemCard(
          entry.value['id'], 
          entry.key, 
          entry.value['cost'],
          entry.value['icon'],
        );
      },
    );
  }
  
  Widget _buildItemCard(String itemId, String name, int cost, IconData icon) {
    final isPurchased = _currentUser!.purchasedItems.contains(itemId);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(child: Icon(icon, size: 50, color: Colors.white)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monetization_on, color: Colors.yellow, size: 16),
                          SizedBox(width: 4),
                          Text('$cost', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (isPurchased)
                        Icon(Icons.check_circle, color: Colors.greenAccent)
                      else
                        ElevatedButton(
                          onPressed: () => _purchaseItem(itemId, cost),
                          child: Text('Beli'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: Colors.white,
                            foregroundColor: Color(0xFF4B0082),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
