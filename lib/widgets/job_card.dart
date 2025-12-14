import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;

  const JobCard({
    super.key,
    required this.job,
    this.onDelete,
    this.onCancel,
  });

  Color get _statusColor {
    switch (job.status) {
      case JobStatus.pending:
        return AppTheme.warning;
      case JobStatus.processing:
        return AppTheme.info;
      case JobStatus.completed:
        return AppTheme.success;
      case JobStatus.failed:
        return AppTheme.error;
      case JobStatus.cancelled:
        return AppTheme.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case JobStatus.pending:
        return Icons.schedule;
      case JobStatus.processing:
        return Icons.sync;
      case JobStatus.completed:
        return Icons.check_circle;
      case JobStatus.failed:
        return Icons.error;
      case JobStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color get _typeColor {
    switch (job.type) {
      case JobType.compress:
        return AppTheme.compressColor;
      case JobType.cut:
        return AppTheme.cutColor;
      case JobType.merge:
        return AppTheme.mergeColor;
      case JobType.extractAudio:
        return AppTheme.extractAudioColor;
      case JobType.audioOnVideo:
        return AppTheme.audioOnVideoColor;
      case JobType.photosToVideo:
        return AppTheme.photosToVideoColor;
      case JobType.addWatermark:
        return AppTheme.watermarkColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: job.status == JobStatus.processing
              ? AppTheme.info.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        job.typeDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _typeColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, size: 14, color: _statusColor),
                        SizedBox(width: 4),
                        Text(
                          job.statusDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                
                // Filename
                Text(
                  job.filename,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                
                // Info row
                Row(
                  children: [
                    if (job.inputSize != null) ...[
                      Text(
                        StorageService.formatFileSize(job.inputSize!),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (job.outputSize != null) ...[
                        Text(
                          ' → ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          StorageService.formatFileSize(job.outputSize!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ],
                    if (job.savingsPercent != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: job.savingsPercent! >= 0 
                              ? AppTheme.success.withAlpha(25) 
                              : AppTheme.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          job.savingsPercent! >= 0
                              ? '${job.savingsPercent!.toStringAsFixed(1)}%'
                              : '+${job.savingsPercent!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: job.savingsPercent! >= 0 
                                ? AppTheme.success 
                                : AppTheme.warning,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTime(job.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                
                // Error message
                if (job.error != null && job.status == JobStatus.failed) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 14, color: AppTheme.error),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            job.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.error,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Progress bar for processing jobs
          if (job.status == JobStatus.processing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.progress / 100,
                  minHeight: 4,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(AppTheme.info),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${job.progress}% complete',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          
          // Action buttons for completed jobs
          if (job.status == JobStatus.completed && job.outputPath != null) ...[
            Divider(height: 1, color: AppTheme.surfaceVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Open
                  IconButton(
                    onPressed: () => _openFile(context),
                    icon: Icon(Icons.play_arrow, size: 22),
                    color: AppTheme.primary,
                    tooltip: 'Open',
                  ),
                  // Location
                  IconButton(
                    onPressed: () => _openFileLocation(context),
                    icon: Icon(Icons.folder_open, size: 22),
                    color: AppTheme.textSecondary,
                    tooltip: 'Open Location',
                  ),
                  // Share (disabled)
                  IconButton(
                    onPressed: null,
                    icon: Icon(Icons.share, size: 22),
                    color: AppTheme.textMuted,
                    disabledColor: AppTheme.textMuted.withAlpha(100),
                    tooltip: 'Share (coming soon)',
                  ),
                  // Remove
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 22),
                    color: AppTheme.textMuted,
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
          ],
          
          // Delete button for failed/cancelled jobs
          if (job.status == JobStatus.failed || job.status == JobStatus.cancelled) ...[
            Divider(height: 1, color: AppTheme.surfaceVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 22),
                    color: AppTheme.textMuted,
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  void _openFile(BuildContext context) async {
    if (job.outputPath != null) {
      try {
        await OpenFile.open(job.outputPath!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: $e')),
          );
        }
      }
    }
  }

  /// Get the subfolder name for Android intent based on job type
  String _getSubfolderForJobType() {
    switch (job.type) {
      case JobType.compress:
        return 'Compressed';
      case JobType.cut:
        return 'Cut';
      case JobType.merge:
        return 'Merged';
      case JobType.extractAudio:
        return 'ExtractedAudio';
      case JobType.audioOnVideo:
        return 'AudioOnVideo';
      case JobType.photosToVideo:
        return 'PhotosToVideo';
      case JobType.addWatermark:
        return 'Watermarked';
    }
  }

  void _openFileLocation(BuildContext context) async {
    if (job.outputPath != null) {
      try {
        final directory = p.dirname(job.outputPath!);
        
        if (Platform.isAndroid) {
          // On Android, open the specific subfolder for this job type
          final subfolder = _getSubfolderForJobType();
          final encodedPath = Uri.encodeComponent('Download/Vixel/$subfolder');
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'content://com.android.externalstorage.documents/document/primary%3A$encodedPath',
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
        } else if (Platform.isMacOS) {
          // On macOS, reveal in Finder with the file selected
          await Process.run('open', ['-R', job.outputPath!]);
        } else if (Platform.isWindows) {
          // On Windows, open Explorer with file selected
          await Process.run('explorer', ['/select,', job.outputPath!]);
        } else if (Platform.isLinux) {
          // On Linux, open the directory
          await Process.run('xdg-open', [directory]);
        } else {
          // Fallback: try to open the directory
          await OpenFile.open(directory);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file location: $e')),
          );
        }
      }
    }
  }
}
