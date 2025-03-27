import 'package:flutter/material.dart';

class AppTheme {
  // Define your custom colors
  static const Color yellow = Color(0xFFFFD60A);
  static const Color blue = Color(0xFF40C4FF);
  static const Color coral = Color(0xFFFF6F61);
  static const Color green = Color(0xFF76FF03);
  static const Color orange = Color(0xFFFFAB40);

  // List of all available colors for squares
  static const List<Color> squareColors = [
    yellow,
    blue,
    coral,
    green,
    orange,
  ];

  // White for app bar and navigation
  static const Color appBarColor = Colors.white;
  static const Color navBarColor = Colors.white;
  static const Color navBarItemColor = blue; // Dark blue from your bottom nav

  // Theme data
  static ThemeData get theme {
    return ThemeData(
      primaryColor: appBarColor,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: appBarColor,
        elevation: 4,
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navBarColor,
        selectedItemColor: navBarItemColor,
        unselectedItemColor: Colors.grey,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
