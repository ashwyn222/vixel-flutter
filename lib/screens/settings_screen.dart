import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/storage_service.dart';
import '../services/job_service.dart';

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
            // Theme section - FIRST
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

            // Language section - SECOND
            Text(
              l10n.tr('language'),
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
                children: [
                  _LanguageOption(
                    language: AppLanguage.english,
                    label: 'English',
                    flag: '🇬🇧',
                    isSelected: l10n.currentLanguage == AppLanguage.english,
                    onTap: () => l10n.setLanguage(AppLanguage.english),
                    theme: t,
                  ),
                  SizedBox(width: 16),
                  _LanguageOption(
                    language: AppLanguage.hindi,
                    label: 'हिंदी',
                    flag: '🇮🇳',
                    isSelected: l10n.currentLanguage == AppLanguage.hindi,
                    onTap: () => l10n.setLanguage(AppLanguage.hindi),
                    theme: t,
                  ),
                ],
              ),
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
                  Divider(color: t.surfaceVariant, height: 24),
                  _AboutRow(label: l10n.tr('built_with'), value: 'Flutter + FFmpeg', theme: t),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.info.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: t.info.withAlpha(51),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: t.info, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.tr('vixel_info'),
                      style: TextStyle(
                        fontSize: 13,
                        color: t.info,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // FFmpeg features
            Text(
              l10n.tr('powered_by_ffmpeg'),
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
                  _FeatureRow(
                    icon: Icons.compress,
                    title: l10n.tr('video_compression'),
                    subtitle: l10n.tr('h264_encoding'),
                    theme: t,
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.content_cut,
                    title: l10n.tr('lossless_cutting'),
                    subtitle: l10n.tr('stream_copy'),
                    theme: t,
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.layers,
                    title: l10n.tr('video_merging'),
                    subtitle: l10n.tr('concat_filter'),
                    theme: t,
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.music_note,
                    title: l10n.tr('audio_processing'),
                    subtitle: l10n.tr('extract_mix_add'),
                    theme: t,
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.photo_library,
                    title: l10n.tr('slideshow_creation'),
                    subtitle: l10n.tr('xfade_transitions'),
                    theme: t,
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.branding_watermark,
                    title: l10n.tr('watermarking'),
                    subtitle: l10n.tr('overlay_images_text'),
                    theme: t,
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),
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

class _LanguageOption extends StatelessWidget {
  final AppLanguage language;
  final String label;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeData theme;

  const _LanguageOption({
    required this.language,
    required this.label,
    required this.flag,
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? theme.primary.withAlpha(26) : theme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                flag,
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.primary : theme.textSecondary,
                ),
              ),
              if (isSelected) ...[
                SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 18,
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppThemeData theme;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.primary),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
