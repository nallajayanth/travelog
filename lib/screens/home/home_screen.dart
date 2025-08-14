// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';
// import 'package:travlog_app/provider/entries_provider.dart';
// import 'package:travlog_app/screens/add%20entry/add_entry_screen.dart';
// import 'package:travlog_app/screens/add%20entry/entry_detail_screen.dart';
// import 'package:travlog_app/screens/settings/settings_screen.dart'; // Import the SettingsScreen
// import 'package:travlog_app/widgets/entry_card.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'dart:async';
// import 'dart:io'; // Added for InternetAddress

// class HomeScreen extends ConsumerStatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends ConsumerState<HomeScreen>
//     with SingleTickerProviderStateMixin {
//   String _searchQuery = '';
//   late RefreshController _refreshController;
//   late AnimationController _animationController;
//   late Animation<double> _fabAnimation;
//   bool _isConnected = true;
//   late StreamSubscription<List<ConnectivityResult>> _connSub;

//   @override
//   void initState() {
//     super.initState();
//     _refreshController = RefreshController();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     )..forward();
//     _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );
//     _initConnectivity();
//   }

//   Future<bool> _checkInternet() async {
//     try {
//       final result = await InternetAddress.lookup(
//         'google.com',
//       ).timeout(const Duration(seconds: 5));
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<void> _initConnectivity() async {
//     final connectivityResults = await Connectivity().checkConnectivity();
//     final networkConnected = connectivityResults.any(
//       (r) => r != ConnectivityResult.none,
//     );
//     bool online = false;
//     if (networkConnected) {
//       online = await _checkInternet();
//     }
//     if (mounted) {
//       setState(() {
//         _isConnected = online;
//       });
//     }

//     _connSub = Connectivity().onConnectivityChanged.listen((
//       connectivityResults,
//     ) {
//       final networkConnected = connectivityResults.any(
//         (r) => r != ConnectivityResult.none,
//       );
//       if (!networkConnected) {
//         if (mounted) {
//           setState(() {
//             _isConnected = false;
//           });
//         }
//       } else {
//         _checkInternet().then((online) {
//           if (mounted) {
//             setState(() {
//               _isConnected = online;
//             });
//           }
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _refreshController.dispose();
//     _animationController.dispose();
//     _connSub.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final entries = ref.watch(entriesNotifierProvider);
//     final notifier = ref.read(entriesNotifierProvider.notifier);

//     final filteredEntries = entries.where((e) {
//       final title = (e['title'] as String?)?.toLowerCase() ?? '';
//       final desc = (e['description'] as String?)?.toLowerCase() ?? '';
//       final dateStr =
//           (e['date_time'] as String?)?.split('T').first.toLowerCase() ?? '';
//       final address =
//           (e['address'] as String?)?.toLowerCase() ?? ''; // Added address

//       final tags = List<String>.from(
//         e['tags'] ?? [],
//       ).map((t) => t.toLowerCase());

//       final query = _searchQuery.toLowerCase();
//       return title.contains(query) ||
//           desc.contains(query) ||
//           dateStr.contains(query) ||
//           address.contains(query) || // Added address filtering
//           tags.any((tag) => tag.contains(query));
//     }).toList();

//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text(
//           'Travlog',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 28,
//             color: Colors.white,
//             shadows: [
//               Shadow(
//                 blurRadius: 10.0,
//                 color: Colors.black26,
//                 offset: Offset(2.0, 2.0),
//               ),
//             ],
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.settings, color: Colors.white, size: 28),
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => const SettingsScreen()),
//             );
//           },
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 8.0),
//             child: Chip(
//               label: Text(
//                 _isConnected ? 'Online' : 'Offline',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               backgroundColor: _isConnected ? Colors.green : Colors.red,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//               visualDensity: VisualDensity.compact,
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.sync, color: Colors.white, size: 28),
//             onPressed: _isConnected
//                 ? () async {
//                     await notifier.fetchFromSupabase();
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Synced with Supabase')),
//                     );
//                   }
//                 : null,
//           ),
//         ],
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Theme.of(context).colorScheme.primary.withOpacity(0.8),
//                 Theme.of(context).colorScheme.secondary.withOpacity(0.6),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           // Subtle background gradient for depth
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFFEAF2F8), Color(0xFFD4E6F1)],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),
//           // Faint travel-themed overlay
//           Opacity(
//             opacity: 0.05,
//             child: Image.network(
//               'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&q=80',
//               fit: BoxFit.cover,
//               height: double.infinity,
//               width: double.infinity,
//             ),
//           ),
//           Column(
//             children: [
//               // Search bar below app bar
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 100, 16, 12),
//                 child: TextField(
//                   style: const TextStyle(color: Colors.black),
//                   decoration: InputDecoration(
//                     labelText:
//                         'Search journeys by title, description, tags, date, or location',
//                     labelStyle: TextStyle(color: Colors.grey[600]),

