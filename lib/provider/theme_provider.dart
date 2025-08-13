// lib/provider/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final box = Hive.box('settings');
    final isDark = box.get('darkMode', defaultValue: true); // Default to dark as per image
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    final box = Hive.box('settings');
    await box.put('darkMode', isDark);
  }
}

// To integrate in main.dart (add this to your main MaterialApp):
// final themeMode = ref.watch(themeModeProvider);
// themeMode: themeMode,
// theme: ThemeData(
//   useMaterial3: true,
//   colorScheme: ColorScheme.fromSeed(
//     seedColor: Colors.blue,
//     brightness: Brightness.light,
//   ),
//   cardTheme: CardTheme(
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     elevation: 2,
//   ),
// ),
// darkTheme: ThemeData(
//   useMaterial3: true,
//   colorScheme: ColorScheme.fromSeed(
//     seedColor: Colors.blue,
//     brightness: Brightness.dark,
//   ),
//   cardTheme: CardTheme(
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     elevation: 2,
//   ),
// ),