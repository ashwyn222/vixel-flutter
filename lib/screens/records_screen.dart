import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/job.dart';
import '../services/job_service.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/job_card.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text(l10n.tr('records'), style: TextStyle(color: t.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: t.textSecondary),
            color: t.cardBackground,
            onSelected: (value) => _handleMenuAction(value, t, l10n),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20, color: t.textSecondary),
                    SizedBox(width: 12),
                    Text(l10n.tr('clear_completed'), style: TextStyle(color: t.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_failed',
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 20, color: t.textSecondary),
                    SizedBox(width: 12),
                    Text(l10n.tr('clear_failed'), style: TextStyle(color: t.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20, color: t.error),
                    SizedBox(width: 12),
                    Text(l10n.tr('clear_all'), style: TextStyle(color: t.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: t.primary,
          labelColor: t.primary,
          unselectedLabelColor: t.textMuted,
          tabs: [
            Tab(text: l10n.tr('all')),
            Tab(text: l10n.tr('active')),
            Tab(text: l10n.tr('completed')),
          ],
        ),
      ),
      body: Consumer<JobService>(
        builder: (context, jobService, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildJobList(jobService.jobs, t, l10n),
              _buildJobList(jobService.activeJobs, t, l10n),
              _buildJobList(jobService.completedJobs, t, l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJobList(List<Job> jobs, AppThemeData t, AppLocalizations l10n) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: t.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.inbox_outlined,
                color: t.textMuted,
                size: 36,
              ),
            ),
            SizedBox(height: 16),
            Text(
              l10n.tr('no_jobs_yet'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              l10n.tr('processing_history'),
              style: TextStyle(
                fontSize: 14,
                color: t.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return JobCard(
          job: job,
          onDelete: () => _deleteJob(job.id, t, l10n),
          onCancel: job.status == JobStatus.processing || job.status == JobStatus.pending
              ? () => _cancelJob(job.id, l10n)
              : null,
        );
      },
    );
  }

  void _handleMenuAction(String action, AppThemeData t, AppLocalizations l10n) {
    final jobService = context.read<JobService>();

    switch (action) {
      case 'clear_completed':
        _showConfirmDialog(
          title: l10n.tr('clear_completed_jobs'),
          message: l10n.tr('clear_completed_message'),
          onConfirm: () => jobService.clearCompletedJobs(),
          theme: t,
          l10n: l10n,
        );
        break;
      case 'clear_failed':
        _showConfirmDialog(
          title: l10n.tr('clear_failed_jobs'),
          message: l10n.tr('clear_failed_message'),
          onConfirm: () => jobService.clearFailedJobs(),
          theme: t,
          l10n: l10n,
        );
        break;
      case 'clear_all':
        _showConfirmDialog(
          title: l10n.tr('clear_all_jobs'),
          message: l10n.tr('clear_all_jobs_message'),
          onConfirm: () => jobService.clearAllJobs(),
          isDestructive: true,
          theme: t,
          l10n: l10n,
        );
        break;
    }
  }

  void _deleteJob(String jobId, AppThemeData t, AppLocalizations l10n) {
    _showConfirmDialog(
      title: l10n.tr('delete_job'),
      message: l10n.tr('delete_job_message'),
      onConfirm: () => context.read<JobService>().deleteJob(jobId),
      theme: t,
      l10n: l10n,
    );
  }

  void _cancelJob(String jobId, AppLocalizations l10n) {
    FFmpegService.cancelAll();
    context.read<JobService>().cancelJob(jobId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.tr('job_cancelled'))),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    required AppThemeData theme,
    required AppLocalizations l10n,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(title, style: TextStyle(color: theme.textPrimary)),
        content: Text(message, style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.tr('cancel'), style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? theme.error : theme.primary,
            ),
            child: Text(isDestructive ? l10n.tr('delete') : l10n.tr('confirm')),
          ),
        ],
      ),
    );
  }
}
