import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../theme/app_theme.dart';

class ProcessingOverlay extends StatelessWidget {
  final int progress;
  final String? message;
  final VoidCallback? onCancel;
  final bool showProgress;

  const ProcessingOverlay({
    super.key,
    required this.progress,
    this.message,
    this.onCancel,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use a semi-transparent overlay that works for both light and dark themes
    return Container(
      color: AppTheme.background.withAlpha(230),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.background.withAlpha(77),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress)
                CircularPercentIndicator(
                  radius: 60,
                  lineWidth: 8,
                  percent: progress / 100,
                  center: Text(
                    '$progress%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  progressColor: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceVariant,
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: true,
                  animateFromLastPercent: true,
                  animationDuration: 300,
                )
              else
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppTheme.primary,
                  ),
                ),
              SizedBox(height: 24),
              Text(
                message ?? 'Processing...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                showProgress ? 'Please wait while your video is being processed' : 'This may take a moment',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (onCancel != null) ...[
                SizedBox(height: 24),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: Icon(Icons.close, size: 18),
                  label: Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

