import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../models/video_info.dart';
import '../services/ffmpeg_service.dart';
import '../services/ffprobe_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../widgets/video_picker_card.dart';
import '../widgets/settings_card.dart';

class AudioOnVideoScreen extends StatefulWidget {
  const AudioOnVideoScreen({super.key});

  @override
  State<AudioOnVideoScreen> createState() => _AudioOnVideoScreenState();
}

class _AudioOnVideoScreenState extends State<AudioOnVideoScreen> {
  File? _selectedVideo;
  VideoInfo? _videoInfo;
  File? _selectedAudio;
  String? _audioFilePath; // Store the accessible path
  String? _audioFileName;
  double? _audioDuration;
  bool _isAnalyzingAudio = false;

  double _originalVolume = 0.5;
  double _newAudioVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    // Show centered pickers when neither video nor audio is selected
    final bool showCenteredPickers = _selectedVideo == null && _selectedAudio == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio on Video'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: showCenteredPickers
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video picker (centered style - no card)
                    VideoPickerCard(
                      onVideoPicked: (file, info) {
                        setState(() {
                          _selectedVideo = file;
                          _videoInfo = info;
                        });
                      },
                      selectedFile: _selectedVideo,
                      videoInfo: _videoInfo,
                      label: 'Select Video',
                    ),
                    SizedBox(height: 24),
                    // Audio picker (centered style - no card background)
                    _buildAudioPlaceholderCentered(),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Video picker
                  VideoPickerCard(
                    onVideoPicked: (file, info) {
                      setState(() {
                        _selectedVideo = file;
                        _videoInfo = info;
                      });
                    },
                    selectedFile: _selectedVideo,
                    videoInfo: _videoInfo,
                    label: 'Select Video',
                  ),
                  SizedBox(height: 16),

                  // Audio picker - centered
                  Center(child: _buildAudioPickerCard()),

