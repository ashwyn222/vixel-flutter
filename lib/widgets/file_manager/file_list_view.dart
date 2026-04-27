import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import '../../models/file_item.dart';
import 'file_manager.dart';

/// Displays files and folders in a directory as a list
class FileListView extends StatefulWidget {
  final Directory directory;
  final FileMediaType mediaType;
  final bool allowMultiple;
  final Set<FileItem> selectedFiles;
  final Function(FileItem) onFileSelected;
  final Function(Directory) onFolderSelected;
  final FileSortOption sortOption;

  const FileListView({
    super.key,
    required this.directory,
    required this.mediaType,
    required this.allowMultiple,
    required this.selectedFiles,
    required this.onFileSelected,
    required this.onFolderSelected,
    required this.sortOption,
  });

  @override
  State<FileListView> createState() => FileListViewState();
}

class FileListViewState extends State<FileListView> {
  List<Directory> _folders = [];
  List<FileItem> _files = [];
  bool _isLoading = true;
  String? _error;

  // Thumbnail cache
  final Map<String, Uint8List?> _thumbnailCache = {};
  
  // Duration cache for video files
  final Map<String, Duration?> _durationCache = {};

  @override
  void initState() {
    super.initState();
    _loadDirectoryContents();
  }

  @override
  void didUpdateWidget(FileListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory.path != widget.directory.path ||
        oldWidget.sortOption != widget.sortOption) {
      _loadDirectoryContents();
    }
  }

  Future<void> _loadDirectoryContents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<Directory> folders = [];
      final List<FileItem> files = [];

      await for (final entity in widget.directory.list(followLinks: false)) {
        if (entity is Directory) {
          // Check if folder name starts with a dot (hidden)
          final folderName = entity.path.split('/').last;
          if (!folderName.startsWith('.')) {
            folders.add(entity);
          }
        } else if (entity is File) {
          final fileName = entity.path.split('/').last;
          
          // Skip hidden files
          if (fileName.startsWith('.')) continue;

          // Check if file matches media type
          if (widget.mediaType.matchesFile(fileName)) {
            final stat = await entity.stat();
            final mediaType = _getMediaType(fileName);
            
            files.add(FileItem(
              file: entity,
              name: fileName,
              sizeInBytes: stat.size,
              modifiedDate: stat.modified,
              mediaType: mediaType,
            ));
          }
        }
      }

      // Sort folders alphabetically
      folders.sort((a, b) => a.path.split('/').last.toLowerCase()
          .compareTo(b.path.split('/').last.toLowerCase()));

      // Sort files based on sort option
      _sortFiles(files);

      setState(() {
        _folders = folders;
        _files = files;
        _isLoading = false;
      });

      // Load thumbnails for video files
      _loadThumbnails();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading directory: $e';
      });
    }
  }

  FileMediaType _getMediaType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (FileMediaType.video.extensions.any((ext) => lowerName.endsWith(ext))) {
      return FileMediaType.video;
    } else if (FileMediaType.audio.extensions.any((ext) => lowerName.endsWith(ext))) {
      return FileMediaType.audio;
    } else if (FileMediaType.image.extensions.any((ext) => lowerName.endsWith(ext))) {
      return FileMediaType.image;
    }
    return FileMediaType.all;
  }

  void _sortFiles(List<FileItem> files) {
    switch (widget.sortOption) {
      case FileSortOption.dateNewest:
        files.sort((a, b) => (b.modifiedDate ?? DateTime(1970))
            .compareTo(a.modifiedDate ?? DateTime(1970)));
        break;
      case FileSortOption.dateOldest:
        files.sort((a, b) => (a.modifiedDate ?? DateTime(1970))
            .compareTo(b.modifiedDate ?? DateTime(1970)));
        break;
      case FileSortOption.nameAZ:
        files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FileSortOption.nameZA:
        files.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case FileSortOption.sizeLargest:
        files.sort((a, b) => b.sizeInBytes.compareTo(a.sizeInBytes));
        break;
      case FileSortOption.sizeSmallest:
        files.sort((a, b) => a.sizeInBytes.compareTo(b.sizeInBytes));
        break;
    }
  }

  Future<void> _loadThumbnails() async {
    for (final file in _files) {
      if (!mounted) return;
      
      // Skip if already cached
      if (_thumbnailCache.containsKey(file.path)) continue;

      Uint8List? thumbnail;
      Duration? duration;
      
      if (file.mediaType == FileMediaType.video) {
        try {
          thumbnail = await VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 120,
            quality: 50,
          );
        } catch (_) {}
        
        // Get video duration
        if (!_durationCache.containsKey(file.path)) {
          try {
            final controller = VideoPlayerController.file(File(file.path));
            await controller.initialize();
            duration = controller.value.duration;
            await controller.dispose();
          } catch (_) {}
        }
      } else if (file.mediaType == FileMediaType.image) {
        try {
          final imageFile = File(file.path);
          final bytes = await imageFile.readAsBytes();
          thumbnail = bytes;
        } catch (_) {}
      } else if (file.mediaType == FileMediaType.audio) {
        // Get audio duration
        if (!_durationCache.containsKey(file.path)) {
          try {
            final controller = VideoPlayerController.file(File(file.path));
            await controller.initialize();
            duration = controller.value.duration;
            await controller.dispose();
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _thumbnailCache[file.path] = thumbnail;
          if (duration != null) {
            _durationCache[file.path] = duration;
          }
        });
      }
    }
  }

  void refresh() {
    _loadDirectoryContents();
  }
  
  /// Get all loaded files for select all functionality
  List<FileItem> get allFiles => _files;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00D9FF),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDirectoryContents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_folders.isEmpty && _files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.mediaType.label.toLowerCase()} files in this folder',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => refresh(),
      color: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF2D2D2D),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _folders.length + _files.length,
        itemBuilder: (context, index) {
          // Show folders first
          if (index < _folders.length) {
            return _FolderListItem(
              directory: _folders[index],
              onTap: () => widget.onFolderSelected(_folders[index]),
            );
          }

          // Then files
          final fileIndex = index - _folders.length;
          final file = _files[fileIndex];
          final isSelected = widget.selectedFiles.contains(file);
          final thumbnail = _thumbnailCache[file.path];
          final duration = _durationCache[file.path];

          return _FileListItem(
            file: file,
            thumbnail: thumbnail,
            duration: duration,
            isSelected: isSelected,
            onTap: () => widget.onFileSelected(file),
          );
        },
      ),
    );
  }
}

