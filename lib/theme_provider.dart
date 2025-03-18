import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // Clé pour stocker le thème dans SharedPreferences
  static const String _themeKey = 'isDarkMode';

  // Variable pour suivre l'état du thème
  bool _isDarkMode = false;

  // Getter pour accéder à l'état du thème
  bool get isDarkMode => _isDarkMode;

  // Constructeur
  ThemeProvider() {
    _loadTheme();
  }

  // Charger le thème depuis SharedPreferences
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false; // Par défaut, mode clair
    notifyListeners();
  }

  // Basculer entre le mode clair et sombre
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    // Sauvegarder le thème dans SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }
}