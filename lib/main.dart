// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:travlog_app/screens/auth/splash_screen.dart';
// import 'package:travlog_app/provider/theme_provider.dart'; // Import the theme provider

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Initialize Supabase
//   await Supabase.initialize(
//     url: 'https://onnunvymuazaeoyoqpdz.supabase.co',
//     anonKey:
//         'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ubnVudnltdWF6YWVveW9xcGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5ODAzMTIsImV4cCI6MjA3MDU1NjMxMn0.aOi09aZyxNRTGOZo6tAfAjb-VNNL9em481wei6JI3Zg',
//   );

//   // Initialize Hive and open the box
//   await Hive.initFlutter();
//   await Hive.openBox('entries');

//   runApp(const ProviderScope(child: MyApp()));
// }

// class MyApp extends ConsumerWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final themeMode = ref.watch(themeModeProvider);

//     return MaterialApp(
//       title: 'Travlog App',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.blue,
//           brightness: Brightness.light,
//         ),
//         cardTheme: CardThemeData(
//           // Changed from CardTheme to CardThemeData
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           elevation: 2,
//         ),
//       ),
//       darkTheme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.white,
//           brightness: Brightness.dark,
//         ),
//         cardTheme: CardThemeData(
//           // Changed from CardTheme to CardThemeData
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           elevation: 2,
//         ),
//       ),
//       themeMode: themeMode,
//       home: const SplashScreen(),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:travlog_app/screens/auth/splash_screen.dart';
import 'package:travlog_app/provider/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (keep for syncing)
  await Supabase.initialize(
    url: 'https://onnunvymuazaeoyoqpdz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ubnVudnltdWF6YWVveW9xcGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5ODAzMTIsImV4cCI6MjA3MDU1NjMxMn0.aOi09aZyxNRTGOZo6tAfAjb-VNNL9em481wei6JI3Zg',
  );

  // Initialize Hive and open boxes
  await Hive.initFlutter();
  await Hive.openBox('entries');
  await Hive.openBox('settings'); // Add settings box for theme

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Travlog App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
        ),
      ),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}