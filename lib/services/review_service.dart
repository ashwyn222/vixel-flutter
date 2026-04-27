import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle in-app review prompts at strategic moments
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  static const String _successfulOpsKey = 'vixel_successful_operations';
  static const String _lastReviewPromptKey = 'vixel_last_review_prompt';
  static const String _hasReviewedKey = 'vixel_has_reviewed';
  
  /// Number of successful operations before prompting for review
  static const int triggerAtOperations = 5;
  
  /// Minimum days between review prompts
  static const int cooldownDays = 30;

  final InAppReview _inAppReview = InAppReview.instance;
  
  int _successfulOperations = 0;
  DateTime? _lastReviewPrompt;
  bool _hasReviewed = false;
  bool _isInitialized = false;

  int get successfulOperations => _successfulOperations;
  bool get hasReviewed => _hasReviewed;

  /// Initialize the service and load persisted data
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _successfulOperations = prefs.getInt(_successfulOpsKey) ?? 0;
      _hasReviewed = prefs.getBool(_hasReviewedKey) ?? false;
      
      final lastPromptMillis = prefs.getInt(_lastReviewPromptKey);
      if (lastPromptMillis != null) {
        _lastReviewPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
      }
      
      _isInitialized = true;
      debugPrint('[ReviewService] Initialized: $_successfulOperations successful ops, hasReviewed: $_hasReviewed');
    } catch (e) {
      debugPrint('[ReviewService] Error initializing: $e');
    }
  }

  /// Record a successful operation and check if we should prompt for review
  /// Returns true if review prompt was triggered
  Future<bool> recordSuccessfulOperation() async {
    _successfulOperations++;
    await _saveSuccessfulOperations();
    
    debugPrint('[ReviewService] Operation #$_successfulOperations completed');
    
    // Check if we should prompt for review
    if (shouldPromptForReview()) {
      return await requestReview();
    }
    
    return false;
  }

  /// Check if conditions are met to prompt for review
  bool shouldPromptForReview() {
    // Already reviewed - don't bother them again
    if (_hasReviewed) {
      debugPrint('[ReviewService] User has already reviewed');
      return false;
    }
    
    // Not enough operations yet
    if (_successfulOperations < triggerAtOperations) {
      debugPrint('[ReviewService] Only $_successfulOperations ops, need $triggerAtOperations');
      return false;
    }
    
    // Check cooldown period
    if (_lastReviewPrompt != null) {
      final daysSinceLastPrompt = DateTime.now().difference(_lastReviewPrompt!).inDays;
      if (daysSinceLastPrompt < cooldownDays) {
        debugPrint('[ReviewService] Cooldown active: $daysSinceLastPrompt days since last prompt');
        return false;
      }
    }
    
    // Only trigger on exact milestones: 5, 10, 20, 50, 100...
    final milestones = [5, 10, 20, 50, 100, 200, 500];
    if (!milestones.contains(_successfulOperations)) {
      return false;
    }
    
    debugPrint('[ReviewService] Conditions met for review prompt!');
    return true;
  }

  /// Request the in-app review
  Future<bool> requestReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      
      if (!isAvailable) {
        debugPrint('[ReviewService] In-app review not available');
        return false;
      }
      
      // Record that we're prompting
      _lastReviewPrompt = DateTime.now();
      await _saveLastReviewPrompt();
      
      // Request the review - Google controls whether it actually shows
      await _inAppReview.requestReview();
      
      // Assume they reviewed after seeing the prompt
      // (We can't actually know if they did)
      _hasReviewed = true;
      await _saveHasReviewed();
      
      debugPrint('[ReviewService] Review requested successfully');
      return true;
    } catch (e) {
      debugPrint('[ReviewService] Error requesting review: $e');
      return false;
    }
  }

  /// Open the app's Play Store page for manual review
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: '', // iOS only
      );
    } catch (e) {
      debugPrint('[ReviewService] Error opening store listing: $e');
    }
  }

  /// Reset review tracking (for testing)
  Future<void> reset() async {
    _successfulOperations = 0;
    _lastReviewPrompt = null;
    _hasReviewed = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_successfulOpsKey);
    await prefs.remove(_lastReviewPromptKey);
    await prefs.remove(_hasReviewedKey);
    
    debugPrint('[ReviewService] Reset complete');
  }

  // Persistence methods
  Future<void> _saveSuccessfulOperations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_successfulOpsKey, _successfulOperations);
  }

  Future<void> _saveLastReviewPrompt() async {
    if (_lastReviewPrompt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReviewPromptKey, _lastReviewPrompt!.millisecondsSinceEpoch);
  }

  Future<void> _saveHasReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasReviewedKey, _hasReviewed);
  }
}
