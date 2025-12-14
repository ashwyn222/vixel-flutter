import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/job.dart';
import '../models/video_info.dart';
import '../services/ffmpeg_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../widgets/video_picker_card.dart';

class CutVideoScreen extends StatefulWidget {
  const CutVideoScreen({super.key});

  @override
  State<CutVideoScreen> createState() => _CutVideoScreenState();
}

class _CutVideoScreenState extends State<CutVideoScreen> {
  File? _selectedFile;
  VideoInfo? _videoInfo;

  double _startTime = 0;
  double _endTime = 0;

  // Video player for preview
  VideoPlayerController? _videoController;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  double _currentPosition = 0;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer(File file) async {
    _videoController?.dispose();
    
    _videoController = VideoPlayerController.file(file);
    
    try {
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoPositionChanged);
      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isPlayerInitialized = false;
      });
    }
  }

  void _onVideoPositionChanged() {
    if (_videoController != null && mounted) {
      final position = _videoController!.value.position.inMilliseconds / 1000.0;
      setState(() {
        _currentPosition = position;
        _isPlaying = _videoController!.value.isPlaying;
      });
      
      // Auto-pause at end time during playback
      if (_isPlaying && position >= _endTime) {
        _videoController!.pause();
        _seekTo(_endTime);
      }
    }
  }

  Future<void> _seekTo(double seconds) async {
    if (_videoController != null && _isPlayerInitialized) {
      await _videoController!.seekTo(Duration(milliseconds: (seconds * 1000).round()));
      setState(() {
        _currentPosition = seconds;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_videoController == null || !_isPlayerInitialized) return;
    
    if (_isPlaying) {
      await _videoController!.pause();
    } else {
      // If at or past end time, start from start time
      if (_currentPosition >= _endTime) {
        await _seekTo(_startTime);
      }
      await _videoController!.play();
    }
  }

  Future<void> _playPreview() async {
    if (_videoController == null || !_isPlayerInitialized) return;
    
    await _seekTo(_startTime);
    await _videoController!.play();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLocalizations>();
    final hasVideo = _selectedFile != null;
    final duration = _videoInfo?.duration ?? 60;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('cut_video')),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: hasVideo
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Preview Player
                  if (_isPlayerInitialized && _videoController != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Video display
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                          // Playback controls
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: AppTheme.cardBackground,
                            child: Column(
                              children: [
                                // Current position slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: _currentPosition.clamp(0, duration),
                                    min: 0,
                                    max: duration,
                                    activeColor: AppTheme.primary,
                                    inactiveColor: AppTheme.surfaceVariant,
                                    onChanged: (value) {
                                      _seekTo(value);
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(_currentPosition),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Jump to start
                                        IconButton(
                                          onPressed: () => _seekTo(_startTime),
                                          icon: Icon(Icons.skip_previous, size: 24),
                                          color: AppTheme.success,
                                          tooltip: 'Jump to Start',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        SizedBox(width: 16),
                                        // Play/Pause
                                        IconButton(
                                          onPressed: _togglePlayPause,
                                          icon: Icon(
                                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                            size: 40,
                                          ),
                                          color: AppTheme.primary,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        SizedBox(width: 16),
                                        // Jump to end
                                        IconButton(
                                          onPressed: () => _seekTo(_endTime),
                                          icon: Icon(Icons.skip_next, size: 24),
                                          color: AppTheme.error,
                                          tooltip: 'Jump to End',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Preview selected range button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _playPreview,
                        icon: Icon(Icons.play_arrow, size: 20),
                        label: Text(l10n.tr('preview_selected_range')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Video info card (compact)
                  VideoPickerCard(
                    onVideoPicked: (file, info) async {
                      setState(() {
                        _selectedFile = file;
                        _videoInfo = info;
                        _startTime = 0;
                        _endTime = info?.duration ?? 60;
                        _isPlayerInitialized = false;
                      });
                      await _initializeVideoPlayer(file);
                    },
                    selectedFile: _selectedFile,
                    videoInfo: _videoInfo,
                    showThumbnail: false,
                  ),
                  SizedBox(height: 24),

                  Text(
                    l10n.tr('cut_range'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Time range display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TimeDisplay(
                              label: 'Start',
                              seconds: _startTime,
                              color: AppTheme.success,
                              onTap: () => _seekTo(_startTime),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDuration(_endTime - _startTime),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            _TimeDisplay(
                              label: 'End',
                              seconds: _endTime,
                              color: AppTheme.error,
                              onTap: () => _seekTo(_endTime),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Range slider with markers
                        Stack(
                          children: [
                            RangeSlider(
                              values: RangeValues(_startTime, _endTime),
                              min: 0,
                              max: duration,
                              onChanged: (values) {
                                setState(() {
                                  _startTime = values.start;
                                  _endTime = values.end;
                                });
                              },
                              onChangeEnd: (values) {
                                // Seek to the changed position for preview
                                if ((_startTime - values.start).abs() > 0.1) {
                                  _seekTo(values.start);
                                } else if ((_endTime - values.end).abs() > 0.1) {
                                  _seekTo(values.end);
                                }
                              },
                              activeColor: AppTheme.primary,
                              inactiveColor: AppTheme.surfaceVariant,
                            ),
                          ],
                        ),

                        SizedBox(height: 8),
                        
                        // Set from current position buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  if (_currentPosition < _endTime) {
                                    setState(() => _startTime = _currentPosition);
                                  }
                                },
                                icon: Icon(Icons.first_page, size: 18),
                                label: Text(l10n.tr('set_start')),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.success,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: AppTheme.surfaceVariant,
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  if (_currentPosition > _startTime) {
                                    setState(() => _endTime = _currentPosition);
                                  }
                                },
                                icon: Icon(Icons.last_page, size: 18),
                                label: Text(l10n.tr('set_end')),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Quick trim buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('quick_trim'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickTrimButton(
                              label: 'First 10s',
                              onTap: () {
                                setState(() {
                                  _startTime = 0;
                                  _endTime = (10.0).clamp(0, duration);
                                });
                                _seekTo(0);
                              },
                            ),
                            _QuickTrimButton(
                              label: 'First 30s',
                              onTap: () {
                                setState(() {
                                  _startTime = 0;
                                  _endTime = (30.0).clamp(0, duration);
                                });
                                _seekTo(0);
                              },
                            ),
                            _QuickTrimButton(
                              label: 'Last 10s',
                              onTap: () {
                                final start = (duration - 10).clamp(0.0, duration);
                                setState(() {
                                  _startTime = start;
                                  _endTime = duration;
                                });
                                _seekTo(start);
                              },
                            ),
                            _QuickTrimButton(
                              label: 'Last 30s',
                              onTap: () {
                                final start = (duration - 30).clamp(0.0, duration);
                                setState(() {
                                  _startTime = start;
                                  _endTime = duration;
                                });
                                _seekTo(start);
                              },
                            ),
                            _QuickTrimButton(
                              label: 'First Half',
                              onTap: () {
                                setState(() {
                                  _startTime = 0;
                                  _endTime = duration / 2;
                                });
                                _seekTo(0);
                              },
                            ),
                            _QuickTrimButton(
                              label: 'Second Half',
                              onTap: () {
                                final start = duration / 2;
                                setState(() {
                                  _startTime = start;
                                  _endTime = duration;
                                });
                                _seekTo(start);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startTime >= _endTime ? null : _cutVideo,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(l10n.tr('cut_video')),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            )
          : Center(
              child: VideoPickerCard(
                onVideoPicked: (file, info) async {
                  setState(() {
                    _selectedFile = file;
                    _videoInfo = info;
                    _startTime = 0;
                    _endTime = info?.duration ?? 60;
                  });
                  await _initializeVideoPlayer(file);
                },
                selectedFile: _selectedFile,
                videoInfo: _videoInfo,
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

  Future<void> _cutVideo() async {
    if (_selectedFile == null || _startTime >= _endTime) return;

    // Pause video if playing
    _videoController?.pause();

    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('cut', 'mp4');

    final job = jobService.createJob(
      type: JobType.cut,
      filename: _selectedFile!.path.split('/').last,
      outputPath: outputPath,
      inputSize: _videoInfo?.fileSize,
      settings: {
        'startTime': _startTime,
        'endTime': _endTime,
        'duration': _endTime - _startTime,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    // Show snackbar and navigate back immediately
    final l10n = context.read<AppLocalizations>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tr('cut_started')),
        backgroundColor: AppTheme.primary,
      ),
    );
    Navigator.pop(context);

    // Run cut in background
    _runCutInBackground(
      jobService: jobService,
      jobId: job.id,
      inputPath: _selectedFile!.path,
      outputPath: outputPath,
    );
  }

  Future<void> _runCutInBackground({
    required JobService jobService,
    required String jobId,
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final result = await FFmpegService.cutVideo(
        inputPath: inputPath,
        outputPath: outputPath,
        startTime: _startTime,
        endTime: _endTime,
        onProgress: (progress, stats) {
          jobService.updateJobProgress(jobId, progress);
        },
      );

      if (result.success) {
        final outputSize = await StorageService.getFileSize(outputPath);
        jobService.markJobCompleted(jobId, outputSize: outputSize);
      } else {
        jobService.markJobFailed(jobId, result.error ?? 'Cut failed');
      }
    } catch (e) {
      jobService.markJobFailed(jobId, e.toString());
    }
  }
}

class _TimeDisplay extends StatelessWidget {
  final String label;
  final double seconds;
  final Color color;
  final VoidCallback? onTap;

  const _TimeDisplay({
    required this.label,
    required this.seconds,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60);
    final ms = (d.inMilliseconds.remainder(1000) / 10).round();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (onTap != null) ...[
            SizedBox(height: 2),
            Text(
              'Tap to preview',
              style: TextStyle(
                fontSize: 10,
                color: color.withAlpha(150),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickTrimButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickTrimButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
