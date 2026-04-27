import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/operation_tracker_service.dart';
import '../screens/subscription_screen.dart';

/// Dialog shown when free user reaches their daily operation limit
class UpgradePromptDialog extends StatelessWidget {
  final String? operationName;

  const UpgradePromptDialog({
    super.key,
    this.operationName,
  });

  /// Show the upgrade prompt dialog
  /// Returns true if user navigated to subscription screen
  static Future<bool> show(BuildContext context, {String? operationName}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpgradePromptDialog(operationName: operationName),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final t = theme.currentThemeData;
    final l10n = context.watch<AppLocalizations>();
    final tracker = context.watch<OperationTrackerService>();

    return Dialog(
      backgroundColor: t.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crown icon
            Container(
              width: 72,
              height: 72,
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
              ),
              child: Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 40,
              ),
            ),
            SizedBox(height: 20),

            // Title
            Text(
              l10n.tr('daily_limit_reached'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: t.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),

            // Subtitle
            Text(
              l10n.tr('upgrade_to_unlock'),
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),

            // Time until next operation
            if (tracker.timeUntilNextOperation != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: t.textMuted,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${l10n.tr('next_operation_in')} ${tracker.timeUntilNextOperationFormatted}',
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 24),

            // Pro benefits
            _BenefitsList(theme: t, l10n: l10n),
            SizedBox(height: 24),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium, size: 20),
                    SizedBox(width: 8),
                    Text(
                      l10n.tr('upgrade_to_pro'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // Maybe later button
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n.tr('maybe_later'),
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _BenefitsList({
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final benefits = [
      l10n.tr('benefit_unlimited_operations'),
      l10n.tr('benefit_all_features'),
      l10n.tr('benefit_no_waiting'),
    ];

    return Column(
      children: benefits.map((benefit) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.success,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  benefit,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
