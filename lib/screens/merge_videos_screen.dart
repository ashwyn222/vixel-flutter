import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../models/video_info.dart';
import '../services/ffmpeg_service.dart';
import '../services/ffprobe_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_service.dart';
import '../widgets/settings_card.dart';

class MergeVideosScreen extends StatefulWidget {
  const MergeVideosScreen({super.key});

  @override
  State<MergeVideosScreen> createState() => _MergeVideosScreenState();
}

class _MergeVideosScreenState extends State<MergeVideosScreen> {
  final List<_VideoItem> _videos = [];
  bool _isAnalyzing = false;

  // Settings
  String _resolution = '-1:-1';
  String _videoBitrate = '1000k';
  final String _audioBitrate = '128k';
  String _preset = 'fast';

  final List<Map<String, String>> _resolutionOptions = [
    {'value': '-1:-1', 'label': 'Original (same resolution only)'},
    {'value': '1920x1080', 'label': '1080p (1920×1080)'},
    {'value': '1280x720', 'label': '720p (1280×720)'},
    {'value': '854x480', 'label': '480p (854×480)'},
    {'value': '640x360', 'label': '360p (640×360)'},
  ];

  final List<Map<String, String>> _videoBitrateOptions = [
    {'value': '5000k', 'label': '5000 kbps (High)'},
    {'value': '2500k', 'label': '2500 kbps (Medium-High)'},
    {'value': '1000k', 'label': '1000 kbps (Medium)'},
    {'value': '500k', 'label': '500 kbps (Low)'},
    {'value': '250k', 'label': '250 kbps (Very Low)'},
  ];

  final List<Map<String, String>> _presetOptions = [
    {'value': 'ultrafast', 'label': 'Ultra Fast'},
    {'value': 'fast', 'label': 'Fast'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'slow', 'label': 'Slow'},
  ];

  double get _totalDuration {
    return _videos.fold(0, (sum, v) => sum + (v.info?.duration ?? 0));
  }

  int get _totalSize {
    return _videos.fold(0, (sum, v) => sum + (v.info?.fileSize ?? 0));
  }

  // Get the minimum width across all videos
  int? get _minVideoWidth {
    if (_videos.isEmpty) return null;
    int? minWidth;
    for (final video in _videos) {
      if (video.info?.width != null) {
        if (minWidth == null || video.info!.width! < minWidth) {
          minWidth = video.info!.width;
        }
      }
    }
    return minWidth;
  }

  // Check if all videos have the same resolution
  bool get _allSameResolution {
    if (_videos.length < 2) return true;
    final firstRes = _videos.first.info?.resolution;
    if (firstRes == null) return false;
    return _videos.every((v) => v.info?.resolution == firstRes);
  }

  // Get the minimum video bitrate across all videos
  int? get _minVideoBitrate {
    if (_videos.isEmpty) return null;
    int? minBitrate;
    for (final video in _videos) {
      if (video.info?.videoBitrate != null) {
        if (minBitrate == null || video.info!.videoBitrate! < minBitrate) {
          minBitrate = video.info!.videoBitrate;
        }
      }
    }
    return minBitrate;
  }

  // Get resolution width from string like "1920x1080" -> 1920
  int? _getResolutionWidth(String resolution) {
    if (resolution == '-1:-1') return null; // Original
    final parts = resolution.split('x');
    if (parts.isNotEmpty) {
      return int.tryParse(parts[0]);
    }
    return null;
  }

  // Get numeric bitrate from string like "1000k" -> 1000
  int? _getBitrateValue(String bitrate) {
    final numStr = bitrate.replaceAll('k', '');
    return int.tryParse(numStr);
  }

  // Check if resolution option should be disabled
  bool _isResolutionDisabled(String optionValue) {
    if (_videos.isEmpty) return false;
    
    // Disable "Original" when videos have different resolutions
    if (optionValue == '-1:-1') {
      return !_allSameResolution;
    }
    
    final optionWidth = _getResolutionWidth(optionValue);
    final minWidth = _minVideoWidth;
    
    if (optionWidth == null || minWidth == null) return false;
    return optionWidth > minWidth;
  }

