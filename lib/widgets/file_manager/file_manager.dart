import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/file_item.dart';
import 'folder_browser.dart';
import 'file_list_view.dart';

/// Sort options for files
enum FileSortOption {
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
  sizeLargest,
  sizeSmallest,
}

extension FileSortOptionExtension on FileSortOption {
  String get label {
    switch (this) {
      case FileSortOption.dateNewest:
        return 'Date (Newest)';
      case FileSortOption.dateOldest:
        return 'Date (Oldest)';
      case FileSortOption.nameAZ:
        return 'Name (A-Z)';
      case FileSortOption.nameZA:
        return 'Name (Z-A)';
      case FileSortOption.sizeLargest:
        return 'Size (Largest)';
      case FileSortOption.sizeSmallest:
        return 'Size (Smallest)';
    }
  }

  IconData get icon {
    switch (this) {
      case FileSortOption.dateNewest:
      case FileSortOption.dateOldest:
        return Icons.calendar_today_rounded;
      case FileSortOption.nameAZ:
      case FileSortOption.nameZA:
        return Icons.sort_by_alpha_rounded;
      case FileSortOption.sizeLargest:
      case FileSortOption.sizeSmallest:
        return Icons.storage_rounded;
    }
  }
}

/// Custom file manager widget for browsing and selecting files from storage
class FileManager extends StatefulWidget {
  final FileMediaType mediaType;
  final bool allowMultiple;
  final int maxSelection;
  final String? title;

  const FileManager({
    super.key,
    required this.mediaType,
    this.allowMultiple = false,
    this.maxSelection = 1,
    this.title,
  });

