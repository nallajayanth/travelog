
// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travlog_app/provider/theme_provider.dart';
import 'package:travlog_app/screens/auth/login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully logged out')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final email =
        user?.email ?? 'nalla.jayanth3@gmail.com'; // Updated to match image
    final name =
        user?.userMetadata?['full_name'] ??
        'Jayanth Nalla'; // Updated to match image
    final avatarUrl =
        user?.userMetadata?['avatar_url'] ??
        'https://via.placeholder.com/50'; // Fallback avatar

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Subtle gradient background for premium feel
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceVariant,
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Profile Card
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(avatarUrl),
                      backgroundColor: Colors.blue,
                      child: avatarUrl.contains('placeholder')
                          ? const Text(
                              'J',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    subtitle: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(overflow: TextOverflow.ellipsis),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.edit, color: Colors.grey),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit profile coming soon'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Theme Mode
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    title: const Text('Theme Mode'),
                    subtitle: const Text('Light / Dark'),
                    value: themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).toggleTheme(value);
                    },
                    secondary: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    activeColor: Theme.of(context).colorScheme.primary,
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.dark_mode, color: Colors.white);
                      }
                      return const Icon(Icons.light_mode, color: Colors.white);
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                // Account Settings
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    leading: Icon(Icons.account_circle, color: Colors.green),
                    title: const Text('Account Settings'),
                    subtitle: const Text('Privacy & Security'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account settings coming soon'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Sync Settings
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    leading: Icon(Icons.sync, color: Colors.green),
                    title: const Text('Sync Settings'),
                    subtitle: Text(
                      'Auto-sync enabled',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Auto-sync is enabled for seamless data backup',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Backup & Restore
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    leading: Icon(Icons.backup, color: Colors.blue),
                    title: const Text('Backup & Restore'),
                    subtitle: const Text('Last backup: Today'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup completed successfully'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Logout
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text('Sign out of your account'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.red,
                    ),
                    onTap: () => _logout(context),
                  ),
                ),
                const SizedBox(height: 32),
                // Version
                Center(
                  child: Text(
                    'Travel Journal\nVersion 1.2.0',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
