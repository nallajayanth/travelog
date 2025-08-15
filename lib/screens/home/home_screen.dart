import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import 'package:travlog_app/screens/add%20entry/add_entry_screen.dart';
import 'package:travlog_app/screens/add%20entry/entry_detail_screen.dart';
import 'package:travlog_app/screens/settings/settings_screen.dart';
import 'package:travlog_app/services/connectivity_service.dart';
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
  bool _hasInitiallyLoaded = false;

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

    // Auto-load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialDataLoad();
    });
  }

  Future<void> _initialDataLoad() async {
    if (_hasInitiallyLoaded) return;
    _hasInitiallyLoaded = true;

    final notifier = ref.read(entriesNotifierProvider.notifier);

    if (_isConnected) {
      // If connected, fetch from Supabase
      try {
        await notifier.fetchFromSupabase();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data synced from cloud'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // If cloud sync fails, fallback to local data
        await notifier.refreshEntries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loaded local data (cloud sync failed)'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // If offline, load local data
      await notifier.refreshEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loaded local data (offline)'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
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

      // Trigger initial data load once connectivity is determined
      if (!_hasInitiallyLoaded) {
        _initialDataLoad();
      }
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
            final wasOffline = !_isConnected;
            setState(() {
              _isConnected = online;
            });

            // Auto-sync when coming back online
            if (wasOffline && online) {
              _autoSyncOnReconnect();
            }
          }
        });
      }
    });
  }

  Future<void> _autoSyncOnReconnect() async {
    final notifier = ref.read(entriesNotifierProvider.notifier);
    try {
      await notifier.fetchFromSupabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-synced with cloud after reconnection'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-sync failed after reconnection'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final syncStatus = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter out entries marked for deletion and apply search
    final visibleEntries = entries
        .where((e) => e['sync_status'] != 'delete_pending')
        .toList();

    final filteredEntries = visibleEntries.where((e) {
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
          // Smart sync status chip
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              avatar: Icon(syncStatus.icon, color: Colors.white, size: 16),
              label: Text(
                syncStatus.displayText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              backgroundColor: syncStatus.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Manual Sync/Refresh button
          IconButton(
            icon: Icon(
              _isConnected ? Icons.sync : Icons.refresh,
              color: colorScheme.onPrimary,
              size: 28,
            ),
            onPressed: () async {
              if (_isConnected) {
                // Online - sync with Supabase
                try {
                  await notifier.fetchFromSupabase();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Manual sync completed'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync failed'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // Offline - refresh local data
                await notifier.refreshEntries();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local data refreshed'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Colors.grey,
                    ),
                  );
                }
              }
            },
            tooltip: _isConnected
                ? 'Manual sync with cloud'
                : 'Refresh local data',
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
            opacity: 0.3,
            child: Image.asset(
              'assets/img.png',
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                // fallback UI if image fails to load
                return Container(
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.image_not_supported)),
                );
              },
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
                              _searchQuery.isEmpty
                                  ? Icons.book_outlined
                                  : Icons.search_off,
                              size: 100,
                              color: colorScheme.onBackground.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No journeys yet'
                                  : 'No matching journeys',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Tap + to capture your first adventure'
                                  : 'Try a different search term',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onBackground.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                                child: const Text('Clear Search'),
                              ),
                            ],
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
                          if (_isConnected) {
                            try {
                              await notifier.fetchFromSupabase();
                            } catch (e) {
                              await notifier.refreshEntries();
                            }
                          } else {
                            await notifier.refreshEntries();
                          }
                          _refreshController.refreshCompleted();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, idx) {
                            final e = filteredEntries[idx];
                            // Find original index in visible entries for navigation
                            final originalIndex = visibleEntries.indexWhere(
                              (entry) => entry['local_id'] == e['local_id'],
                            );

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EntryDetailScreen(
                                      index: originalIndex >= 0
                                          ? originalIndex
                                          : idx,
                                    ),
                                  ),
                                );
                              },
                              child: Hero(
                                tag: 'entry_${e['local_id'] ?? idx}',
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(20),
                                  shadowColor: colorScheme.shadow.withOpacity(
                                    0.2,
                                  ),
                                  color: colorScheme.surface,
                                  child: Stack(
                                    children: [
                                      EntryCard(entry: e),
                                      // Add sync status indicator on the card
                                      if (e['sync_status'] != 'synced')
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: _getSyncStatusColor(
                                                e['sync_status'],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getSyncStatusIcon(
                                                e['sync_status'],
                                              ),
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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
          icon: const Icon(Icons.add, color: Colors.white, size: 28),
          label: const Text(
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

  Color _getSyncStatusColor(String? syncStatus) {
    switch (syncStatus) {
      case 'synced':
        return const Color(0xFF27AE60); // Green
      case 'pending':
        return const Color(0xFFF39C12); // Orange
      case 'modified':
        return const Color(0xFFE67E22); // Orange-red
      case 'error':
        return const Color(0xFFE74C3C); // Red
      default:
        return const Color(0xFF95A5A6); // Gray
    }
  }

  IconData _getSyncStatusIcon(String? syncStatus) {
    switch (syncStatus) {
      case 'synced':
        return Icons.cloud_done;
      case 'pending':
        return Icons.cloud_upload;
      case 'modified':
        return Icons.cloud_sync;
      case 'error':
        return Icons.cloud_off;
      default:
        return Icons.cloud_outlined;
    }
  }
}
