import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final t = theme.currentThemeData;
    final l10n = context.watch<AppLocalizations>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // App Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: t.primary.withAlpha(77),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'Vixel',
                style: GoogleFonts.pacifico(
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  color: t.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 6),
              
              Text(
                l10n.tr('app_tagline'),
                style: TextStyle(
                  fontSize: 14,
                  color: t.textMuted,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(flex: 2),
              
              // Key benefits
              _BenefitChip(icon: Icons.auto_awesome, text: l10n.tr('benefit_all_in_one'), theme: t),
              const SizedBox(height: 8),
              _BenefitChip(icon: Icons.wifi_off, text: l10n.tr('benefit_no_internet'), theme: t),
              const SizedBox(height: 8),
              _BenefitChip(icon: Icons.sync, text: l10n.tr('benefit_sync_devices'), theme: t),
              
              const Spacer(flex: 2),
              
              // Error message
              if (authService.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.error.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.error.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: t.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authService.error!,
                          style: TextStyle(color: t.error, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => authService.clearError(),
                        child: Icon(Icons.close, color: t.error, size: 18),
                      ),
                    ],
                  ),
                ),
              
              // Sign in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: authService.isLoading 
                      ? null 
                      : () => authService.signInWithGoogle(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    elevation: 0,
                  ),
                  child: authService.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.primary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.g_mobiledata,
                                color: Colors.red,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.tr('continue_with_google'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Terms text
              Text(
                l10n.tr('sign_in_terms'),
                style: TextStyle(
                  fontSize: 12,
                  color: t.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppThemeData theme;

  const _BenefitChip({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: theme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

