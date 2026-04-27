import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/media_item.dart';
import 'folder_view.dart';
import 'media_view.dart';

/// Sort options for media
enum SortOption {
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
  sizeLargest,
  sizeSmallest,
  durationLongest,
  durationShortest,
}

extension SortOptionExtension on SortOption {
  String get label {
    switch (this) {
      case SortOption.dateNewest:
        return 'Date (Newest)';
      case SortOption.dateOldest:
        return 'Date (Oldest)';
      case SortOption.nameAZ:
        return 'Name (A-Z)';
      case SortOption.nameZA:
        return 'Name (Z-A)';
      case SortOption.sizeLargest:
        return 'Size (Largest)';
      case SortOption.sizeSmallest:
        return 'Size (Smallest)';
      case SortOption.durationLongest:
        return 'Duration (Longest)';
      case SortOption.durationShortest:
        return 'Duration (Shortest)';
    }
  }
  
  IconData get icon {
    switch (this) {
      case SortOption.dateNewest:
      case SortOption.dateOldest:
        return Icons.calendar_today_rounded;
      case SortOption.nameAZ:
      case SortOption.nameZA:
        return Icons.sort_by_alpha_rounded;
      case SortOption.sizeLargest:
      case SortOption.sizeSmallest:
        return Icons.storage_rounded;
      case SortOption.durationLongest:
      case SortOption.durationShortest:
        return Icons.timer_rounded;
    }
  }
}

/// Custom media picker widget that provides a native-like experience
/// for selecting videos, audio, or images from the device.
class MediaPicker extends StatefulWidget {
  final MediaType mediaType;
  final bool allowMultiple;
  final int maxSelection;
  final String? title;
  
  const MediaPicker({
    super.key,
    required this.mediaType,
    this.allowMultiple = false,
    this.maxSelection = 1,
    this.title,
  });
  