                  if (_selectedVideo != null && _selectedAudio != null) ...[
                    SizedBox(height: 24),
                    Text(
                      'Volume Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Original video audio volume
                    if (_videoInfo?.hasAudio == true)
                      SliderSettingCard(
                        title: 'Original Audio Volume',
                        subtitle: 'Volume of the existing video audio',
                        value: _originalVolume,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        valueLabel: '${(_originalVolume * 100).round()}%',
                        onChanged: (value) => setState(() => _originalVolume = value),
                      ),

                    // New audio volume
                    SliderSettingCard(
                      title: 'New Audio Volume',
                      subtitle: 'Volume of the audio you\'re adding',
                      value: _newAudioVolume,
                      min: 0,
                      max: 2,
                      divisions: 40,
                      valueLabel: '${(_newAudioVolume * 100).round()}%',
                      onChanged: (value) => setState(() => _newAudioVolume = value),
                    ),

                    // Info about audio length
                    if (_audioDuration != null && _videoInfo?.duration != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              label: 'Video Duration',
                              value: _formatDuration(_videoInfo!.duration!),
                            ),
                            SizedBox(height: 8),
                            _InfoRow(
                              label: 'Audio Duration',
                              value: _formatDuration(_audioDuration!),
                            ),
                            if (_audioDuration! < _videoInfo!.duration!) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.loop, size: 14, color: AppTheme.info),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Audio will be looped to match video duration',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.info,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addAudioToVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.audioOnVideoColor,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Add Audio to Video'),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ],
              ),
            ),
    );
  }

  // Audio picker with card background (used when video is selected)
  Widget _buildAudioPickerCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isAnalyzingAudio ? null : _pickAudio,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedAudio != null
                  ? AppTheme.audioOnVideoColor.withAlpha(128)
                  : AppTheme.surfaceVariant,
              width: _selectedAudio != null ? 2 : 1,
            ),
          ),
          child: _isAnalyzingAudio
              ? Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'Analyzing audio...',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : _selectedAudio != null
                  ? _buildAudioInfo()
                  : _buildAudioPlaceholder(),
        ),
      ),
    );
  }

  // Centered audio placeholder without card background (used in initial centered view)
  Widget _buildAudioPlaceholderCentered() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isAnalyzingAudio ? null : _pickAudio,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.audiotrack,
                color: AppTheme.textMuted.withAlpha(100),
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'Select Audio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.audioOnVideoColor,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.audioOnVideoColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'MP3, AAC, WAV, M4A',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlaceholder() {
    return Column(
      children: [
        Icon(
          Icons.audiotrack,
          color: AppTheme.textMuted.withAlpha(100),
          size: 48,
        ),
        SizedBox(height: 12),
        Text(
          'Select Audio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.audioOnVideoColor,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.audioOnVideoColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'MP3, AAC, WAV, M4A',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioInfo() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.success.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.audiotrack,
            color: AppTheme.success,
            size: 24,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _audioFileName ?? 'Audio file',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_audioDuration != null)
                Text(
                  'Duration: ${_formatDuration(_audioDuration!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: _pickAudio,
          icon: Icon(Icons.refresh, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60);
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        setState(() => _isAnalyzingAudio = true);

        // Copy to accessible path for FFmpeg on Android
        final accessiblePath = await StorageService.copyToAccessiblePath(
          result.files.first.path!,
          'audio',
        );
        final file = File(accessiblePath);
        final duration = await FFprobeService.getAudioDuration(accessiblePath);

        setState(() {
          _selectedAudio = file;
          _audioFilePath = accessiblePath; // Store the accessible path
          _audioFileName = result.files.first.name;
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

  Future<void> _addAudioToVideo() async {
    if (_selectedVideo == null || _selectedAudio == null || _audioFilePath == null) return;

    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('audio_mixed', 'mp4');

    // Capture all values BEFORE navigating away (widget will be disposed)
    final videoPath = _selectedVideo!.path;
    final audioPath = _audioFilePath!;
    final originalVolume = _originalVolume;
    final newAudioVolume = _newAudioVolume;
    final videoDuration = _videoInfo?.duration ?? 0.0;
    final audioDuration = _audioDuration ?? 0.0;
    final videoHasAudio = _videoInfo?.hasAudio ?? false;

    final job = jobService.createJob(
      type: JobType.audioOnVideo,
      filename: videoPath.split('/').last,
      outputPath: outputPath,
      inputSize: _videoInfo?.fileSize,
      settings: {
        'audioFile': _audioFileName,
        'originalVolume': originalVolume,
        'newAudioVolume': newAudioVolume,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    // Show snackbar and navigate back immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adding audio to video. Check Records for progress.'),
          backgroundColor: AppTheme.audioOnVideoColor,
        ),
      );
      Navigator.pop(context);
    }

    // Run in background with captured values
    _runProcessingInBackground(
      jobService: jobService,
      jobId: job.id,
      videoPath: videoPath,
      audioPath: audioPath,
      outputPath: outputPath,
      originalVolume: originalVolume,
      newAudioVolume: newAudioVolume,
      videoDuration: videoDuration,
      audioDuration: audioDuration,
      videoHasAudio: videoHasAudio,
    );
  }

  Future<void> _runProcessingInBackground({
    required JobService jobService,
    required String jobId,
    required String videoPath,
    required String audioPath,
    required String outputPath,
    required double originalVolume,
    required double newAudioVolume,
    required double videoDuration,
    required double audioDuration,
    required bool videoHasAudio,
  }) async {
    try {
      final result = await FFmpegService.audioOnVideo(
        videoPath: videoPath,
        audioPath: audioPath,
        outputPath: outputPath,
        originalVolume: originalVolume,
        newAudioVolume: newAudioVolume,
        videoDuration: videoDuration,
        audioDuration: audioDuration,
        videoHasAudio: videoHasAudio,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

