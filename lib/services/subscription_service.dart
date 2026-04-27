import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum SubscriptionPlan {
  free,
  week,
  month,
  year,
  lifetime,
}

class SubscriptionService extends ChangeNotifier {
  static const String _isProKey = 'vixel_is_pro';
  static const String _planKey = 'vixel_subscription_plan';
  static const String _expiryKey = 'vixel_subscription_expiry';
  static const String _purchaseDateKey = 'vixel_purchase_date';

  bool _isPro = false;
  SubscriptionPlan _plan = SubscriptionPlan.free;
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _isInitialized = false;

  // Getters
  bool get isPro => _isPro && !isExpired;
  bool get isExpired => _expiryDate != null && DateTime.now().isAfter(_expiryDate!);
  SubscriptionPlan get plan => _plan;
  DateTime? get expiryDate => _expiryDate;
  DateTime? get purchaseDate => _purchaseDate;
  bool get isInitialized => _isInitialized;

  /// Days remaining in subscription
  int get daysRemaining {
    if (!_isPro || _expiryDate == null) return 0;
    final remaining = _expiryDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Subscription plan display name
  String get planDisplayName {
    switch (_plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.week:
        return 'Weekly';
      case SubscriptionPlan.month:
        return 'Monthly';
      case SubscriptionPlan.year:
        return 'Yearly';
      case SubscriptionPlan.lifetime:
        return 'Lifetime';
    }
  }

  /// Product IDs for in-app purchases (configure in Play Console / App Store Connect)
  static const String weeklyProductId = 'vixel_pro_weekly';
  static const String monthlyProductId = 'vixel_pro_monthly';
  static const String yearlyProductId = 'vixel_pro_yearly';
  static const String lifetimeProductId = 'vixel_pro_lifetime';

  /// Pricing in INR
  static const Map<SubscriptionPlan, int> pricing = {
    SubscriptionPlan.week: 39,
    SubscriptionPlan.month: 99,
    SubscriptionPlan.year: 349,
    SubscriptionPlan.lifetime: 999,
  };

  /// Duration for each plan (lifetime = 100 years effectively)
  static const Map<SubscriptionPlan, Duration> planDurations = {
    SubscriptionPlan.week: Duration(days: 7),
    SubscriptionPlan.month: Duration(days: 30),
    SubscriptionPlan.year: Duration(days: 365),
    SubscriptionPlan.lifetime: Duration(days: 36500), // ~100 years
  };

  /// Initialize subscription service
  Future<void> init() async {
    await _loadSubscription();
    _isInitialized = true;
    
    // Check if subscription has expired
    if (_isPro && isExpired) {
      await _handleExpiredSubscription();
    }
    
    // Auto-restore purchases on app launch to sync with Google Play
    await restorePurchases();
    
    notifyListeners();
  }

  /// Restore purchases from Google Play / App Store
  /// This syncs the subscription status with the stores
  Future<void> restorePurchases() async {
    try {
      final inAppPurchase = InAppPurchase.instance;
      final isAvailable = await inAppPurchase.isAvailable();
      
      if (!isAvailable) return;

      // Track if we had a local subscription before restore
      final bool hadLocalSubscription = _isPro;
      // Track if we found any active purchases during restore
      bool foundActivePurchase = false;
      
      // Listen for restored purchases
      StreamSubscription<List<PurchaseDetails>>? subscription;
      
      subscription = inAppPurchase.purchaseStream.listen(
        (purchaseDetailsList) async {
          for (var purchase in purchaseDetailsList) {
            // Only process active purchases (not error or cancelled)
            if (purchase.status == PurchaseStatus.restored ||
                purchase.status == PurchaseStatus.purchased) {
              final plan = getPlanFromProductId(purchase.productID);
              if (plan != null) {
                foundActivePurchase = true;
                // Verify and activate the subscription
                await activateSubscription(plan);
              }
            }
            
            // Complete pending purchases
            if (purchase.pendingCompletePurchase) {
              await inAppPurchase.completePurchase(purchase);
            }
          }
        },
        onDone: () {
          subscription?.cancel();
        },
        onError: (error) {
          subscription?.cancel();
          print('Error in purchase stream: $error');
        },
      );

      // Trigger restore
      await inAppPurchase.restorePurchases();
      
      // Wait for restore to complete (increased timeout for reliability)
      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();
      
      // If we had a local subscription but no active purchases were found,
      // the subscription was likely cancelled - clear it
      if (hadLocalSubscription && !foundActivePurchase) {
        print('No active purchases found during restore. Subscription may be cancelled. Clearing local subscription.');
        await clearSubscription();
      }
      
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }

  /// Load subscription from SharedPreferences
  Future<void> _loadSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool(_isProKey) ?? false;
      
      final planIndex = prefs.getInt(_planKey);
      if (planIndex != null && planIndex < SubscriptionPlan.values.length) {
        _plan = SubscriptionPlan.values[planIndex];
      }
      
      final expiryStr = prefs.getString(_expiryKey);
      if (expiryStr != null) {
        _expiryDate = DateTime.tryParse(expiryStr);
      }
      
      final purchaseStr = prefs.getString(_purchaseDateKey);
      if (purchaseStr != null) {
        _purchaseDate = DateTime.tryParse(purchaseStr);
      }
    } catch (e) {
      print('Error loading subscription: $e');
    }
  }