  // Check if video bitrate option should be disabled
  bool _isVideoBitrateDisabled(String optionValue) {
    if (_videos.isEmpty) return false;
    
    // Always allow the lowest option
    if (optionValue == '250k') return false;
    
    final optionBitrate = _getBitrateValue(optionValue);
    final minBitrate = _minVideoBitrate;
    
    if (optionBitrate == null || minBitrate == null) return false;
    return optionBitrate > minBitrate;
  }

  @override
  Widget build(BuildContext context) {
    final hasVideos = _videos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Merge Videos'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: hasVideos
          ? Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add more videos button (compact)
                        GestureDetector(
                          onTap: _isAnalyzing ? null : _pickVideos,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.surfaceVariant,
                                width: 1,
                              ),
                            ),
                            child: _isAnalyzing
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Analyzing...',
                                        style: TextStyle(color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add, color: AppTheme.mergeColor, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Add More Videos',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.mergeColor,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Videos (${_videos.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _videos.clear();
                                  // Reset selections
                                  _resolution = '-1:-1';
                                  _videoBitrate = '1000k';
                                });
                              },
                              child: Text('Clear All'),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        // Summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryItem(
                                label: 'Total Duration',
                                value: _formatDuration(_totalDuration),
                              ),
                              _SummaryItem(
                                label: 'Total Size',
                                value: StorageService.formatFileSize(_totalSize),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),

                        // Reorderable list
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _videos.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _videos.removeAt(oldIndex);
                              _videos.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final video = _videos[index];
                            return _VideoListItem(
                              key: ValueKey(video.file.path),
                              video: video,
                              index: index,
                              onRemove: () {
                                setState(() => _videos.removeAt(index));
                                // Reset selections if they're now invalid
                                if (_isResolutionDisabled(_resolution)) {
                                  // Find the first enabled resolution option
                                  for (final opt in _resolutionOptions) {
                                    if (!_isResolutionDisabled(opt['value']!)) {
                                      setState(() => _resolution = opt['value']!);
                                      break;
                                    }
                                  }
                                }
                                if (_isVideoBitrateDisabled(_videoBitrate)) {
                                  setState(() => _videoBitrate = '250k');
                                }
                              },
                            );
                          },
                        ),

                        SizedBox(height: 24),

                        // Settings
                        Text(
                          'Output Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16),

                        DropdownSettingCard<String>(
                          title: 'Resolution',
                          value: _resolution,
                          items: _resolutionOptions.map((opt) {
                            final isDisabled = _isResolutionDisabled(opt['value']!);
                            return DropdownMenuItem(
                              value: opt['value'],
                              enabled: !isDisabled,
                              child: Text(
                                opt['label']!,
                                style: TextStyle(
                                  color: isDisabled ? AppTheme.textMuted : null,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && !_isResolutionDisabled(value)) {
                              setState(() => _resolution = value);
                            }
                          },
                        ),

                        DropdownSettingCard<String>(
                          title: 'Video Bitrate',
                          value: _videoBitrate,
                          items: _videoBitrateOptions.map((opt) {
                            final isDisabled = _isVideoBitrateDisabled(opt['value']!);
                            return DropdownMenuItem(
                              value: opt['value'],
                              enabled: !isDisabled,
                              child: Text(
                                opt['label']!,
                                style: TextStyle(
                                  color: isDisabled ? AppTheme.textMuted : null,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && !_isVideoBitrateDisabled(value)) {
                              setState(() => _videoBitrate = value);
                            }
                          },
                        ),

                        DropdownSettingCard<String>(
                          title: 'Speed',
                          value: _preset,
                          items: _presetOptions.map((opt) {
                            return DropdownMenuItem(
                              value: opt['value'],
                              child: Text(opt['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _preset = value);
                          },
                        ),

                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Merge button
                if (_videos.length >= 2)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(
                        top: BorderSide(color: AppTheme.surfaceVariant),
                      ),
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _mergeVideos,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Merge Videos'),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: GestureDetector(
                onTap: _isAnalyzing ? null : _pickVideos,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAnalyzing) ...[
                      const CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 16),
                      Text(
                        'Analyzing videos...',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ] else ...[
                      Icon(
                        Icons.layers_outlined,
                        color: AppTheme.textMuted.withAlpha(100),
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Select Videos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select multiple videos to merge',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60);
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _pickVideos() async {
    try {
      final pickerService = context.read<FilePickerService>();
      final files = await pickerService.pickVideos(context);

      if (files.isNotEmpty) {
        setState(() => _isAnalyzing = true);

        for (final file in files) {
          // Copy to accessible path for FFmpeg on Android
          final accessiblePath = await StorageService.copyToAccessiblePath(
            file.path,
            'merge_video',
          );
          final videoFile = File(accessiblePath);
          final info = await FFprobeService.analyzeVideo(videoFile.path);
          setState(() {
            _videos.add(_VideoItem(file: videoFile, info: info));
          });
        }

        // Reset selections if they're now invalid
        if (_isResolutionDisabled(_resolution)) {
          // Find the first enabled resolution option
          for (final opt in _resolutionOptions) {
            if (!_isResolutionDisabled(opt['value']!)) {
              _resolution = opt['value']!;
              break;
            }
          }
        }
        if (_isVideoBitrateDisabled(_videoBitrate)) {
          _videoBitrate = '250k';
        }

        setState(() => _isAnalyzing = false);
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking videos: $e')),
        );
      }
    }
  }

  Future<void> _mergeVideos() async {
    if (_videos.length < 2) return;

    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('merged', 'mp4');
    final inputPaths = _videos.map((v) => v.file.path).toList();
    final totalDuration = _totalDuration;
    final totalSize = _totalSize;

    final job = jobService.createJob(
      type: JobType.merge,
      filename: '${_videos.length} videos',
      outputPath: outputPath,
      inputSize: totalSize,
      settings: {
        'videoCount': _videos.length,
        'resolution': _resolution,
        'videoBitrate': _videoBitrate,
        'preset': _preset,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    // Show snackbar and navigate back immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Merge started! Check Records for progress.'),
        backgroundColor: AppTheme.primary,
      ),
    );
    Navigator.pop(context);

    // Run merge in background
    _runMergeInBackground(
      jobService: jobService,
      jobId: job.id,
      inputPaths: inputPaths,
      outputPath: outputPath,
      totalDuration: totalDuration,
    );
  }

  Future<void> _runMergeInBackground({
    required JobService jobService,
    required String jobId,
    required List<String> inputPaths,
    required String outputPath,
    required double totalDuration,
  }) async {
    try {
      final result = await FFmpegService.mergeVideos(
        inputPaths: inputPaths,
        outputPath: outputPath,
        resolution: _resolution,
        videoBitrate: _videoBitrate,
        audioBitrate: _audioBitrate,
        preset: _preset,
        totalDuration: totalDuration,
        onProgress: (progress, stats) {
          jobService.updateJobProgress(jobId, progress);
        },
      );

      if (result.success) {
        final outputSize = await StorageService.getFileSize(outputPath);
        jobService.markJobCompleted(jobId, outputSize: outputSize);
      } else {
        jobService.markJobFailed(jobId, result.error ?? 'Merge failed');
      }
    } catch (e) {
      jobService.markJobFailed(jobId, e.toString());
    }
  }
}

class _VideoItem {
  final File file;
  final VideoInfo? info;

  _VideoItem({required this.file, this.info});
}

class _VideoListItem extends StatelessWidget {
  final _VideoItem video;
  final int index;
  final VoidCallback onRemove;

  const _VideoListItem({
    super.key,
    required this.video,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = video.file.path.split('/').last;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (video.info != null)
                  Text(
                    '${video.info!.resolution} · ${video.info!.durationFormatted} · ${video.info!.fileSizeFormatted}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 18),
            color: AppTheme.textMuted,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
