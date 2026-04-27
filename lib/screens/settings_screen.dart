import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/storage_service.dart';
import '../services/job_service.dart';
import '../services/file_picker_service.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../services/logging_service.dart';
import '../services/operation_tracker_service.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StorageInfo? _storageInfo;
  bool _isLoading = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    final info = await StorageService.getStorageInfo();
    setState(() {
      _storageInfo = info;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final t = theme.currentThemeData;
    final l10n = context.watch<AppLocalizations>();
    
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        title: Text(l10n.tr('settings'), style: TextStyle(color: t.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account section - NEW
            _AccountSection(theme: t, l10n: l10n),
            SizedBox(height: 24),
            
            // Subscription section
            _SubscriptionSection(theme: t, l10n: l10n),
            SizedBox(height: 24),

            // Privacy section
            _PrivacySection(theme: t, l10n: l10n),
            SizedBox(height: 24),
            
            // Theme section
            Text(
              l10n.tr('theme'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: AppThemeMode.values.map((mode) {
                  final themeData = AppTheme.themes[mode]!;
                  final isSelected = theme.currentMode == mode;
                  
                  return GestureDetector(
                    onTap: () => theme.setTheme(mode),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 40,
                          decoration: BoxDecoration(
                            color: themeData.previewColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                  ? t.primary 
                                  : (themeData.isDark ? Colors.white24 : Colors.black12),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: themeData.isDark ? Colors.white : Colors.black87,
                                  size: 20,
                                )
                              : null,
                        ),
                        SizedBox(height: 8),
                        Text(
                          themeData.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? t.textPrimary : t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 24),

            // File Picker section
            Text(
              l10n.tr('file_picker'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),

            Consumer<FilePickerService>(
              builder: (context, pickerService, _) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Picker type row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _PickerOption(
                            type: PickerType.files,
                            label: l10n.tr('picker_files'),
                            description: l10n.tr('picker_files_desc'),
                            icon: Icons.folder_open,
                            isSelected: pickerService.pickerType == PickerType.files,
                            onTap: () => pickerService.setPickerType(PickerType.files),
                            theme: t,
                          ),
                          SizedBox(width: 12),
                          _PickerOption(
                            type: PickerType.gallery,
                            label: l10n.tr('picker_gallery'),
                            description: l10n.tr('picker_gallery_desc'),
                            icon: Icons.grid_view_rounded,
                            isSelected: pickerService.pickerType == PickerType.gallery,
                            onTap: () => pickerService.setPickerType(PickerType.gallery),
                            theme: t,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Divider(color: t.surfaceVariant, height: 1),
                      SizedBox(height: 16),
                      // Concurrent jobs row
                      Row(
                        children: [
                          Icon(Icons.layers, size: 20, color: t.textMuted),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('concurrent_jobs'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: t.textPrimary,
                                  ),
                                ),
                                Text(
                                  l10n.tr('concurrent_jobs_desc'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Number selector
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ConcurrentJobButton(
                                value: 1,
                                isSelected: pickerService.maxConcurrentJobs == 1,
                                onTap: () => pickerService.setMaxConcurrentJobs(1),
                                theme: t,
                              ),
                              SizedBox(width: 8),
                              _ConcurrentJobButton(
                                value: 2,
                                isSelected: pickerService.maxConcurrentJobs == 2,
                                onTap: () => pickerService.setMaxConcurrentJobs(2),
                                theme: t,
                              ),
                              SizedBox(width: 8),
                              _ConcurrentJobButton(
                                value: 3,
                                isSelected: pickerService.maxConcurrentJobs == 3,
                                onTap: () => pickerService.setMaxConcurrentJobs(3),
                                theme: t,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 24),

            // Storage section
            Text(
              l10n.tr('storage'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_storageInfo != null) ...[
                    _StorageRow(
                      label: l10n.tr('total_storage_used'),
                      value: _storageInfo!.totalSizeFormatted,
                      icon: Icons.storage,
                      theme: t,
                    ),
                    Divider(color: t.surfaceVariant, height: 24),
                    _StorageRow(
                      label: l10n.tr('temporary_files'),
                      value: '${_storageInfo!.tempFiles} ${l10n.tr('files')}',
                      icon: Icons.folder_outlined,
                      theme: t,
                    ),
                    Divider(color: t.surfaceVariant, height: 24),
                    _StorageRow(
                      label: l10n.tr('output_files'),
                      value: '${_storageInfo!.outputFiles} ${l10n.tr('files')}',
                      icon: Icons.video_file_outlined,
                      theme: t,
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 16),

            // Clear buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: l10n.tr('clear_temp'),
                    icon: Icons.cleaning_services,
                    isLoading: _isClearing,
                    onTap: () => _clearFiles(tempOnly: true),
                    theme: t,
                    l10n: l10n,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: l10n.tr('clear_all'),
                    icon: Icons.delete_sweep,
                    isLoading: _isClearing,
                    isDestructive: true,
                    onTap: () => _clearFiles(tempOnly: false),
                    theme: t,
                    l10n: l10n,
                  ),
                ),
              ],
            ),

            SizedBox(height: 32),

            // About section
            Text(
              l10n.tr('about'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _AboutRow(label: l10n.tr('app_name'), value: 'Vixel', theme: t),
                  Divider(color: t.surfaceVariant, height: 24),
                  _AboutRow(label: l10n.tr('version'), value: '1.0.0', theme: t),
                ],
              ),
            ),

            SizedBox(height: 40),

            // Developer credit
            Center(
              child: Text(
                'Developed by Ashwin Sharma',
                style: TextStyle(
                  fontSize: 12,
                  color: t.textMuted.withAlpha(150),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _clearFiles({required bool tempOnly}) async {
    final t = context.read<AppTheme>().currentThemeData;
    final l10n = context.read<AppLocalizations>();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          tempOnly ? l10n.tr('clear_temporary_files') : l10n.tr('clear_all_files'),
          style: TextStyle(color: t.textPrimary),
        ),
        content: Text(
          tempOnly ? l10n.tr('clear_temp_message') : l10n.tr('clear_all_message'),
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.tr('cancel'), style: TextStyle(color: t.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: tempOnly ? t.primary : t.error,
            ),
            child: Text(l10n.tr('clear')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);

    final result = tempOnly
        ? await StorageService.clearTempFiles()
        : await StorageService.clearAllFiles();

    // Also clear all job records when clearing all files
    if (!tempOnly && mounted) {
      context.read<JobService>().clearAllJobs();
    }

    setState(() => _isClearing = false);

    if (mounted) {
      final t = context.read<AppTheme>().currentThemeData;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tempOnly
                ? 'Cleared ${result.deletedCount} files (${result.freedSpaceFormatted})'
                : 'Cleared ${result.deletedCount} files (${result.freedSpaceFormatted}) and all records',
          ),
          backgroundColor: t.success,
        ),
      );
      _loadStorageInfo();
    }
  }
}

class _AccountSection extends StatelessWidget {
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _AccountSection({
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isSignedIn = authService.isSignedIn;
    final isLoading = authService.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tr('account'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: isSignedIn
              ? _buildSignedInView(context, authService)
              : _buildSignedOutView(context, authService, isLoading),
        ),
        if (!isSignedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.tr('sign_in_benefit'),
              style: TextStyle(
                fontSize: 11,
                color: theme.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSignedInView(BuildContext context, AuthService authService) {
    return Column(
      children: [
        Row(
          children: [
            // User avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary.withAlpha(51),
                borderRadius: BorderRadius.circular(24),
              ),
              child: authService.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        authService.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          color: theme.primary,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: theme.primary,
                      size: 24,
                    ),
            ),
            SizedBox(width: 14),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authService.displayName ?? l10n.tr('user'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (authService.userEmail != null)
                    Text(
                      authService.userEmail!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textMuted,
                      ),
                    ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.cloud_done, size: 12, color: theme.success),
                      SizedBox(width: 4),
                      Text(
                        l10n.tr('synced'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Sign out button
            IconButton(
              onPressed: () => _showSignOutConfirmation(context, authService),
              icon: Icon(Icons.logout, color: theme.textMuted),
              tooltip: l10n.tr('sign_out'),
            ),
          ],
        ),
        SizedBox(height: 12),
        Divider(color: theme.surfaceVariant, height: 1),
        SizedBox(height: 8),
        // Delete account row
        InkWell(
          onTap: () => _showDeleteAccountConfirmation(context, authService),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.delete_forever, size: 20, color: theme.error),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('delete_account'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.error,
                        ),
                      ),
                      Text(
                        l10n.tr('delete_account_desc'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: theme.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountConfirmation(
    BuildContext context,
    AuthService authService,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.tr('delete_account_title'),
          style: TextStyle(color: theme.textPrimary),
        ),
        content: Text(
          l10n.tr('delete_account_message'),
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.tr('cancel'), style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _runDeleteAccount(context, authService);
            },
            style: TextButton.styleFrom(foregroundColor: theme.error),
            child: Text(l10n.tr('delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _runDeleteAccount(
    BuildContext context,
    AuthService authService,
  ) async {
    final uid = authService.userId ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final operationTracker = context.read<OperationTrackerService>();
    final loggingService = context.read<LoggingService>();

    if (uid.isNotEmpty) {
      // Best-effort cleanup of cloud data while we still hold a valid token.
      await operationTracker.deleteCloudData(uid);
      await loggingService.deleteUserLogs(uid);
    }

    final ok = await authService.deleteAccount();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.tr('account_deleted') : l10n.tr('delete_account_failed'),
        ),
        backgroundColor: ok ? theme.success : theme.error,
      ),
    );
    // On success, the auth state listener in main.dart automatically navigates
    // back to the SignInScreen.
  }

  Widget _buildSignedOutView(BuildContext context, AuthService authService, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : () => authService.signInWithGoogle(),
      child: Row(
        children: [
          // Google icon
          Container(
            width: 48,
            height: 48,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Image.network(
              'https://www.google.com/favicon.ico',
              errorBuilder: (_, __, ___) => Icon(
                Icons.g_mobiledata,
                color: Colors.red,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 14),
          // Sign in text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('sign_in_with_google'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  l10n.tr('sync_across_devices'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Arrow or loading
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.primary,
              ),
            )
          else
            Icon(Icons.chevron_right, color: theme.textMuted),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.tr('sign_out'),
          style: TextStyle(color: theme.textPrimary),
        ),
        content: Text(
          l10n.tr('sign_out_message'),
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.tr('cancel'), style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              authService.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: theme.error),
            child: Text(l10n.tr('sign_out')),
          ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final PickerType type;
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeData theme;

  const _PickerOption({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primary.withAlpha(26) : theme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? theme.primary : theme.textMuted,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.primary : theme.textSecondary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.textMuted,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelected) ...[
                SizedBox(height: 6),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConcurrentJobButton extends StatelessWidget {
  final int value;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeData theme;

  const _ConcurrentJobButton({
    required this.value,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? theme.primary : theme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : theme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final AppThemeData theme;

  const _StorageRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.textMuted),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeData theme;

  const _AboutRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: theme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isDestructive;
  final VoidCallback onTap;
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    this.isDestructive = false,
    required this.onTap,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? theme.error.withAlpha(26)
              : theme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? theme.error.withAlpha(77)
                : theme.surfaceVariant,
          ),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isDestructive ? theme.error : theme.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? theme.error : theme.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _PrivacySection({required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final logging = context.watch<LoggingService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tr('privacy'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.bug_report_outlined, size: 20, color: theme.textMuted),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('send_error_reports'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.tr('send_error_reports_desc'),
                      style: TextStyle(fontSize: 11, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: logging.enableRemoteLogging,
                activeColor: theme.primary,
                onChanged: (v) => logging.setEnableRemoteLogging(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _SubscriptionSection({
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionService = context.watch<SubscriptionService>();
    final isPro = subscriptionService.isPro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tr('subscription'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isPro
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFD700).withAlpha(51),
                        Color(0xFFFFA500).withAlpha(51),
                      ],
                    )
                  : null,
              color: isPro ? null : theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: isPro
                  ? Border.all(color: Color(0xFFFFD700).withAlpha(128))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.tr('vixel_pro'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                          if (isPro) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.tr('active').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        isPro
                            ? '${subscriptionService.daysRemaining} ${l10n.tr('days_left')}'
                            : l10n.tr('upgrade_to_unlock'),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
