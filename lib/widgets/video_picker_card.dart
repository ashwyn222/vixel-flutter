import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../theme/app_theme.dart';
import '../models/video_info.dart';
import '../services/ffprobe_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_service.dart';

class VideoPickerCard extends StatefulWidget {
  final Function(File file, VideoInfo? info) onVideoPicked;
  final File? selectedFile;
  final VideoInfo? videoInfo;
  final bool isLoading;
  final String? label;
  final bool allowMultiple;
  final bool showThumbnail;

  const VideoPickerCard({
    super.key,
    required this.onVideoPicked,
    this.selectedFile,
    this.videoInfo,
    this.isLoading = false,
    this.label,
    this.allowMultiple = false,
    this.showThumbnail = true,
  });

  @override
  State<VideoPickerCard> createState() => _VideoPickerCardState();
}

class _VideoPickerCardState extends State<VideoPickerCard> {
  bool _analyzing = false;
  Uint8List? _thumbnail;

  Future<void> _pickVideo() async {
    try {
      final pickerService = context.read<FilePickerService>();
      final file = await pickerService.pickVideo(context);

      if (file != null) {
        setState(() => _analyzing = true);
        
        // Copy to accessible path for FFmpeg on Android
        final accessiblePath = await StorageService.copyToAccessiblePath(
          file.path,
          'input_video',
        );
        final accessibleFile = File(accessiblePath);
        
        final videoInfo = await FFprobeService.analyzeVideo(accessibleFile.path);
        
        // Generate thumbnail
        if (widget.showThumbnail) {
          try {
            final thumbnail = await VideoThumbnail.thumbnailData(
              video: accessibleFile.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 300,
              quality: 75,
            );
            setState(() => _thumbnail = thumbnail);
          } catch (_) {
            // Thumbnail generation failed, continue without it
          }
        }
        
        setState(() => _analyzing = false);
        
        widget.onVideoPicked(accessibleFile, videoInfo);
      }
    } catch (e) {
      setState(() => _analyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.selectedFile != null;
    final isLoading = widget.isLoading || _analyzing;

    if (!hasVideo && !isLoading) {
      return _buildPlaceholder();
    }

    return Material(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : _pickVideo,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasVideo ? AppTheme.primary.withAlpha(128) : AppTheme.surfaceVariant,
              width: hasVideo ? 2 : 1,
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 12),
                        Text(
                          'Analyzing video...',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildVideoInfo(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              color: AppTheme.textMuted.withAlpha(100),
              size: 64,
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: _pickVideo,
              child: Text(
                widget.label ?? 'Select Video',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    final info = widget.videoInfo;
    final fileName = widget.selectedFile!.path.split('/').last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail and basic info row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (widget.showThumbnail)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _thumbnail != null
                    ? Image.memory(
                        _thumbnail!,
                        width: 100,
                        height: 70,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 100,
                        height: 70,
                        color: AppTheme.surfaceVariant,
                        child: Icon(
                          Icons.video_file,
                          color: AppTheme.textMuted,
                          size: 32,
                        ),
                      ),
              ),
            if (widget.showThumbnail) SizedBox(width: 12),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (info != null) ...[
                    Text(
                      '${info.resolution} • ${info.durationFormatted}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      info.fileSizeFormatted,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Change button
            IconButton(
              onPressed: _pickVideo,
              icon: Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
              tooltip: 'Change video',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        // Additional info
        if (info != null) ...[
          SizedBox(height: 12),
          Divider(color: AppTheme.surfaceVariant),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.aspect_ratio, info.resolution),
              _buildInfoChip(Icons.timer_outlined, info.durationFormatted),
              if (info.videoBitrate != null)
                _buildInfoChip(Icons.videocam, '${info.videoBitrate} kbps'),
              _buildInfoChip(
                info.hasAudio ? Icons.volume_up : Icons.volume_off,
                info.hasAudio 
                    ? (info.audioBitrate != null ? '${info.audioBitrate} kbps' : 'Audio')
                    : 'No Audio',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(128),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