  /// Show the media picker as a full-screen overlay.
  /// Returns null if cancelled, or a list of [SelectedMedia] if selected.
  static Future<List<SelectedMedia>?> show({
    required BuildContext context,
    required MediaType mediaType,
    bool allowMultiple = false,
    int maxSelection = 1,
    String? title,
  }) async {
    return Navigator.of(context).push<List<SelectedMedia>>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MediaPicker(
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
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _error;
  SortOption _sortOption = SortOption.dateNewest;
  
  // For multi-selection
  final Set<AssetEntity> _selectedAssets = {};
  
  // Key for refreshing views
  final GlobalKey<FolderViewState> _folderViewKey = GlobalKey();
  final GlobalKey<MediaViewState> _mediaViewKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadAlbums();
  }
  
  Future<void> _requestPermissionAndLoadAlbums() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // First, request Android permissions using permission_handler
      // This ensures native permissions are granted before photo_manager tries to access them
      Permission? mediaPermission;
      
      if (widget.mediaType == MediaType.video) {
        mediaPermission = Permission.videos;
      } else if (widget.mediaType == MediaType.audio) {
        mediaPermission = Permission.audio;
      } else {
        mediaPermission = Permission.photos;
      }
      
      // Request the appropriate permission
      var permissionStatus = await mediaPermission.request();
      
      // If denied, try requesting photo permission as fallback (for older Android versions)
      if (!permissionStatus.isGranted && widget.mediaType == MediaType.video) {
        permissionStatus = await Permission.photos.request();
      }
      
      if (!permissionStatus.isGranted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
          _error = 'Permission denied. Please grant access to your media library.';
        });
        return;
      }
      
      // Now request permission from photo_manager
      // This should work now that Android permissions are granted
      PermissionState? photoManagerPermission;
      try {
        photoManagerPermission = await PhotoManager.requestPermissionExtend();
      } catch (e) {
        // If photo_manager fails, we can still proceed if Android permissions are granted
        debugPrint('PhotoManager permission request failed: $e');
        // Continue anyway if Android permission is granted
        if (permissionStatus.isGranted) {
          photoManagerPermission = PermissionState.authorized;
        }
      }
      
      if (photoManagerPermission != null && !photoManagerPermission.isAuth && !permissionStatus.isGranted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
          _error = 'Permission denied. Please grant access to your media library.';
        });
        return;
      }
      
      _hasPermission = true;
      
      // Load albums filtered by media type
      FilterOptionGroup? filterOption;
      if (widget.mediaType == MediaType.video) {
        filterOption = FilterOptionGroup(
          videoOption: const FilterOption(
            durationConstraint: DurationConstraint(
              min: Duration.zero,
              max: Duration(hours: 24),
            ),
          ),
        );
      } else if (widget.mediaType == MediaType.audio) {
        filterOption = FilterOptionGroup(
          audioOption: const FilterOption(
            durationConstraint: DurationConstraint(
              min: Duration.zero,
              max: Duration(hours: 24),
            ),
          ),
        );
      }
      
      final albums = await PhotoManager.getAssetPathList(
        type: widget.mediaType.requestType,
        hasAll: true,
        filterOption: filterOption,
      );
      
      // Filter out empty albums and sort
      final nonEmptyAlbums = <AssetPathEntity>[];
      for (final album in albums) {
        final count = await album.assetCountAsync;
        if (count > 0) {
          nonEmptyAlbums.add(album);
        }
      }
      
      // Sort albums - "Recent" or "All" first, then by name
      nonEmptyAlbums.sort((a, b) {
        if (a.isAll) return -1;
        if (b.isAll) return 1;
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _albums = nonEmptyAlbums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading media: $e';
      });
    }
  }
  
  Future<void> _onRefresh() async {
    await _requestPermissionAndLoadAlbums();
  }
  
  void _onAlbumSelected(AssetPathEntity album) {
    setState(() {
      _selectedAlbum = album;
    });
  }
  
  void _onBackToFolders() {
    setState(() {
      _selectedAlbum = null;
    });
  }
  
  void _onMediaSelected(AssetEntity asset) {
    setState(() {
      if (widget.allowMultiple) {
        // Multi-selection: toggle selection
        if (_selectedAssets.contains(asset)) {
          _selectedAssets.remove(asset);
        } else if (_selectedAssets.length < widget.maxSelection) {
          _selectedAssets.add(asset);
        }
      } else {
        // Single selection: clear previous and select new (or deselect if same)
        if (_selectedAssets.contains(asset)) {
          _selectedAssets.remove(asset);
        } else {
          _selectedAssets.clear();
          _selectedAssets.add(asset);
        }
      }
    });
  }
  
  void _onConfirmSelection() async {
    if (_selectedAssets.isEmpty) return;
    
    final List<SelectedMedia> results = [];
    
    for (final asset in _selectedAssets) {
      try {
        // Get file path - use originFile for audio to get the actual file
        final file = await asset.originFile ?? await asset.file;
        
        // Try to get thumbnail (may fail for audio files)
        Uint8List? thumbnail;
        try {
          thumbnail = await asset.thumbnailDataWithSize(
            const ThumbnailSize(200, 200),
          );
        } catch (_) {
          // Audio files may not have thumbnails, that's okay
        }
        
        results.add(SelectedMedia(
          asset: asset,
          path: file?.path,
          thumbnail: thumbnail,
        ));
      } catch (e) {
        debugPrint('Error processing asset: $e');
      }
    }
    
    if (mounted && results.isNotEmpty) {
      Navigator.of(context).pop(results);
    }
  }
  
  void _onClose() {
    Navigator.of(context).pop(null);
  }
  
  void _onSortChanged(SortOption? option) {
    if (option != null && option != _sortOption) {
      setState(() {
        _sortOption = option;
      });
      // Trigger refresh in media view
      _mediaViewKey.currentState?.refresh();
    }
  }
  
  bool get _isAllSelected {
    final allAssets = _mediaViewKey.currentState?.allAssets ?? [];
    if (allAssets.isEmpty) return false;
    return allAssets.every((asset) => _selectedAssets.contains(asset));
  }
  
  void _onSelectAll() {
    final allAssets = _mediaViewKey.currentState?.allAssets ?? [];
    if (allAssets.isEmpty) return;
    
    setState(() {
      if (_isAllSelected) {
        // Deselect all
        _selectedAssets.clear();
      } else {
        // Select all (respecting maxSelection)
        _selectedAssets.clear();
        final toSelect = allAssets.take(widget.maxSelection).toList();
        _selectedAssets.addAll(toSelect);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _selectedAlbum != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _onBackToFolders,
              )
            : null,
        leadingWidth: _selectedAlbum != null ? 56 : 0,
        titleSpacing: 16,
        title: Text(
          _selectedAlbum?.name ?? _title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          // Select All button (only in media view when multi-select is enabled)
          if (_selectedAlbum != null && widget.allowMultiple)
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
          // Sort dropdown (only in media view)
          if (_selectedAlbum != null)
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort_rounded, color: Colors.white70),
              tooltip: 'Sort',
              color: const Color(0xFF2D2D2D),
              onSelected: _onSortChanged,
              itemBuilder: (context) => SortOption.values.map((option) {
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
      bottomNavigationBar: _selectedAssets.isNotEmpty
          ? _buildSelectionBar()
          : null,
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
                onPressed: _requestPermissionAndLoadAlbums,
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
                'Media access required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant permission to access your photos and videos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => PhotoManager.openSetting(),
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
    
    if (_albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.mediaType == MediaType.video
                  ? Icons.video_library_outlined
                  : widget.mediaType == MediaType.audio
                      ? Icons.library_music_outlined
                      : Icons.photo_library_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.mediaType.label.toLowerCase()}s found',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show folder view or media view based on selection
    if (_selectedAlbum == null) {
      return FolderView(
        key: _folderViewKey,
        albums: _albums,
        mediaType: widget.mediaType,
        onAlbumSelected: _onAlbumSelected,
        onRefresh: _onRefresh,
      );
    } else {
      return MediaView(
        key: _mediaViewKey,
        album: _selectedAlbum!,
        mediaType: widget.mediaType,
        allowMultiple: widget.allowMultiple,
        selectedAssets: _selectedAssets,
        onMediaSelected: _onMediaSelected,
        sortOption: _sortOption,
      );
    }
  }
  
  Widget _buildSelectionBar() {
    final count = _selectedAssets.length;
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
