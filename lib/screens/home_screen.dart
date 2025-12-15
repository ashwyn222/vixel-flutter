import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/job_service.dart';
import 'compress_video_screen.dart';
import 'cut_video_screen.dart';
import 'merge_videos_screen.dart';
import 'extract_audio_screen.dart';
import 'audio_on_video_screen.dart';
import 'photos_to_video_screen.dart';
import 'add_watermark_screen.dart';
import 'play_video_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final t = theme.currentThemeData;
    final l10n = context.watch<AppLocalizations>();
    
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vixel',
                      style: GoogleFonts.pacifico(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: t.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _navigateTo(context, const SettingsScreen()),
                      icon: Icon(Icons.settings_outlined),
                      color: t.textSecondary,
                      tooltip: l10n.tr('settings'),
                    ),
                  ],
                ),
              ),
            ),

            // Records & Play Video cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _RecordsCard(
                        onTap: () => _navigateTo(context, const RecordsScreen()),
                        theme: t,
                        l10n: l10n,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _PlayCard(
                        onTap: () => _navigateTo(context, const PlayVideoScreen()),
                        theme: t,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video Editing Section
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.tr('video_editing'), theme: t),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.compress,
                        label: l10n.tr('compress'),
                        color: t.compressColor,
                        onTap: () => _navigateTo(context, const CompressVideoScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.content_cut,
                        label: l10n.tr('cut'),
                        color: t.cutColor,
                        onTap: () => _navigateTo(context, const CutVideoScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.layers,
                        label: l10n.tr('merge'),
                        color: t.mergeColor,
                        onTap: () => _navigateTo(context, const MergeVideosScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Audio Operations Section
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.tr('audio_operations'), theme: t),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.music_note,
                        label: l10n.tr('extract_audio'),
                        color: t.extractAudioColor,
                        onTap: () => _navigateTo(context, const ExtractAudioScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.mic,
                        label: l10n.tr('audio_on_video'),
                        color: t.audioOnVideoColor,
                        onTap: () => _navigateTo(context, const AudioOnVideoScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Creative Tools Section
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.tr('creative_tools'), theme: t),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.photo_library,
                        label: l10n.tr('photos_to_video'),
                        color: t.photosToVideoColor,
                        onTap: () => _navigateTo(context, const PhotosToVideoScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.branding_watermark,
                        label: l10n.tr('add_watermark'),
                        color: t.watermarkColor,
                        onTap: () => _navigateTo(context, const AddWatermarkScreen()),
                        theme: t,
                        themeMode: theme.currentMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  final VoidCallback onTap;
  final AppThemeData theme;
  final AppLocalizations l10n;

  const _RecordsCard({required this.onTap, required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Consumer<JobService>(
      builder: (context, jobService, _) {
        final hasJobs = jobService.totalJobs > 0;
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.list_alt,
                    color: theme.primary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: hasJobs
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.tr('records'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${jobService.activeJobCount > 0 ? "${jobService.activeJobCount} ${l10n.tr('active')}" : ""}${jobService.activeJobCount > 0 && jobService.completedJobCount > 0 ? " · " : ""}${jobService.completedJobCount > 0 ? "${jobService.completedJobCount} ${l10n.tr('done')}" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            l10n.tr('records'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                if (hasJobs)
                  Icon(
                    Icons.chevron_right,
                    color: theme.textMuted,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayCard extends StatelessWidget {
  final VoidCallback onTap;
  final AppThemeData theme;

  const _PlayCard({required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primary,
              theme.primary.withAlpha(200),
            ],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white, // Always white on primary-colored button
            size: 40,
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AppThemeData theme;
  final AppThemeMode themeMode;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.theme,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    // Only Dark 1 theme gets colored card backgrounds
    // All other themes (Light, Dark 2, Dark 3) use standard card background
    final bool useColoredCard = themeMode == AppThemeMode.dark1;
    
    final cardBgColor = useColoredCard ? color : theme.cardBackground;
    final iconBgColor = useColoredCard 
        ? Colors.white.withAlpha(40)  // Light overlay on colored card
        : color.withAlpha(38);         // Colored overlay on standard card
    final iconColor = useColoredCard ? Colors.white : color;
    final textColor = useColoredCard ? Colors.white : theme.textOnCard;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
