import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subscription_service.dart';
import 'auth_service.dart';

/// Service to track daily operation limits for free users
/// Uses Firestore when signed in, falls back to local storage otherwise
class OperationTrackerService extends ChangeNotifier {
  static const String _operationsKey = 'vixel_operations';
  static const int freeOperationLimit = 3;
  static const Duration operationWindow = Duration(hours: 24);

  List<DateTime> _operationTimestamps = [];
  SubscriptionService? _subscriptionService;
  AuthService? _authService;
  bool _isInitialized = false;
  bool _isSyncing = false;

  // Firestore reference
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  
  /// Get count of operations in the last 24 hours
  int get operationsUsed {
    _cleanupExpiredOperations();
    return _operationTimestamps.length;
  }

  /// Get remaining operations for free users
  int get remainingOperations {
    if (_subscriptionService?.isPro == true) {
      return -1; // -1 indicates unlimited
    }
    return (freeOperationLimit - operationsUsed).clamp(0, freeOperationLimit);
  }

  /// Check if user can perform an operation
  bool get canPerformOperation {
    if (_subscriptionService?.isPro == true) {
      return true; // Pro users have unlimited
    }
    return remainingOperations > 0;
  }

  /// Get time until next operation is available (for free users at limit)
  Duration? get timeUntilNextOperation {
    if (canPerformOperation) return null;
    if (_operationTimestamps.isEmpty) return null;

    // Find the oldest operation
    _operationTimestamps.sort();
    final oldest = _operationTimestamps.first;
    final expiresAt = oldest.add(operationWindow);
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Format time until next operation for display
  String get timeUntilNextOperationFormatted {
    final duration = timeUntilNextOperation;
    if (duration == null) return '';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Less than a minute';
    }
  }

  /// Initialize the service
  Future<void> init(SubscriptionService subscriptionService, {AuthService? authService}) async {
    _subscriptionService = subscriptionService;
    _authService = authService;
    
    // Listen to auth changes to sync operations
    _authService?.addListener(_onAuthChange);
    
    await _loadOperations();
    _isInitialized = true;
    notifyListeners();
  }

  /// Handle auth state changes
  void _onAuthChange() async {
    if (_authService?.isSignedIn == true) {
      // User just signed in, sync from cloud
      await _syncFromCloud();
    }
    notifyListeners();
  }

  /// Load operations (from cloud if signed in, otherwise local)
  Future<void> _loadOperations() async {
    if (_authService?.isSignedIn == true && _authService?.userId != null) {
      await _loadFromCloud();
    } else {
      await _loadFromLocal();
    }
    _cleanupExpiredOperations();
  }

  /// Load operations from Firestore
  Future<void> _loadFromCloud() async {
    try {
      final userId = _authService?.userId;
      if (userId == null) return;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('operations')
          .doc('tracker')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List<dynamic> timestamps = data['timestamps'] ?? [];
        _operationTimestamps = timestamps
            .map((e) => DateTime.tryParse(e as String))
            .whereType<DateTime>()
            .toList();
      } else {
        // First time user - check for local operations and migrate
        await _loadFromLocal();
        if (_operationTimestamps.isNotEmpty) {
          await _saveToCloud();
        }
      }
    } catch (e) {
      print('Error loading operations from cloud: $e');
      // Fall back to local
      await _loadFromLocal();
    }
  }

  /// Load operations from SharedPreferences
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_operationsKey);
      
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _operationTimestamps = list
            .map((e) => DateTime.tryParse(e as String))
            .whereType<DateTime>()
            .toList();
      }
    } catch (e) {
      print('Error loading operations from local: $e');
      _operationTimestamps = [];
    }
  }

  /// Sync operations from cloud (called after sign-in)
  Future<void> _syncFromCloud() async {
    if (_authService?.userId == null) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      // Load local operations
      final localOps = List<DateTime>.from(_operationTimestamps);
      
      // Load cloud operations
      await _loadFromCloud();
      
      // Merge: keep all unique operations from both sources
      final allOps = {...localOps, ..._operationTimestamps};
      _operationTimestamps = allOps.toList();
      _cleanupExpiredOperations();
      
      // Save merged result to both cloud and local
      await _saveOperations();
    } catch (e) {
      print('Error syncing from cloud: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Save operations to appropriate storage
  Future<void> _saveOperations() async {
    await _saveToLocal();
    
    if (_authService?.isSignedIn == true && _authService?.userId != null) {
      await _saveToCloud();
    }
  }

  /// Save operations to Firestore
  Future<void> _saveToCloud() async {
    try {
      final userId = _authService?.userId;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('operations')
          .doc('tracker')
          .set({
        'timestamps': _operationTimestamps.map((e) => e.toIso8601String()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving operations to cloud: $e');
    }
  }

  /// Save operations to SharedPreferences
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(
        _operationTimestamps.map((e) => e.toIso8601String()).toList(),
      );
      await prefs.setString(_operationsKey, jsonStr);
    } catch (e) {
      print('Error saving operations to local: $e');
    }
  }

  /// Remove operations older than 24 hours
  void _cleanupExpiredOperations() {
    final cutoff = DateTime.now().toUtc().subtract(operationWindow);
    _operationTimestamps.removeWhere((t) => t.isBefore(cutoff));
  }

  /// Record a new operation
  /// Returns true if operation was recorded, false if limit reached
  Future<bool> recordOperation() async {
    // Pro users don't need to record
    if (_subscriptionService?.isPro == true) {
      return true;
    }

    // Check if limit reached
    if (!canPerformOperation) {
      return false;
    }

    // Record the operation
    _operationTimestamps.add(DateTime.now().toUtc());
    await _saveOperations();
    notifyListeners();
    
    return true;
  }

  /// Check if user can perform operation (without recording)
  /// Returns a result with details
  OperationCheckResult checkOperation() {
    if (_subscriptionService?.isPro == true) {
      return OperationCheckResult(
        canProceed: true,
        isPro: true,
        remainingOperations: -1,
      );
    }

    _cleanupExpiredOperations();
    final remaining = remainingOperations;
    
    return OperationCheckResult(
      canProceed: remaining > 0,
      isPro: false,
      remainingOperations: remaining,
      timeUntilNext: remaining <= 0 ? timeUntilNextOperation : null,
    );
  }

  /// Clear all operation history (for testing)
  Future<void> clearOperations() async {
    _operationTimestamps.clear();
    await _saveOperations();
    notifyListeners();
  }

  /// Permanently delete the given user's operation data from Firestore.
  /// Best-effort: silently swallows errors. Used during account deletion.
  Future<void> deleteCloudData(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('operations')
          .doc('tracker')
          .delete();
    } catch (e) {
      print('Failed to delete cloud operations doc: $e');
    }
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (_) {
      // Parent doc may not exist; ignore.
    }
  }

  /// Get operation history for display (debugging)
  List<DateTime> get operationHistory => List.unmodifiable(_operationTimestamps);

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChange);
    super.dispose();
  }
}

/// Result of checking if an operation can be performed
class OperationCheckResult {
  final bool canProceed;
  final bool isPro;
  final int remainingOperations; // -1 for unlimited (Pro)
  final Duration? timeUntilNext;

  OperationCheckResult({
    required this.canProceed,
    required this.isPro,
    required this.remainingOperations,
    this.timeUntilNext,
  });

  String get remainingText {
    if (isPro) return 'Unlimited';
    return '$remainingOperations/${OperationTrackerService.freeOperationLimit}';
  }
}
