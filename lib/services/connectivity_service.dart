

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'package:travlog_app/provider/entries_provider.dart';

// Provider to watch connectivity status
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// Provider to determine sync status for UI
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final entries = ref.watch(entriesNotifierProvider);
  final connectivity = ref.watch(connectivityProvider);
  
  final isOnline = connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => false,
    error: (_, __) => false,
  );
  
  // Check if there are any pending changes
  final hasPendingChanges = entries.any((entry) => 
    entry['needs_sync'] == true || 
    entry['sync_status'] == 'pending' || 
    entry['sync_status'] == 'modified' ||
    entry['sync_status'] == 'delete_pending'
  );
  
  if (!isOnline) {
    return hasPendingChanges ? SyncStatus.offlineWithChanges : SyncStatus.offline;
  }
  
  return hasPendingChanges ? SyncStatus.onlineWithChanges : SyncStatus.synced;
});

enum SyncStatus {
  synced,           // Green cloud - everything synced
  onlineWithChanges, // Orange cloud - online but has pending changes
  offlineWithChanges, // Red cloud - offline with pending changes
  offline,          // Gray cloud - offline but no changes
}

extension SyncStatusExtension on SyncStatus {
  String get displayText {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.onlineWithChanges:
        return 'Syncing...';
      case SyncStatus.offlineWithChanges:
        return 'Offline (Changes)';
      case SyncStatus.offline:
        return 'Offline';
    }
  }
  
  Color get color {
    switch (this) {
      case SyncStatus.synced:
        return const Color(0xFF27AE60); // Green
      case SyncStatus.onlineWithChanges:
        return const Color(0xFFF39C12); // Orange
      case SyncStatus.offlineWithChanges:
        return const Color(0xFFE74C3C); // Red
      case SyncStatus.offline:
        return const Color(0xFF95A5A6); // Gray
    }
  }
  
  IconData get icon {
    switch (this) {
      case SyncStatus.synced:
        return Icons.cloud_done;
      case SyncStatus.onlineWithChanges:
        return Icons.cloud_sync;
      case SyncStatus.offlineWithChanges:
        return Icons.cloud_off;
      case SyncStatus.offline:
        return Icons.cloud_outlined;
    }
  }
}