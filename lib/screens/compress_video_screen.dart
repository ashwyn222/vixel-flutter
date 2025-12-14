import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/job.dart';
import '../models/video_info.dart';
import '../services/ffmpeg_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../widgets/video_picker_card.dart';
import '../widgets/settings_card.dart';

class CompressVideoScreen extends StatefulWidget {
  const CompressVideoScreen({super.key});

  @override
  State<CompressVideoScreen> createState() => _CompressVideoScreenState();
}

class _CompressVideoScreenState extends State<CompressVideoScreen> {
  File? _selectedFile;
  VideoInfo? _videoInfo;

  // Settings
  String _resolution = '-1:-1';
  String _videoBitrate = '1000k';
  String _audioBitrate = '128k';
  String _preset = 'fast';
  final String _outputFormat = 'mp4';
  bool _removeAudio = false;

  final List<Map<String, String>> _resolutionOptions = [
    {'value': '-1:-1', 'label': 'Original'},
    {'value': '1920:-1', 'label': '1080p (1920×auto)'},
    {'value': '1280:-1', 'label': '720p (1280×auto)'},
    {'value': '854:-1', 'label': '480p (854×auto)'},
    {'value': '640:-1', 'label': '360p (640×auto)'},
  ];

  final List<Map<String, String>> _videoBitrateOptions = [
    {'value': '', 'label': 'Auto'},
    {'value': '5000k', 'label': '5000 kbps (High)'},
    {'value': '2500k', 'label': '2500 kbps (Medium-High)'},
    {'value': '1000k', 'label': '1000 kbps (Medium)'},
    {'value': '500k', 'label': '500 kbps (Low)'},
    {'value': '250k', 'label': '250 kbps (Very Low)'},
  ];

  final List<Map<String, String>> _audioBitrateOptions = [
    {'value': '', 'label': 'Auto'},
    {'value': '320k', 'label': '320 kbps (High)'},
    {'value': '192k', 'label': '192 kbps (Medium-High)'},
    {'value': '128k', 'label': '128 kbps (Medium)'},
    {'value': '96k', 'label': '96 kbps (Low)'},
    {'value': '64k', 'label': '64 kbps (Very Low)'},
  ];

  final List<Map<String, String>> _presetOptions = [
    {'value': 'ultrafast', 'label': 'Ultra Fast (Largest)'},
    {'value': 'veryfast', 'label': 'Very Fast'},
    {'value': 'fast', 'label': 'Fast'},
    {'value': 'medium', 'label': 'Medium (Balanced)'},
    {'value': 'slow', 'label': 'Slow (Smaller)'},
    {'value': 'veryslow', 'label': 'Very Slow (Smallest)'},
  ];

  int? _getResolutionWidth(String resolution) {
    if (resolution == '-1:-1') return null;
    final parts = resolution.split(':');
    if (parts.isNotEmpty) {
      final width = int.tryParse(parts[0]);
      if (width != null && width > 0) return width;
    }
    return null;
  }

  int? _getBitrateValue(String bitrate) {
    if (bitrate.isEmpty) return null;
    final numStr = bitrate.replaceAll('k', '');
    return int.tryParse(numStr);
  }

  bool _isResolutionDisabled(String optionValue) {
    if (_videoInfo == null) return false;
    if (optionValue == '-1:-1') return false;
    
    final optionWidth = _getResolutionWidth(optionValue);
    final sourceWidth = _videoInfo!.width;
    
    if (optionWidth == null || sourceWidth == null) return false;
    return optionWidth > sourceWidth;
  }

  bool _isVideoBitrateDisabled(String optionValue) {
    if (_videoInfo == null) return false;
    if (optionValue.isEmpty) return false;
    if (optionValue == '250k') return false;
    
    final optionBitrate = _getBitrateValue(optionValue);
    final sourceBitrate = _videoInfo!.videoBitrate;
    
    if (optionBitrate == null || sourceBitrate == null) return false;
    return optionBitrate > sourceBitrate;
  }

