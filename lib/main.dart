import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'login_page.dart'; // Adjust to your actual login page
import 'dashboard_page.dart';
import 'settings_page.dart';
import 'market_page.dart'; // Import MarketPage
import 'profile_page.dart'; // Import ProfilePage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHabit',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(), // Adjust to your login page
        '/dashboard': (context) => DashboardPage(),
        '/settings': (context) => SettingsPage(),
        '/market': (context) => MarketPage(),
        '/profile': (context) => ProfilePage(),
        // Add '/profile': (context) => ProfilePage() if needed
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('Route "${settings.name}" not found'),
            ),
          ),
        );
      },
    );
  }
}