import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../theme/app_theme.dart';
import '../models/video_info.dart';
import '../services/ffprobe_service.dart';
import '../services/file_picker_service.dart';

class PlayVideoScreen extends StatefulWidget {
  const PlayVideoScreen({super.key});

  @override
  State<PlayVideoScreen> createState() => _PlayVideoScreenState();
}

class _PlayVideoScreenState extends State<PlayVideoScreen> {
  File? _selectedFile;
  VideoInfo? _videoInfo;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = false;

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Play Video'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedFile != null)
            IconButton(
              onPressed: _pickVideo,
              icon: Icon(Icons.folder_open),
              tooltip: 'Open another video',
            ),
        ],
      ),
      body: _selectedFile == null
          ? _buildPicker()
          : _isLoading
              ? Center(child: CircularProgressIndicator())
              : _buildPlayer(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GestureDetector(
          onTap: _pickVideo,
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.surfaceVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: AppTheme.primary,
                    size: 40,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Select a Video',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to browse and play video files',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return Column(
      children: [
        // Video player
        Expanded(
          child: _chewieController != null
              ? Chewie(controller: _chewieController!)
              : Center(child: CircularProgressIndicator()),
        ),

        // Video info
        if (_videoInfo != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                top: BorderSide(color: AppTheme.surfaceVariant),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFile!.path.split('/').last,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.aspect_ratio,
                        label: _videoInfo!.resolution,
                      ),
                      SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.timer,
                        label: _videoInfo!.durationFormatted,
                      ),
                      SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.storage,
                        label: _videoInfo!.fileSizeFormatted,
                      ),
                      if (_videoInfo!.hasAudio) ...[
                        SizedBox(width: 8),
                        const _InfoChip(
                          icon: Icons.volume_up,
                          label: 'Audio',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickVideo() async {
    try {
      final pickerService = context.read<FilePickerService>();
      final file = await pickerService.pickVideo(context);

      if (file != null) {
        setState(() => _isLoading = true);

        // Dispose previous controllers
        _chewieController?.dispose();
        _videoController?.dispose();

        final info = await FFprobeService.analyzeVideo(file.path);

        // Initialize video player
        final videoController = VideoPlayerController.file(file);
        await videoController.initialize();

        final chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: true,
          looping: false,
          aspectRatio: videoController.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.primary,
            handleColor: AppTheme.primary,
            backgroundColor: AppTheme.surfaceVariant,
            bufferedColor: AppTheme.primary.withOpacity(0.3),
          ),
        );

        setState(() {
          _selectedFile = file;
          _videoInfo = info;
          _videoController = videoController;
          _chewieController = chewieController;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

