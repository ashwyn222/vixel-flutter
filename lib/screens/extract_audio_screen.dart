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

class ExtractAudioScreen extends StatefulWidget {
  const ExtractAudioScreen({super.key});

  @override
  State<ExtractAudioScreen> createState() => _ExtractAudioScreenState();
}

class _ExtractAudioScreenState extends State<ExtractAudioScreen> {
  File? _selectedFile;
  VideoInfo? _videoInfo;

  String _format = 'mp3';
  String _bitrate = '128k';

  final List<Map<String, String>> _formatOptions = [
    {'value': 'mp3', 'label': 'MP3'},
    {'value': 'aac', 'label': 'AAC'},
    {'value': 'wav', 'label': 'WAV'},
    {'value': 'm4a', 'label': 'M4A'},
  ];

  final List<Map<String, String>> _bitrateOptions = [
    {'value': '320k', 'label': '320 kbps (High Quality)'},
    {'value': '256k', 'label': '256 kbps'},
    {'value': '192k', 'label': '192 kbps'},
    {'value': '128k', 'label': '128 kbps (Standard)'},
    {'value': '96k', 'label': '96 kbps'},
    {'value': '64k', 'label': '64 kbps (Low)'},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLocalizations>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('extract_audio_title')),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _selectedFile == null
          ? Center(
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
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VideoPickerCard(
                    onVideoPicked: (file, info) {
                      setState(() {
                        _selectedFile = file;
                        _videoInfo = info;
                      });
                    },
                    selectedFile: _selectedFile,
                    videoInfo: _videoInfo,
                  ),

                  // Warning if no audio
                  if (_videoInfo?.hasAudio == false) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warning.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: AppTheme.warning),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This video does not contain an audio track.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_videoInfo?.hasAudio == true) ...[
                    SizedBox(height: 24),
                    Text(
                      l10n.tr('output_settings'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Format selector
                    SettingsCard(
                      title: l10n.tr('output_format'),
                      child: Row(
                        children: _formatOptions.map((opt) {
                          final isSelected = _format == opt['value'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _format = opt['value']!),
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: opt != _formatOptions.last ? 8 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.extractAudioColor.withAlpha(38)
                                      : AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.extractAudioColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  opt['label']!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppTheme.extractAudioColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Bitrate
                    DropdownSettingCard<String>(
                      title: l10n.tr('audio_quality'),
                      subtitle: l10n.tr('bitrate_hint'),
                      value: _bitrate,
                      items: _bitrateOptions.map((opt) {
                        return DropdownMenuItem(
                          value: opt['value'],
                          child: Text(opt['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _bitrate = value);
                      },
                    ),

                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _extractAudio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.extractAudioColor,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(l10n.tr('extract_audio')),
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

  Future<void> _extractAudio() async {
    if (_selectedFile == null || _videoInfo?.hasAudio != true) return;

    final l10n = context.read<AppLocalizations>();
    final jobService = context.read<JobService>();
    final outputPath = await StorageService.getOutputFilePath('extracted', _format);

    final job = jobService.createJob(
      type: JobType.extractAudio,
      filename: _selectedFile!.path.split('/').last,
      outputPath: outputPath,
      inputSize: _videoInfo?.fileSize,
      settings: {
        'format': _format,
        'bitrate': _bitrate,
      },
    );

    jobService.updateJobStatus(job.id, JobStatus.processing);

    // Show snackbar and navigate back immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('extraction_started')),
          backgroundColor: AppTheme.extractAudioColor,
        ),
      );
      Navigator.pop(context);
    }

    // Run extraction in background
    _runExtractionInBackground(
      jobService: jobService,
      jobId: job.id,
      inputPath: _selectedFile!.path,
      outputPath: outputPath,
    );
  }

  Future<void> _runExtractionInBackground({
    required JobService jobService,
    required String jobId,
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final result = await FFmpegService.extractAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        format: _format,
        bitrate: _bitrate,
        onProgress: (progress, stats) {
          jobService.updateJobProgress(jobId, progress);
        },
      );

      if (result.success) {
        final outputSize = await StorageService.getFileSize(outputPath);
        jobService.markJobCompleted(jobId, outputSize: outputSize);
      } else {
        jobService.markJobFailed(jobId, result.error ?? 'Extraction failed');
      }
    } catch (e) {
      jobService.markJobFailed(jobId, e.toString());
    }
  }
}