class _FolderListItem extends StatelessWidget {
  final Directory directory;
  final VoidCallback onTap;

  const _FolderListItem({
    required this.directory,
    required this.onTap,
  });

  String get _name => directory.path.split('/').last;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2D2D2D),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF404040),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.folder_rounded,
            color: Color(0xFFFFCA28),
            size: 28,
          ),
        ),
        title: Text(
          _name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text(
          'Folder',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white54,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final FileItem file;
  final Uint8List? thumbnail;
  final Duration? duration;
  final bool isSelected;
  final VoidCallback onTap;

  const _FileListItem({
    required this.file,
    this.thumbnail,
    this.duration,
    required this.isSelected,
    required this.onTap,
  });
  
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  IconData get _icon {
    switch (file.mediaType) {
      case FileMediaType.video:
        return Icons.videocam_rounded;
      case FileMediaType.audio:
        return Icons.music_note_rounded;
      case FileMediaType.image:
        return Icons.image_rounded;
      case FileMediaType.all:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _iconColor {
    switch (file.mediaType) {
      case FileMediaType.video:
        return const Color(0xFF00D9FF);
      case FileMediaType.audio:
        return const Color(0xFFEE5396);
      case FileMediaType.image:
        return const Color(0xFF08BDBA);
      case FileMediaType.all:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected 
          ? const Color(0xFF00D9FF).withAlpha(38)
          : const Color(0xFF2D2D2D),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? const BorderSide(color: Color(0xFF00D9FF), width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumbnail != null
                  ? Image.memory(
                      thumbnail!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                    )
                  : Icon(
                      _icon,
                      color: _iconColor,
                      size: 28,
                    ),
            ),
            // Selection indicator
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D9FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          file.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            // Extension badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _iconColor.withAlpha(51),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                file.extension,
                style: TextStyle(
                  color: _iconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Duration for video/audio
            if (duration != null && (file.mediaType == FileMediaType.video || file.mediaType == FileMediaType.audio)) ...[
              const Icon(
                Icons.schedule_rounded,
                size: 12,
                color: Colors.white54,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  _formatDuration(duration!),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Size
            Flexible(
              child: Text(
                file.formattedSize,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (file.formattedDate.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '• ${file.formattedDate}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
