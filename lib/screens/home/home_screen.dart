// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:travlog_app/provider/entries_provider.dart';
import 'package:travlog_app/screens/add%20entry/add_entry_screen.dart';
import 'package:travlog_app/screens/add%20entry/entry_detail_screen.dart';
import 'package:travlog_app/widgets/entry_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesNotifierProvider);
    final notifier = ref.read(entriesNotifierProvider.notifier);
    final refreshController = RefreshController();

    final filteredEntries = entries.where((e) {
      final title = (e['title'] as String?)?.toLowerCase() ?? '';
      final desc = (e['description'] as String?)?.toLowerCase() ?? '';
      return title.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WanderLog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await notifier.fetchFromSupabase();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synced from Supabase')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by title or description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
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
                        const Icon(
                          Icons.book_outlined,
                          size: 72,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No entries yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text('Tap + to create your first travel memory'),
                      ],
                    ),
                  )
                : SmartRefresher(
                    controller: refreshController,
                    onRefresh: () async {
                      await notifier.fetchFromSupabase();
                      refreshController.refreshCompleted();
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                          child: EntryCard(entry: e),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddEntryScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
    );
  }
}
