import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../models/video_info.dart';
import '../services/ffmpeg_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../widgets/video_picker_card.dart';
import '../widgets/settings_card.dart';

class AddWatermarkScreen extends StatefulWidget {
  const AddWatermarkScreen({super.key});

  @override
  State<AddWatermarkScreen> createState() => _AddWatermarkScreenState();
}

class _AddWatermarkScreenState extends State<AddWatermarkScreen> {
  File? _selectedVideo;
  VideoInfo? _videoInfo;
  File? _watermarkImage;
  String? _watermarkImagePath;

  // Settings
  String _watermarkType = 'text'; // 'text' or 'image'
  String _watermarkText = 'Vixel';
  String _position = 'bottom-right';
  double _opacity = 0.8;
  double _scale = 0.2;
  String _durationType = 'full'; // 'full' or 'custom'
  RangeValues _timeRange = const RangeValues(0, 100);

  final List<Map<String, dynamic>> _positionOptions = [
    {'value': 'top-left', 'label': 'Top Left', 'icon': Icons.north_west},
    {'value': 'top-right', 'label': 'Top Right', 'icon': Icons.north_east},
    {'value': 'center', 'label': 'Center', 'icon': Icons.center_focus_strong},
    {'value': 'bottom-left', 'label': 'Bottom Left', 'icon': Icons.south_west},
    {'value': 'bottom-right', 'label': 'Bottom Right', 'icon': Icons.south_east},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Watermark'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _selectedVideo == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: VideoPickerCard(
                  onVideoPicked: (file, info) {
                    setState(() {
                      _selectedVideo = file;
                      _videoInfo = info;
                      if (info?.duration != null) {
                        _timeRange = RangeValues(0, info!.duration!);
                      }
                    });
                  },
                  selectedFile: _selectedVideo,
                  videoInfo: _videoInfo,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VideoPickerCard(
                          onVideoPicked: (file, info) {
                            setState(() {
                              _selectedVideo = file;
                              _videoInfo = info;
                              if (info?.duration != null) {
                                _timeRange = RangeValues(0, info!.duration!);
                              }
                            });
                          },
                          selectedFile: _selectedVideo,
                          videoInfo: _videoInfo,
                        ),

                        SizedBox(height: 24),
                        Text(
                          'Watermark Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12),

                        // Type selector
                        Row(
                          children: [
                            Expanded(
                              child: _TypeButton(
                                icon: Icons.text_fields,
                                label: 'Text',
                                isSelected: _watermarkType == 'text',
                                onTap: () => setState(() => _watermarkType = 'text'),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _TypeButton(
                                icon: Icons.image,
                                label: 'Image',
                                isSelected: _watermarkType == 'image',
                                onTap: () => setState(() => _watermarkType = 'image'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),

                        // Watermark content
                        if (_watermarkType == 'text') ...[
                          SettingsCard(
                            title: 'Watermark Text',
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Enter watermark text',
                              ),
                              onChanged: (value) => setState(() => _watermarkText = value),
                              controller: TextEditingController(text: _watermarkText),
                            ),
                          ),
                        ] else ...[
                          // Image picker
                          GestureDetector(
                            onTap: _pickWatermarkImage,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _watermarkImage != null
                                      ? AppTheme.watermarkColor.withAlpha(128)
                                      : AppTheme.surfaceVariant,
                                ),
                              ),
                              child: _watermarkImage != null
                                  ? Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            _watermarkImage!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Watermark image selected',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _pickWatermarkImage,
                                          icon: Icon(Icons.refresh),
                                          color: AppTheme.textSecondary,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, color: AppTheme.textMuted),
                                        SizedBox(width: 8),
                                        Text(
                                          'Select watermark image',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Scale slider for image
                          SliderSettingCard(
                            title: 'Watermark Size',
                            subtitle: 'Size relative to video width',
                            value: _scale,
                            min: 0.05,
                            max: 0.5,
                            divisions: 45,
                            valueLabel: '${(_scale * 100).round()}%',
                            onChanged: (value) => setState(() => _scale = value),
                          ),
                        ],

                        // Position - full width
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Position',
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
                                children: _positionOptions.map((opt) {
                                  final isSelected = _position == opt['value'];
                                  return GestureDetector(
                                    onTap: () => setState(() => _position = opt['value']),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.watermarkColor.withAlpha(38)
                                            : AppTheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.watermarkColor
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            opt['icon'],
                                            size: 16,
                                            color: isSelected
                                                ? AppTheme.watermarkColor
                                                : AppTheme.textMuted,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            opt['label'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? AppTheme.watermarkColor
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Opacity
                        SliderSettingCard(
                          title: 'Opacity',
                          value: _opacity,
                          min: 0.1,
                          max: 1.0,
                          divisions: 18,
                          valueLabel: '${(_opacity * 100).round()}%',
                          onChanged: (value) => setState(() => _opacity = value),
                        ),

                        // Duration type
                        SettingsCard(
                          title: 'Duration',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _TypeButton(
                                      icon: Icons.all_inclusive,
                                      label: 'Full Video',
                                      isSelected: _durationType == 'full',
                                      onTap: () => setState(() => _durationType = 'full'),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _TypeButton(
                                      icon: Icons.timelapse,
                                      label: 'Custom Range',
                                      isSelected: _durationType == 'custom',
                                      onTap: () => setState(() => _durationType = 'custom'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_durationType == 'custom' && _videoInfo?.duration != null) ...[
                                SizedBox(height: 16),
                                // Single range slider instead of two separate sliders
                                RangeSlider(
                                  values: _timeRange,
                                  min: 0,
                                  max: _videoInfo!.duration!,
                                  divisions: (_videoInfo!.duration! > 1) ? _videoInfo!.duration!.round() : 1,
                                  labels: RangeLabels(
                                    _formatTime(_timeRange.start),
                                    _formatTime(_timeRange.end),
                                  ),
                                  activeColor: AppTheme.watermarkColor,
                                  inactiveColor: AppTheme.surfaceVariant,
                                  onChanged: (values) {
                                    setState(() => _timeRange = values);
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Start: ${_formatTime(_timeRange.start)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'End: ${_formatTime(_timeRange.end)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Bottom button
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
                        onPressed: _canProcess ? _addWatermark : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.watermarkColor,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Add Watermark'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool get _canProcess {
    if (_selectedVideo == null) return false;
    if (_watermarkType == 'text' && _watermarkText.isEmpty) return false;
    if (_watermarkType == 'image' && _watermarkImage == null) return false;
    return true;
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _pickWatermarkImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        // Copy to accessible path for FFmpeg on Android
        final accessiblePath = await StorageService.copyToAccessiblePath(
          result.files.first.path!,
          'watermark',
        );
        setState(() {
          _watermarkImage = File(accessiblePath);
          _watermarkImagePath = accessiblePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _addWatermark() async {
    if (!_canProcess) return;

    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('watermarked', 'mp4');

    // Capture all values BEFORE navigating away
    final videoPath = _selectedVideo!.path;
    final watermarkType = _watermarkType;
    final position = _position;
    final opacity = _opacity;
    final watermarkImagePath = _watermarkImagePath;
    final watermarkText = _watermarkText;
    final scale = _scale;
    final durationType = _durationType;
    final startTime = _timeRange.start;
    final endTime = _timeRange.end;
    final inputSize = _videoInfo?.fileSize;

    final job = jobService.createJob(
      type: JobType.addWatermark,
      filename: _selectedVideo!.path.split('/').last,
      outputPath: outputPath,
      inputSize: inputSize,
      settings: {
        'watermarkType': watermarkType,
        'position': position,
        'opacity': opacity,
        'text': watermarkType == 'text' ? watermarkText : null,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    // Show snackbar and navigate back immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adding watermark. Check Records for progress.'),
          backgroundColor: AppTheme.watermarkColor,
        ),
      );
      Navigator.pop(context);
    }

    // Run in background with captured values
    _runProcessingInBackground(
      jobService: jobService,
      jobId: job.id,
      videoPath: videoPath,
      outputPath: outputPath,
      watermarkType: watermarkType,
      position: position,
      opacity: opacity,
      watermarkImagePath: watermarkImagePath,
      watermarkText: watermarkText,
      scale: scale,
      durationType: durationType,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Future<void> _runProcessingInBackground({
    required JobService jobService,
    required String jobId,
    required String videoPath,
    required String outputPath,
    required String watermarkType,
    required String position,
    required double opacity,
    required String? watermarkImagePath,
    required String watermarkText,
    required double scale,
    required String durationType,
    required double startTime,
    required double endTime,
  }) async {
    try {
      final result = await FFmpegService.addWatermark(
        videoPath: videoPath,
        outputPath: outputPath,
        watermarkType: watermarkType,
        positionMode: 'preset',
        position: position,
        opacity: opacity,
        watermarkImagePath: watermarkImagePath,
        watermarkText: watermarkText,
        scale: scale,
        durationType: durationType,
        startTime: startTime,
        endTime: endTime,
        onProgress: (progress, stats) {
          jobService.updateJobProgress(jobId, progress);
        },
      );

      if (result.success) {
        final outputSize = await StorageService.getFileSize(outputPath);
        jobService.markJobCompleted(jobId, outputSize: outputSize);
      } else {
        jobService.markJobFailed(jobId, result.error ?? 'Processing failed');
      }
    } catch (e) {
      jobService.markJobFailed(jobId, e.toString());
    }
  }
}

class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.watermarkColor.withAlpha(38)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.watermarkColor : AppTheme.surfaceVariant,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppTheme.watermarkColor : AppTheme.textMuted,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.watermarkColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