//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(25),
//                       borderSide: BorderSide.none,
//                     ),
//                     prefixIcon: const Icon(
//                       Icons.search,
//                       color: Color(0xFF3498DB),
//                     ),
//                     suffixIcon: _searchQuery.isNotEmpty
//                         ? IconButton(
//                             icon: const Icon(
//                               Icons.clear,
//                               color: Color(0xFF3498DB),
//                             ),
//                             onPressed: () => setState(() => _searchQuery = ''),
//                           )
//                         : null,
//                     filled: true,
//                     fillColor: Colors.white,
//                     contentPadding: const EdgeInsets.symmetric(
//                       vertical: 16,
//                       horizontal: 20,
//                     ),
//                     hintStyle: TextStyle(color: Colors.grey[400]),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(25),
//                       borderSide: const BorderSide(
//                         color: Color(0xFF3498DB),
//                         width: 2,
//                       ),
//                     ),
//                   ),
//                   onChanged: (value) => setState(() => _searchQuery = value),
//                 ),
//               ),
//               Expanded(
//                 child: filteredEntries.isEmpty
//                     ? Center(
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               Icons.book_outlined,
//                               size: 100,
//                               color: Theme.of(
//                                 context,
//                               ).colorScheme.primary.withOpacity(0.5),
//                             ),
//                             const SizedBox(height: 16),
//                             Text(
//                               'No journeys yet',
//                               style: Theme.of(context).textTheme.headlineMedium
//                                   ?.copyWith(
//                                     fontWeight: FontWeight.bold,
//                                     color: Color(0xFF2C3E50),
//                                   ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               'Tap + to capture your first adventure',
//                               style: Theme.of(context).textTheme.bodyLarge
//                                   ?.copyWith(color: Colors.grey[600]),
//                             ),
//                           ],
//                         ),
//                       )
//                     : SmartRefresher(
//                         controller: _refreshController,
//                         enablePullUp: false,
//                         header: const WaterDropMaterialHeader(
//                           backgroundColor: Color(0xFF3498DB),
//                         ),
//                         onRefresh: () async {
//                           await notifier.fetchFromSupabase();
//                           _refreshController.refreshCompleted();
//                         },
//                         child: ListView.separated(
//                           padding: const EdgeInsets.all(16),
//                           separatorBuilder: (_, __) =>
//                               const SizedBox(height: 16),
//                           itemCount: filteredEntries.length,
//                           itemBuilder: (context, idx) {
//                             final e = filteredEntries[idx];
//                             final originalIndex = entries.indexOf(e);
//                             return GestureDetector(
//                               onTap: () {
//                                 Navigator.of(context).push(
//                                   MaterialPageRoute(
//                                     builder: (_) =>
//                                         EntryDetailScreen(index: originalIndex),
//                                   ),
//                                 );
//                               },
//                               child: Hero(
//                                 tag: 'entry_${e['id'] ?? idx}',
//                                 child: Material(
//                                   elevation: 4,
//                                   borderRadius: BorderRadius.circular(20),
//                                   shadowColor: Colors.black.withOpacity(0.1),
//                                   child: EntryCard(entry: e),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       floatingActionButton: ScaleTransition(
//         scale: _fabAnimation,
//         child: FloatingActionButton.extended(
//           onPressed: () => Navigator.of(
//             context,
//           ).push(MaterialPageRoute(builder: (_) => const AddEntryScreen())),
//           icon: const Icon(Icons.add, color: Colors.white, size: 28),
//           label: const Text(
//             'New Journey',
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//           backgroundColor: const Color(0xFF2ECC71),
//           elevation: 8,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           tooltip: 'Add New Entry',
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import 'package:travlog_app/screens/add%20entry/add_entry_screen.dart';
import 'package:travlog_app/screens/add%20entry/entry_detail_screen.dart';
import 'package:travlog_app/screens/settings/settings_screen.dart';
import 'package:travlog_app/widgets/entry_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late RefreshController _refreshController;
  late AnimationController _animationController;
  late Animation<double> _fabAnimation;
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connSub;

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initConnectivity();
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    final networkConnected = connectivityResults.any(
      (r) => r != ConnectivityResult.none,
    );
    bool online = false;
    if (networkConnected) {
      online = await _checkInternet();
    }
    if (mounted) {
      setState(() {
        _isConnected = online;
      });
    }

    _connSub = Connectivity().onConnectivityChanged.listen((
      connectivityResults,
    ) {
      final networkConnected = connectivityResults.any(
        (r) => r != ConnectivityResult.none,
      );
      if (!networkConnected) {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      } else {
        _checkInternet().then((online) {
          if (mounted) {
            setState(() {
              _isConnected = online;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _animationController.dispose();
    _connSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesNotifierProvider);
    final notifier = ref.read(entriesNotifierProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredEntries = entries.where((e) {
      final title = (e['title'] as String?)?.toLowerCase() ?? '';
      final desc = (e['description'] as String?)?.toLowerCase() ?? '';
      final dateStr =
          (e['date_time'] as String?)?.split('T').first.toLowerCase() ?? '';
      final address = (e['address'] as String?)?.toLowerCase() ?? '';
      final tags = List<String>.from(
        e['tags'] ?? [],
      ).map((t) => t.toLowerCase());
      final query = _searchQuery.toLowerCase();
      return title.contains(query) ||
          desc.contains(query) ||
          dateStr.contains(query) ||
          address.contains(query) ||
          tags.any((tag) => tag.contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Travlog',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: colorScheme.onPrimary,
            shadows: const [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black26,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.settings, color: colorScheme.onPrimary, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              label: Text(
                _isConnected ? 'Online' : 'Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _isConnected ? Colors.green : Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: Icon(Icons.sync, color: colorScheme.onPrimary, size: 28),
            onPressed: _isConnected
                ? () async {
                    await notifier.fetchFromSupabase();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Synced with Supabase')),
                    );
                  }
                : null,
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.8),
                colorScheme.secondary.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.background,
                  colorScheme.background.withOpacity(0.95),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Opacity(
            opacity: 0.05,
            child: Image.network(
              'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&q=80',
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 12),
                child: TextField(
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText:
                        'Search journeys by title, description, tags, date, or location',
                    labelStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colorScheme.primary),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child: filteredEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 100,
                              color: colorScheme.onBackground.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No journeys yet',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to capture your first adventure',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onBackground.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SmartRefresher(
                        controller: _refreshController,
                        enablePullUp: false,
                        header: WaterDropMaterialHeader(
                          backgroundColor: colorScheme.primary,
                        ),
                        onRefresh: () async {
                          await notifier.fetchFromSupabase();
                          _refreshController.refreshCompleted();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, idx) {
                            final e = filteredEntries[idx];
                            final originalIndex = entries.indexOf(e);
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EntryDetailScreen(index: originalIndex),
                                  ),
                                );
                              },
                              child: Hero(
                                tag: 'entry_${e['id'] ?? idx}',
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(20),
                                  shadowColor: colorScheme.shadow.withOpacity(
                                    0.2,
                                  ),
                                  color: colorScheme.surface,
                                  child: EntryCard(entry: e),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddEntryScreen())),
          icon: Icon(Icons.add, color: Colors.white, size: 28),
          label: Text(
            'New Journey',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.green,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          tooltip: 'Add New Entry',
        ),
      ),
    );
  }
}
