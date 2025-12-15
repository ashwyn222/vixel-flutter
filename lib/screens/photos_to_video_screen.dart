import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/ffmpeg_service.dart';
import '../services/ffprobe_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_service.dart';

class PhotosToVideoScreen extends StatefulWidget {
  const PhotosToVideoScreen({super.key});

  @override
  State<PhotosToVideoScreen> createState() => _PhotosToVideoScreenState();
}

class _PhotosToVideoScreenState extends State<PhotosToVideoScreen> {
  final List<_PhotoItem> _photos = [];
  File? _audioFile;
  String? _audioFilePath;
  String? _audioFileName;
  double? _audioDuration;
  bool _isAnalyzingAudio = false;

  final List<String> _transitionOptions = [
    'fade',
    'wipeleft',
    'wiperight',
    'wipeup',
    'wipedown',
    'slideleft',
    'slideright',
    'slideup',
    'slidedown',
    'circlecrop',
    'rectcrop',
    'distance',
    'fadeblack',
    'fadewhite',
    'radial',
    'smoothleft',
    'smoothright',
    'smoothup',
    'smoothdown',
    'dissolve',
  ];

  double get _totalDuration {
    return _photos.fold(0, (sum, p) => sum + p.duration);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos to Video'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add photos button
                      GestureDetector(
                        onTap: _pickPhotos,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.surfaceVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.photosToVideoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.add_photo_alternate,
                                  color: AppTheme.photosToVideoColor,
                                  size: 28,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Add Photos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _photos.isEmpty
                                    ? 'Select images for your slideshow'
                                    : 'Tap to add more photos',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_photos.isNotEmpty) ...[
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Photos (${_photos.length}/20)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Total: ${_totalDuration.round()}s',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => setState(() => _photos.clear()),
                                  child: Text('Clear'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Photo list
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _photos.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _photos.removeAt(oldIndex);
                              _photos.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            return _PhotoListItem(
                              key: ValueKey(photo.file.path),
                              photo: photo,
                              index: index,
                              isLast: index == _photos.length - 1,
                              transitionOptions: _transitionOptions,
                              onDurationChanged: (duration) {
                                setState(() => photo.duration = duration);
                              },
                              onTransitionChanged: (transition) {
                                setState(() => photo.transition = transition);
                              },
                              onRemove: () {
                                setState(() => _photos.removeAt(index));
                              },
                            );
                          },
                        ),

                        SizedBox(height: 24),

                        // Background music
                        Text(
                          'Background Music (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12),

                        GestureDetector(
                          onTap: _isAnalyzingAudio ? null : _pickAudio,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _isAnalyzingAudio
                                ? Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : _audioFile != null
                                    ? Row(
                                        children: [
                                          Icon(
                                            Icons.audiotrack,
                                            color: AppTheme.success,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _audioFileName ?? 'Audio',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (_audioDuration != null)
                                                  Text(
                                                    '${(_audioDuration! / 60).floor()}:${(_audioDuration! % 60).round().toString().padLeft(2, '0')}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.textMuted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _audioFile = null;
                                _audioFilePath = null;
                                _audioFileName = null;
                                _audioDuration = null;
                              });
                            },
                            icon: Icon(Icons.close, size: 18),
                            color: AppTheme.textMuted,
                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            color: AppTheme.textMuted,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Add background music',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),

                        SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),

              // Create button (requires at least 2 photos)
              if (_photos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(
                      top: BorderSide(color: AppTheme.surfaceVariant),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_photos.length < 2)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Add at least 2 photos to create a video',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _photos.length >= 2 ? _createVideo : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.photosToVideoColor,
                              disabledBackgroundColor: AppTheme.photosToVideoColor.withAlpha(100),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text('Create Video'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 20 photos allowed')),
      );
      return;
    }

    try {
      final pickerService = context.read<FilePickerService>();
      final remaining = 20 - _photos.length;
      final files = await pickerService.pickImages(context, maxCount: remaining);

      for (final file in files) {
        // Copy to accessible path for FFmpeg on Android
        final accessiblePath = await StorageService.copyToAccessiblePath(
          file.path,
          'photo',
        );
        setState(() {
          _photos.add(_PhotoItem(
            file: File(accessiblePath),
            duration: 3.0,
            transition: 'fade',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking photos: $e')),
        );
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      final pickerService = context.read<FilePickerService>();
      final file = await pickerService.pickAudio(context);

      if (file != null) {
        setState(() => _isAnalyzingAudio = true);

        // Copy to accessible path for FFmpeg on Android
        final accessiblePath = await StorageService.copyToAccessiblePath(
          file.path,
          'audio',
        );
        final accessibleFile = File(accessiblePath);
        final duration = await FFprobeService.getAudioDuration(accessiblePath);

        setState(() {
          _audioFile = accessibleFile;
          _audioFilePath = accessiblePath;
          _audioFileName = file.path.split('/').last;
          _audioDuration = duration;
          _isAnalyzingAudio = false;
        });
      }
    } catch (e) {
      setState(() => _isAnalyzingAudio = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking audio: $e')),
        );
      }
    }
  }

  Future<void> _createVideo() async {
    if (_photos.isEmpty) return;

    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('slideshow', 'mp4');

    // Capture all values BEFORE navigating away
    final imagePaths = _photos.map((p) => p.file.path).toList();
    final durations = _photos.map((p) => p.duration).toList();
    final transitions = _photos.map((p) => p.transition).toList();
    final audioPath = _audioFilePath;
    final photoCount = _photos.length;
    final totalDuration = _totalDuration;

    final job = jobService.createJob(
      type: JobType.photosToVideo,
      filename: '$photoCount photos',
      outputPath: outputPath,
      settings: {
        'photoCount': photoCount,
        'totalDuration': totalDuration,
        'hasAudio': audioPath != null,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    // Show snackbar and navigate back immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Creating video. Check Records for progress.'),
          backgroundColor: AppTheme.photosToVideoColor,
        ),
      );
      Navigator.pop(context);
    }

    // Run in background with captured values
    _runCreationInBackground(
      jobService: jobService,
      jobId: job.id,
      imagePaths: imagePaths,
      durations: durations,
      transitions: transitions,
      audioPath: audioPath,
      outputPath: outputPath,
    );
  }

  Future<void> _runCreationInBackground({
    required JobService jobService,
    required String jobId,
    required List<String> imagePaths,
    required List<double> durations,
    required List<String> transitions,
    required String? audioPath,
    required String outputPath,
  }) async {
    try {
      final result = await FFmpegService.photosToVideo(
        imagePaths: imagePaths,
        durations: durations,
        transitions: transitions,
        audioPath: audioPath,
        outputPath: outputPath,
        onProgress: (progress, stats) {
          jobService.updateJobProgress(jobId, progress);
        },
      );

      if (result.success) {
        final outputSize = await StorageService.getFileSize(outputPath);
        jobService.markJobCompleted(jobId, outputSize: outputSize);
      } else {
        jobService.markJobFailed(jobId, result.error ?? 'Creation failed');
      }
    } catch (e) {
      jobService.markJobFailed(jobId, e.toString());
    }
  }
}

class _PhotoItem {
  final File file;
  double duration;
  String transition;

  _PhotoItem({
    required this.file,
    required this.duration,
    required this.transition,
  });
}

class _PhotoListItem extends StatelessWidget {
  final _PhotoItem photo;
  final int index;
  final bool isLast;
  final List<String> transitionOptions;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<String> onTransitionChanged;
  final VoidCallback onRemove;

  const _PhotoListItem({
    super.key,
    required this.photo,
    required this.index,
    required this.isLast,
    required this.transitionOptions,
    required this.onDurationChanged,
    required this.onTransitionChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    photo.file,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 12),
                // Photo info and duration controls
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Photo ${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          // Close and drag buttons moved here
                          GestureDetector(
                            onTap: onRemove,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                            ),
                          ),
                          SizedBox(width: 4),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.drag_handle, size: 20, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Duration with +/- buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Duration:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          SizedBox(width: 8),
                          // Decrease button
                          _DurationButton(
                            icon: Icons.remove,
                            onPressed: photo.duration > 1
                                ? () => onDurationChanged(photo.duration - 1)
                                : null,
                          ),
                          // Duration value
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${photo.duration.round()}s',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.photosToVideoColor,
                              ),
                            ),
                          ),
                          // Increase button
                          _DurationButton(
                            icon: Icons.add,
                            onPressed: photo.duration < 8
                                ? () => onDurationChanged(photo.duration + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Transition selector (not for last photo)
          if (!isLast) ...[
            Divider(height: 1, color: AppTheme.surfaceVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Transition:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButton<String>(
                        value: photo.transition,
                        items: transitionOptions.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) onTransitionChanged(value);
                        },
                        isExpanded: true,
                        underline: SizedBox(),
                        dropdownColor: AppTheme.surfaceVariant,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DurationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _DurationButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.photosToVideoColor.withAlpha(38)
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled
                ? AppTheme.photosToVideoColor
                : AppTheme.textMuted.withAlpha(100),
          ),
        ),
      ),
    );
  }
}