  /// Show the file manager as a full-screen overlay.
  /// Returns null if cancelled, or a list of [SelectedFile] if selected.
  static Future<List<SelectedFile>?> show({
    required BuildContext context,
    required FileMediaType mediaType,
    bool allowMultiple = false,
    int maxSelection = 1,
    String? title,
  }) async {
    return Navigator.of(context).push<List<SelectedFile>>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FileManager(
            mediaType: mediaType,
            allowMultiple: allowMultiple,
            maxSelection: maxSelection,
            title: title,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  State<FileManager> createState() => _FileManagerState();
}

class _FileManagerState extends State<FileManager> {
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _error;
  FileSortOption _sortOption = FileSortOption.dateNewest;

  // Navigation stack
  final List<Directory> _navigationStack = [];
  Directory? _currentDirectory;

  // Root directories to show (storage locations)
  List<Directory> _rootDirectories = [];

  // For selection
  final Set<FileItem> _selectedFiles = {};

  // Keys for refreshing views
  final GlobalKey<FolderBrowserState> _folderBrowserKey = GlobalKey();
  final GlobalKey<FileListViewState> _fileListViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadRoots();
  }

  Future<void> _requestPermissionAndLoadRoots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Request storage permission
      final status = await Permission.manageExternalStorage.request();
      
      if (!status.isGranted) {
        // Try regular storage permission as fallback
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
            _error = 'Storage permission denied. Please grant access to browse files.';
          });
          return;
        }
      }

      _hasPermission = true;

      // Get root storage directories
      _rootDirectories = await _getStorageDirectories();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error accessing storage: $e';
      });
    }
  }

  Future<List<Directory>> _getStorageDirectories() async {
    final List<Directory> roots = [];

    // Internal storage
    final internalStorage = Directory('/storage/emulated/0');
    if (await internalStorage.exists()) {
      roots.add(internalStorage);
    }

    // Check for external SD card
    try {
      final storageDir = Directory('/storage');
      if (await storageDir.exists()) {
        await for (final entity in storageDir.list()) {
          if (entity is Directory && 
              !entity.path.contains('emulated') &&
              !entity.path.contains('self')) {
            roots.add(entity);
          }
        }
      }
    } catch (_) {}

    return roots;
  }

  Future<void> _onRefresh() async {
    if (_currentDirectory != null) {
      _fileListViewKey.currentState?.refresh();
    } else {
      _folderBrowserKey.currentState?.refresh();
    }
  }

  void _onFolderSelected(Directory directory) {
    setState(() {
      if (_currentDirectory != null) {
        _navigationStack.add(_currentDirectory!);
      }
      _currentDirectory = directory;
    });
  }

  void _onNavigateBack() {
    setState(() {
      if (_navigationStack.isNotEmpty) {
        _currentDirectory = _navigationStack.removeLast();
      } else {
        _currentDirectory = null;
      }
    });
  }

  void _onNavigateToRoot() {
    setState(() {
      _navigationStack.clear();
      _currentDirectory = null;
    });
  }

  void _onFileSelected(FileItem file) {
    setState(() {
      if (widget.allowMultiple) {
        // Multi-selection: toggle selection
        if (_selectedFiles.contains(file)) {
          _selectedFiles.remove(file);
        } else if (_selectedFiles.length < widget.maxSelection) {
          _selectedFiles.add(file);
        }
      } else {
        // Single selection: clear previous and select new (or deselect if same)
        if (_selectedFiles.contains(file)) {
          _selectedFiles.remove(file);
        } else {
          _selectedFiles.clear();
          _selectedFiles.add(file);
        }
      }
    });
  }

  void _onConfirmSelection() {
    if (_selectedFiles.isEmpty) return;

    final List<SelectedFile> results = _selectedFiles.map((file) {
      return SelectedFile(
        fileItem: file,
        thumbnail: file.thumbnail,
      );
    }).toList();

    Navigator.of(context).pop(results);
  }

  void _onClose() {
    Navigator.of(context).pop(null);
  }

  void _onSortChanged(FileSortOption? option) {
    if (option != null && option != _sortOption) {
      setState(() {
        _sortOption = option;
      });
      // Trigger refresh in file list view
      _fileListViewKey.currentState?.refresh();
    }
  }
  
  bool get _isAllSelected {
    final allFiles = _fileListViewKey.currentState?.allFiles ?? [];
    if (allFiles.isEmpty) return false;
    return allFiles.every((file) => _selectedFiles.contains(file));
  }
  
  void _onSelectAll() {
    final allFiles = _fileListViewKey.currentState?.allFiles ?? [];
    if (allFiles.isEmpty) return;
    
    setState(() {
      if (_isAllSelected) {
        // Deselect all
        _selectedFiles.clear();
      } else {
        // Select all (respecting maxSelection)
        _selectedFiles.clear();
        final toSelect = allFiles.take(widget.maxSelection).toList();
        _selectedFiles.addAll(toSelect);
      }
    });
  }

  String get _title {
    if (widget.title != null) return widget.title!;

    final type = widget.mediaType.label;
    if (widget.allowMultiple) {
      return 'Select ${type}s';
    }
    return 'Select $type';
  }

  String get _currentPath {
    if (_currentDirectory == null) return 'Storage';
    
    final path = _currentDirectory!.path;
    // Simplify path for display
    if (path.startsWith('/storage/emulated/0/')) {
      return path.replaceFirst('/storage/emulated/0/', 'Internal/');
    }
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _currentDirectory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _onNavigateBack,
              )
            : null,
        leadingWidth: _currentDirectory != null ? 56 : 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _currentDirectory != null ? _currentPath : _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_currentDirectory != null && _navigationStack.isNotEmpty)
              GestureDetector(
                onTap: _onNavigateToRoot,
                child: Text(
                  'Go to root',
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Select All button (only in file list view when multi-select is enabled)
          if (_currentDirectory != null && widget.allowMultiple)
            TextButton(
              onPressed: _onSelectAll,
              child: Text(
                _isAllSelected ? 'Deselect All' : 'Select All',
                style: const TextStyle(
                  color: Color(0xFF00D9FF),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
          // Sort dropdown (only in file list view)
          if (_currentDirectory != null)
            PopupMenuButton<FileSortOption>(
              icon: const Icon(Icons.sort_rounded, color: Colors.white70),
              tooltip: 'Sort',
              color: const Color(0xFF2D2D2D),
              onSelected: _onSortChanged,
              itemBuilder: (context) => FileSortOption.values.map((option) {
                final isSelected = option == _sortOption;
                return PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        option.icon,
                        size: 20,
                        color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        option.label,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00D9FF) : Colors.white,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Color(0xFF00D9FF),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: _onClose,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _selectedFiles.isNotEmpty ? _buildSelectionBar() : null,
    );
  }

  Widget _buildBody() {
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
                onPressed: _requestPermissionAndLoadRoots,
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

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_off_rounded,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              const Text(
                'Storage access required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant permission to access files on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    // Show folder browser or file list based on current directory
    if (_currentDirectory == null) {
      return FolderBrowser(
        key: _folderBrowserKey,
        rootDirectories: _rootDirectories,
        mediaType: widget.mediaType,
        onFolderSelected: _onFolderSelected,
      );
    } else {
      return FileListView(
        key: _fileListViewKey,
        directory: _currentDirectory!,
        mediaType: widget.mediaType,
        allowMultiple: widget.allowMultiple,
        selectedFiles: _selectedFiles,
        onFileSelected: _onFileSelected,
        onFolderSelected: _onFolderSelected,
        sortOption: _sortOption,
      );
    }
  }

  Widget _buildSelectionBar() {
    final count = _selectedFiles.length;
    final label = widget.allowMultiple
        ? '$count ${widget.mediaType.label.toLowerCase()}${count > 1 ? 's' : ''} selected'
        : '1 ${widget.mediaType.label.toLowerCase()} selected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(
          top: BorderSide(color: Color(0xFF404040)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00D9FF),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _onConfirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
