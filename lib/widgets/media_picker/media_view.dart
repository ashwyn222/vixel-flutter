import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../../models/media_item.dart';
import 'media_picker.dart';

/// Displays a grid of media files (videos, images, or audio) from a selected album
class MediaView extends StatefulWidget {
  final AssetPathEntity album;
  final MediaType mediaType;
  final bool allowMultiple;
  final Set<AssetEntity> selectedAssets;
  final Function(AssetEntity) onMediaSelected;
  final SortOption sortOption;
  
  const MediaView({
    super.key,
    required this.album,
    required this.mediaType,
    required this.allowMultiple,
    required this.selectedAssets,
    required this.onMediaSelected,
    required this.sortOption,
  });

  @override
  State<MediaView> createState() => MediaViewState();
}

class MediaViewState extends State<MediaView> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;
  
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadAssets();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(MediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortOption != widget.sortOption) {
      _sortAssets();
    }
  }
  
  void refresh() {
    _loadAssets();
  }
  
  /// Get all loaded assets for select all functionality
  List<AssetEntity> get allAssets => _assets;
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreAssets();
    }
  }
  
  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    
    try {
      final assets = await widget.album.getAssetListPaged(
        page: 0,
        size: _pageSize,
      );
      
      if (mounted) {
        setState(() {
          _assets = assets;
          _currentPage = 0;
          _hasMore = assets.length >= _pageSize;
          _isLoading = false;
        });
        _sortAssets();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadMoreAssets() async {
    if (!_hasMore || _isLoading) return;
    
    try {
      final nextPage = _currentPage + 1;
      final assets = await widget.album.getAssetListPaged(
        page: nextPage,
        size: _pageSize,
      );
      
      if (mounted && assets.isNotEmpty) {
        setState(() {
          _assets.addAll(assets);
          _currentPage = nextPage;
          _hasMore = assets.length >= _pageSize;
        });
        _sortAssets();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      // Silently fail on pagination errors
    }
  }
  
  void _sortAssets() {
    setState(() {
      switch (widget.sortOption) {
        case SortOption.dateNewest:
          _assets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
          break;
        case SortOption.dateOldest:
          _assets.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
          break;
        case SortOption.nameAZ:
          _assets.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
          break;
        case SortOption.nameZA:
          _assets.sort((a, b) => (b.title ?? '').compareTo(a.title ?? ''));
          break;
        case SortOption.sizeLargest:
          _assets.sort((a, b) => b.size.width.compareTo(a.size.width));
          break;
        case SortOption.sizeSmallest:
          _assets.sort((a, b) => a.size.width.compareTo(b.size.width));
          break;
        case SortOption.durationLongest:
          _assets.sort((a, b) => b.duration.compareTo(a.duration));
          break;
        case SortOption.durationShortest:
          _assets.sort((a, b) => a.duration.compareTo(b.duration));
          break;
      }
    });
  }
  
  Future<void> _onRefresh() async {
    await _loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonGrid();
    }
    
    if (_assets.isEmpty) {
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
              'No ${widget.mediaType.label.toLowerCase()}s in this folder',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF2D2D2D),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: _assets.length,
        itemBuilder: (context, index) {
          final asset = _assets[index];
          final isSelected = widget.selectedAssets.contains(asset);
          
          return _MediaTile(
            asset: asset,
            mediaType: widget.mediaType,
            isSelected: isSelected,
            showCheckbox: true, // Always show checkbox for confirmation flow
            onTap: () => widget.onMediaSelected(asset),
          );
        },
      ),
    );
  }
  
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const _SkeletonTile();
      },
    );
  }
}

class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile();

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _controller.value, 0),
              end: Alignment(1.0 + 2 * _controller.value, 0),
              colors: const [
                Color(0xFF2D2D2D),
                Color(0xFF3D3D3D),
                Color(0xFF2D2D2D),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _MediaTile extends StatefulWidget {
  final AssetEntity asset;
  final MediaType mediaType;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback onTap;
  
  const _MediaTile({
    required this.asset,
    required this.mediaType,
    required this.isSelected,
    required this.showCheckbox,
    required this.onTap,
  });

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> with SingleTickerProviderStateMixin {
  Uint8List? _thumbnail;
  bool _isLoading = true;
  bool _isPreviewing = false;
  VideoPlayerController? _videoController;
  int? _fileSizeBytes;
  
  late AnimationController _shimmerController;
  
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadThumbnailAndSize();
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadThumbnailAndSize() async {
    try {
      final thumb = await widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(300, 300),
        quality: 80,
      );
      
      // Get file size
      final file = await widget.asset.file;
      final size = file != null ? await file.length() : null;
      
      if (mounted) {
        setState(() {
          _thumbnail = thumb;
          _fileSizeBytes = size;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  Future<void> _startPreview() async {
    if (widget.mediaType != MediaType.video || _isPreviewing) return;
    
    try {
      final file = await widget.asset.file;
      if (file == null || !mounted) return;
      
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0); // Muted preview
      await _videoController!.play();
      
      if (mounted) {
        setState(() => _isPreviewing = true);
      }
    } catch (e) {
      // Failed to start preview, ignore
    }
  }
  
  void _stopPreview() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
    }
    if (mounted) {
      setState(() => _isPreviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _startPreview(),
      onLongPressEnd: (_) => _stopPreview(),
      onLongPressCancel: _stopPreview,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
          border: widget.isSelected
              ? Border.all(color: const Color(0xFF00D9FF), width: 3)
              : null,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnailOrPreview(),
                  
                  // Selection checkbox
                  if (widget.showCheckbox)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? const Color(0xFF00D9FF)
                              : Colors.black.withAlpha(128),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: widget.isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.black,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  
                  // Long press indicator
                  if (_isPreviewing)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'PREVIEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Info area (solid gray like folder view)
            Container(
              padding: const EdgeInsets.all(10),
              child: _isLoading
                  ? _buildInfoSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Duration for video/audio
                        if (widget.mediaType == MediaType.video || 
                            widget.mediaType == MediaType.audio)
                          Row(
                            children: [
                              Icon(
                                widget.mediaType == MediaType.video 
                                    ? Icons.play_arrow_rounded 
                                    : Icons.music_note_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(widget.asset.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        // File size
                        if (_fileSizeBytes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _formatFileSize(_fileSizeBytes!),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              width: 60,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + 2 * _shimmerController.value, 0),
                  end: Alignment(1.0 + 2 * _shimmerController.value, 0),
                  colors: const [
                    Color(0xFF3A3A3A),
                    Color(0xFF4A4A4A),
                    Color(0xFF3A3A3A),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + 2 * _shimmerController.value, 0),
                  end: Alignment(1.0 + 2 * _shimmerController.value, 0),
                  colors: const [
                    Color(0xFF3A3A3A),
                    Color(0xFF4A4A4A),
                    Color(0xFF3A3A3A),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildThumbnailOrPreview() {
    // Show video preview if long pressing
    if (_isPreviewing && _videoController != null && _videoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    
    if (_isLoading) {
      return _buildShimmer();
    }
    
    if (_thumbnail != null) {
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
      );
    }
    
    // Placeholder for audio files without album art
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_note_rounded,
            size: 40,
            color: Color(0xFF00D9FF),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.asset.title ?? 'Audio',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _shimmerController.value, 0),
              end: Alignment(1.0 + 2 * _shimmerController.value, 0),
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF2D2D2D),
                Color(0xFF1A1A1A),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
