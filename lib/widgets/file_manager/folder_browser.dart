import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/file_item.dart';

/// Displays root storage directories and quick access folders
class FolderBrowser extends StatefulWidget {
  final List<Directory> rootDirectories;
  final FileMediaType mediaType;
  final Function(Directory) onFolderSelected;

  const FolderBrowser({
    super.key,
    required this.rootDirectories,
    required this.mediaType,
    required this.onFolderSelected,
  });

  @override
  State<FolderBrowser> createState() => FolderBrowserState();
}

class FolderBrowserState extends State<FolderBrowser> {
  List<_QuickAccessFolder> _quickAccessFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuickAccessFolders();
  }

  Future<void> _loadQuickAccessFolders() async {
    setState(() => _isLoading = true);

    final List<_QuickAccessFolder> folders = [];

    // Define quick access paths based on media type
    final quickPaths = <String, IconData>{
      '/storage/emulated/0/DCIM': Icons.camera_alt_rounded,
      '/storage/emulated/0/Movies': Icons.movie_rounded,
      '/storage/emulated/0/Download': Icons.download_rounded,
      '/storage/emulated/0/Pictures': Icons.image_rounded,
      '/storage/emulated/0/Music': Icons.music_note_rounded,
      '/storage/emulated/0/Documents': Icons.description_rounded,
      '/storage/emulated/0/WhatsApp/Media': Icons.chat_rounded,
    };

    for (final entry in quickPaths.entries) {
      final dir = Directory(entry.key);
      if (await dir.exists()) {
        final count = await _countMediaFiles(dir);
        if (count > 0) {
          folders.add(_QuickAccessFolder(
            directory: dir,
            name: entry.key.split('/').last,
            icon: entry.value,
            fileCount: count,
          ));
        }
      }
    }

    // Sort by file count (most files first)
    folders.sort((a, b) => b.fileCount.compareTo(a.fileCount));

    setState(() {
      _quickAccessFolders = folders;
      _isLoading = false;
    });
  }

  Future<int> _countMediaFiles(Directory directory) async {
    int count = 0;
    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File && widget.mediaType.matchesFile(entity.path)) {
          count++;
          // Limit for performance
          if (count >= 9999) break;
        }
      }
    } catch (_) {}
    return count;
  }

  void refresh() {
    _loadQuickAccessFolders();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00D9FF),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Storage locations section
        if (widget.rootDirectories.isNotEmpty) ...[
          const _SectionHeader(title: 'Storage'),
          const SizedBox(height: 8),
          ...widget.rootDirectories.map((dir) => _StorageItem(
            directory: dir,
            onTap: () => widget.onFolderSelected(dir),
          )),
          const SizedBox(height: 24),
        ],

        // Quick access section
        if (_quickAccessFolders.isNotEmpty) ...[
          const _SectionHeader(title: 'Quick Access'),
          const SizedBox(height: 8),
          ..._quickAccessFolders.map((folder) => _QuickAccessItem(
            folder: folder,
            onTap: () => widget.onFolderSelected(folder.directory),
          )),
        ],

        // Empty state
        if (widget.rootDirectories.isEmpty && _quickAccessFolders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_off_rounded,
                    size: 64,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.mediaType.label.toLowerCase()} files found',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StorageItem extends StatelessWidget {
  final Directory directory;
  final VoidCallback onTap;

  const _StorageItem({
    required this.directory,
    required this.onTap,
  });

  String get _name {
    final path = directory.path;
    if (path == '/storage/emulated/0') {
      return 'Internal Storage';
    }
    return path.split('/').last;
  }

  IconData get _icon {
    final path = directory.path;
    if (path == '/storage/emulated/0') {
      return Icons.phone_android_rounded;
    }
    return Icons.sd_card_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2D2D2D),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF00D9FF).withAlpha(38),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _icon,
            color: const Color(0xFF00D9FF),
            size: 24,
          ),
        ),
        title: Text(
          _name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          directory.path,
          style: TextStyle(
            color: Colors.white.withAlpha(128),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _QuickAccessFolder {
  final Directory directory;
  final String name;
  final IconData icon;
  final int fileCount;

  _QuickAccessFolder({
    required this.directory,
    required this.name,
    required this.icon,
    required this.fileCount,
  });
}

class _QuickAccessItem extends StatelessWidget {
  final _QuickAccessFolder folder;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.folder,
    required this.onTap,
  });

  String get _countLabel {
    if (folder.fileCount >= 9999) {
      return '9999+ files';
    }
    return '${folder.fileCount} file${folder.fileCount != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2D2D2D),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF404040),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            folder.icon,
            color: Colors.white70,
            size: 24,
          ),
        ),
        title: Text(
          folder.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _countLabel,
          style: TextStyle(
            color: Colors.white.withAlpha(128),
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