  bool _isAudioBitrateDisabled(String optionValue) {
    if (_videoInfo == null) return false;
    if (optionValue.isEmpty) return false;
    if (optionValue == '64k') return false;
    
    final optionBitrate = _getBitrateValue(optionValue);
    final sourceBitrate = _videoInfo!.audioBitrate;
    
    if (optionBitrate == null || sourceBitrate == null) return false;
    return optionBitrate > sourceBitrate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final t = theme.currentThemeData;
    final l10n = context.watch<AppLocalizations>();
    final hasVideo = _selectedFile != null;
    
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        title: Text(l10n.tr('compress_video'), style: TextStyle(color: t.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: hasVideo
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VideoPickerCard(
                    onVideoPicked: (file, info) {
                      setState(() {
                        _selectedFile = file;
                        _videoInfo = info;
                        if (_isResolutionDisabled(_resolution)) {
                          _resolution = '-1:-1';
                        }
                        if (_isVideoBitrateDisabled(_videoBitrate)) {
                          _videoBitrate = '';
                        }
                        if (_isAudioBitrateDisabled(_audioBitrate)) {
                          _audioBitrate = '';
                        }
                      });
                    },
                    selectedFile: _selectedFile,
                    videoInfo: _videoInfo,
                  ),
                  SizedBox(height: 24),

                  Text(
                    l10n.tr('compression_settings'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),

                  DropdownSettingCard<String>(
                    title: l10n.tr('resolution'),
                    subtitle: l10n.tr('output_resolution'),
                    value: _resolution,
                    items: _resolutionOptions.map((opt) {
                      final isDisabled = _isResolutionDisabled(opt['value']!);
                      return DropdownMenuItem(
                        value: opt['value'],
                        enabled: !isDisabled,
                        child: Text(
                          opt['value'] == '-1:-1' ? l10n.tr('original') : opt['label']!,
                          style: TextStyle(
                            color: isDisabled ? t.textMuted : t.textPrimary,
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
                    title: l10n.tr('video_bitrate'),
                    subtitle: l10n.tr('bitrate_hint'),
                    value: _videoBitrate,
                    items: _videoBitrateOptions.map((opt) {
                      final isDisabled = _isVideoBitrateDisabled(opt['value']!);
                      return DropdownMenuItem(
                        value: opt['value'],
                        enabled: !isDisabled,
                        child: Text(
                          opt['value']!.isEmpty ? l10n.tr('auto') : opt['label']!,
                          style: TextStyle(
                            color: isDisabled ? t.textMuted : t.textPrimary,
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
                    title: l10n.tr('compression_speed'),
                    subtitle: l10n.tr('speed_hint'),
                    value: _preset,
                    items: _presetOptions.map((opt) {
                      return DropdownMenuItem(
                        value: opt['value'],
                        child: Text(opt['label']!, style: TextStyle(color: t.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _preset = value);
                    },
                  ),

                  if (_videoInfo?.hasAudio == true && !_removeAudio)
                    DropdownSettingCard<String>(
                      title: l10n.tr('audio_bitrate'),
                      subtitle: l10n.tr('audio_quality'),
                      value: _audioBitrate,
                      items: _audioBitrateOptions.map((opt) {
                        final isDisabled = _isAudioBitrateDisabled(opt['value']!);
                        return DropdownMenuItem(
                          value: opt['value'],
                          enabled: !isDisabled,
                          child: Text(
                            opt['value']!.isEmpty ? l10n.tr('auto') : opt['label']!,
                            style: TextStyle(
                              color: isDisabled ? t.textMuted : t.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null && !_isAudioBitrateDisabled(value)) {
                          setState(() => _audioBitrate = value);
                        }
                      },
                    ),

                  if (_videoInfo?.hasAudio == true)
                    SwitchSettingCard(
                      title: l10n.tr('remove_audio'),
                      subtitle: l10n.tr('strip_audio'),
                      value: _removeAudio,
                      onChanged: (value) => setState(() => _removeAudio = value),
                    ),

                  SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _compressVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primary,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(l10n.tr('compress_video')),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            )
          : Center(
              child: VideoPickerCard(
                onVideoPicked: (file, info) {
                  setState(() {
                    _selectedFile = file;
                    _videoInfo = info;
                  });
                },
                selectedFile: _selectedFile,
                videoInfo: _videoInfo,
              ),
            ),
    );
  }

  Future<void> _compressVideo() async {
    if (_selectedFile == null) return;

    final theme = context.read<AppTheme>().currentThemeData;
    final l10n = context.read<AppLocalizations>();
    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('compressed', _outputFormat);
    final inputPath = _selectedFile!.path;
    final inputSize = _videoInfo?.fileSize;
    final duration = _videoInfo?.duration;

    final job = jobService.createJob(
      type: JobType.compress,
      filename: _selectedFile!.path.split('/').last,
      outputPath: outputPath,
      inputSize: inputSize,
      settings: {
        'resolution': _resolution,
        'videoBitrate': _videoBitrate,
        'audioBitrate': _audioBitrate,
        'preset': _preset,
        'removeAudio': _removeAudio,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tr('compression_started')),
        backgroundColor: theme.primary,
      ),
    );
    Navigator.pop(context);

    _runCompressionInBackground(
      jobService: jobService,
      jobId: job.id,
      inputPath: inputPath,
      outputPath: outputPath,
      inputSize: inputSize,
      duration: duration,
    );
  }

  Future<void> _runCompressionInBackground({
    required JobService jobService,
    required String jobId,
    required String inputPath,
    required String outputPath,
    int? inputSize,
    double? duration,
  }) async {
    try {
      final result = await FFmpegService.compressVideo(
        inputPath: inputPath,
        outputPath: outputPath,
        resolution: _resolution,
        videoBitrate: _videoBitrate,
        audioBitrate: _audioBitrate,
        preset: _preset,
        removeAudio: _removeAudio,
        duration: duration,
        onProgress: (progress, stats) {
          jobService.updateJobProgress(jobId, progress);
        },
      );

      if (result.success) {
        final outputSize = await StorageService.getFileSize(outputPath);
        double? savings;
        if (inputSize != null && inputSize > 0) {
          savings = ((inputSize - outputSize) / inputSize) * 100;
        }

        jobService.markJobCompleted(
          jobId,
          outputSize: outputSize,
          savingsPercent: savings,
        );
      } else {
        jobService.markJobFailed(jobId, result.error ?? 'Compression failed');
      }
    } catch (e) {
      jobService.markJobFailed(jobId, e.toString());
    }
  }
}
