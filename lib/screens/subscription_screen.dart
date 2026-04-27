import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  SubscriptionPlan? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _selectedPlan = SubscriptionPlan.month; // Default selection
    _initializePurchases();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initializePurchases() async {
    // Check if in-app purchases are available
    _isAvailable = await _inAppPurchase.isAvailable();
    
    if (!_isAvailable) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        _showError(error.toString());
      },
    );

    // Load products
    await _loadProducts();
    
    // Auto-restore purchases to sync latest status
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    final productIds = <String>{
      SubscriptionService.weeklyProductId,
      SubscriptionService.monthlyProductId,
      SubscriptionService.yearlyProductId,
      SubscriptionService.lifetimeProductId,
    };

    try {
      final response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }

      setState(() {
        _products = response.productDetails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      setState(() => _isPurchasing = true);
    } else {
      setState(() => _isPurchasing = false);
      
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify and deliver the purchase
        await _deliverPurchase(purchase);
      }
      
      if (purchase.status == PurchaseStatus.error) {
        _showError(purchase.error?.message ?? 'Purchase failed');
      }
      
      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final plan = SubscriptionService.getPlanFromProductId(purchase.productID);
    if (plan != null) {
      final subscriptionService = context.read<SubscriptionService>();
      await subscriptionService.activateSubscription(plan);
      
      if (mounted) {
        _showSuccess();
      }
    }
  }

  Future<void> _buySubscription(SubscriptionPlan plan) async {
    if (_isPurchasing) return;

    // Find the product
    final productId = SubscriptionService.getProductId(plan);
    ProductDetails? product;
    
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      _showError('Product not available. Please try again later.');
      return;
    }

    setState(() => _isPurchasing = true);

    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      // Use buyNonConsumable for subscriptions and lifetime
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      setState(() => _isPurchasing = false);
      _showError('Failed to start purchase. Please try again.');
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    
    try {
      await _inAppPurchase.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<AppLocalizations>().tr('restore_initiated')),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to restore purchases');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.read<AppTheme>().currentThemeData.error,
      ),
    );
  }

  void _showSuccess() {
    if (!mounted) return;
    final l10n = context.read<AppLocalizations>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tr('subscription_activated')),
        backgroundColor: context.read<AppTheme>().currentThemeData.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final t = theme.currentThemeData;
    final l10n = context.watch<AppLocalizations>();
    final subscriptionService = context.watch<SubscriptionService>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        title: Text(l10n.tr('vixel_pro'), style: TextStyle(color: t.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: t.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pro badge
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFFA500),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFD700).withAlpha(77),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Title
                  Text(
                    l10n.tr('unlock_vixel_pro'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),

                  Text(
                    l10n.tr('pro_description'),
                    style: TextStyle(
                      fontSize: 14,
                      color: t.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),

                  // Current status (if pro)
                  if (subscriptionService.isPro) ...[
                    _CurrentSubscriptionCard(
                      subscriptionService: subscriptionService,
                      theme: t,
                      l10n: l10n,
                    ),
                    SizedBox(height: 24),
                  ],

                  // Benefits
                  _BenefitsSection(theme: t, l10n: l10n),
                  SizedBox(height: 32),

                  // Pricing plans
                  if (!subscriptionService.isPro) ...[
                    Text(
                      l10n.tr('choose_your_plan'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Plan cards
                    _PlanCard(
                      plan: SubscriptionPlan.week,
                      isSelected: _selectedPlan == SubscriptionPlan.week,
                      onTap: () => setState(() => _selectedPlan = SubscriptionPlan.week),
                      theme: t,
                      l10n: l10n,
                    ),
                    SizedBox(height: 12),

                    _PlanCard(
                      plan: SubscriptionPlan.month,
                      isSelected: _selectedPlan == SubscriptionPlan.month,
                      onTap: () => setState(() => _selectedPlan = SubscriptionPlan.month),
                      theme: t,
                      l10n: l10n,
                    ),
                    SizedBox(height: 12),

                    _PlanCard(
                      plan: SubscriptionPlan.year,
                      isSelected: _selectedPlan == SubscriptionPlan.year,
                      onTap: () => setState(() => _selectedPlan = SubscriptionPlan.year),
                      theme: t,
                      l10n: l10n,
                      isPopular: true,
                    ),
                    SizedBox(height: 12),

                    _PlanCard(
                      plan: SubscriptionPlan.lifetime,
                      isSelected: _selectedPlan == SubscriptionPlan.lifetime,
                      onTap: () => setState(() => _selectedPlan = SubscriptionPlan.lifetime),
                      theme: t,
                      l10n: l10n,
                      isBestValue: true,
                    ),
                    SizedBox(height: 24),

                    // Subscribe button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPurchasing || _selectedPlan == null
                            ? null
                            : () => _buySubscription(_selectedPlan!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: t.surfaceVariant,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isPurchasing
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black54,
                                ),
                              )
                            : Text(
                                l10n.tr('subscribe_now'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Restore purchases
                  TextButton(
                    onPressed: _restorePurchases,
                    child: Text(
                      l10n.tr('restore_purchases'),
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Terms
                  Text(
                    l10n.tr('subscription_terms'),
                    style: TextStyle(
                      fontSize: 11,
                      color: t.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  final SubscriptionService subscriptionService;
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _CurrentSubscriptionCard({
    required this.subscriptionService,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700).withAlpha(51),
            Color(0xFFFFA500).withAlpha(51),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFFD700).withAlpha(128),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                color: Color(0xFFFFD700),
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('pro_active'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      '${subscriptionService.planDisplayName} ${l10n.tr('plan')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subscriptionService.expiryDate != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.event,
                  color: theme.textMuted,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  '${l10n.tr('expires')}: ${_formatDate(subscriptionService.expiryDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textMuted,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.success.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subscriptionService.daysRemaining} ${l10n.tr('days_left')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _BenefitsSection extends StatelessWidget {
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _BenefitsSection({
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final benefits = [
      {'icon': Icons.all_inclusive, 'text': l10n.tr('benefit_unlimited_operations')},
      {'icon': Icons.flash_on, 'text': l10n.tr('benefit_all_features')},
      {'icon': Icons.timer_off, 'text': l10n.tr('benefit_no_waiting')},
      {'icon': Icons.support_agent, 'text': l10n.tr('benefit_priority_support')},
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tr('pro_benefits'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textMuted,
            ),
          ),
          SizedBox(height: 16),
          ...benefits.map((benefit) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    benefit['icon'] as IconData,
                    color: theme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    benefit['text'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeData theme;
  final AppLocalizations l10n;
  final bool isPopular;
  final bool isBestValue;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.l10n,
    this.isPopular = false,
    this.isBestValue = false,
  });

  String get _planName {
    switch (plan) {
      case SubscriptionPlan.week:
        return l10n.tr('weekly');
      case SubscriptionPlan.month:
        return l10n.tr('monthly');
      case SubscriptionPlan.year:
        return l10n.tr('yearly');
      case SubscriptionPlan.lifetime:
        return l10n.tr('lifetime');
      default:
        return '';
    }
  }

  String get _duration {
    switch (plan) {
      case SubscriptionPlan.week:
        return '7 ${l10n.tr('days')}';
      case SubscriptionPlan.month:
        return '30 ${l10n.tr('days')}';
      case SubscriptionPlan.year:
        return '365 ${l10n.tr('days')}';
      case SubscriptionPlan.lifetime:
        return l10n.tr('forever');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = SubscriptionService.formatPrice(plan);
    final perDay = SubscriptionService.getPerDayPrice(plan);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? theme.primary.withAlpha(26) : theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? theme.primary : theme.surfaceVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Radio indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? theme.primary : theme.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 14),
                
                // Plan details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _planName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _duration,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      perDay,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Badge
          if (isPopular || isBestValue)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBestValue ? Color(0xFFFFD700) : theme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isBestValue ? l10n.tr('best_value') : l10n.tr('popular'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isBestValue ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