  /// Save subscription to SharedPreferences
  Future<void> _saveSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isProKey, _isPro);
      await prefs.setInt(_planKey, _plan.index);
      
      if (_expiryDate != null) {
        await prefs.setString(_expiryKey, _expiryDate!.toIso8601String());
      } else {
        await prefs.remove(_expiryKey);
      }
      
      if (_purchaseDate != null) {
        await prefs.setString(_purchaseDateKey, _purchaseDate!.toIso8601String());
      } else {
        await prefs.remove(_purchaseDateKey);
      }
    } catch (e) {
      print('Error saving subscription: $e');
    }
  }

  /// Handle expired subscription
  Future<void> _handleExpiredSubscription() async {
    _isPro = false;
    _plan = SubscriptionPlan.free;
    _expiryDate = null;
    _purchaseDate = null;
    await _saveSubscription();
    notifyListeners();
  }

  /// Activate a subscription (called after successful purchase)
  Future<void> activateSubscription(SubscriptionPlan plan) async {
    final duration = planDurations[plan];
    if (duration == null) return;

    _isPro = true;
    _plan = plan;
    _purchaseDate = DateTime.now();
    _expiryDate = DateTime.now().add(duration);
    
    await _saveSubscription();
    notifyListeners();
  }

  /// Restore subscription from app store
  /// This will be called when restorePurchases returns valid purchases
  Future<void> restoreSubscription({
    required SubscriptionPlan plan,
    required DateTime expiryDate,
  }) async {
    if (expiryDate.isAfter(DateTime.now())) {
      _isPro = true;
      _plan = plan;
      _expiryDate = expiryDate;
      await _saveSubscription();
      notifyListeners();
    }
  }

  /// Clear subscription (for testing or when cancelled)
  Future<void> clearSubscription() async {
    _isPro = false;
    _plan = SubscriptionPlan.free;
    _expiryDate = null;
    _purchaseDate = null;
    await _saveSubscription();
    notifyListeners();
  }

  /// Get product ID for a plan
  static String getProductId(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.week:
        return weeklyProductId;
      case SubscriptionPlan.month:
        return monthlyProductId;
      case SubscriptionPlan.year:
        return yearlyProductId;
      case SubscriptionPlan.lifetime:
        return lifetimeProductId;
      case SubscriptionPlan.free:
        return '';
    }
  }

  /// Get plan from product ID
  static SubscriptionPlan? getPlanFromProductId(String productId) {
    switch (productId) {
      case weeklyProductId:
        return SubscriptionPlan.week;
      case monthlyProductId:
        return SubscriptionPlan.month;
      case yearlyProductId:
        return SubscriptionPlan.year;
      case lifetimeProductId:
        return SubscriptionPlan.lifetime;
      default:
        return null;
    }
  }

  /// Format price for display
  static String formatPrice(SubscriptionPlan plan) {
    final price = pricing[plan];
    if (price == null) return 'Free';
    return '₹$price';
  }

  /// Get per-day price for comparison
  static String getPerDayPrice(SubscriptionPlan plan) {
    if (plan == SubscriptionPlan.lifetime) {
      return 'One-time';
    }
    
    final price = pricing[plan];
    final duration = planDurations[plan];
    if (price == null || duration == null) return '';
    
    final perDay = price / duration.inDays;
    return '₹${perDay.toStringAsFixed(1)}/day';
  }
}
