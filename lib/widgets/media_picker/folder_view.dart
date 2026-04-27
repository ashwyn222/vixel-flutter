import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/media_item.dart';

/// Displays a grid of folders/albums with thumbnails and media counts
class FolderView extends StatefulWidget {
  final List<AssetPathEntity> albums;
  final MediaType mediaType;
  final Function(AssetPathEntity) onAlbumSelected;
  final Future<void> Function() onRefresh;
  
  const FolderView({
    super.key,
    required this.albums,
    required this.mediaType,
    required this.onAlbumSelected,
    required this.onRefresh,
  });

  @override
  State<FolderView> createState() => FolderViewState();
}

class FolderViewState extends State<FolderView> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: const Color(0xFF00D9FF),
      backgroundColor: const Color(0xFF2D2D2D),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: widget.albums.length,
        itemBuilder: (context, index) {
          return _FolderTile(
            album: widget.albums[index],
            mediaType: widget.mediaType,
            onTap: () => widget.onAlbumSelected(widget.albums[index]),
          );
        },
      ),
    );
  }
}

class _FolderTile extends StatefulWidget {
  final AssetPathEntity album;
  final MediaType mediaType;
  final VoidCallback onTap;
  
  const _FolderTile({
    required this.album,
    required this.mediaType,
    required this.onTap,
  });

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> with SingleTickerProviderStateMixin {
  Uint8List? _thumbnail;
  int _assetCount = 0;
  bool _isLoading = true;
  
  late AnimationController _shimmerController;
  
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadThumbnailAndCount();
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }
  
  Future<void> _loadThumbnailAndCount() async {
    try {
      // For audio, assetCountAsync may not work correctly
      // So we fetch actual assets to get the real count
      int count;
      List<AssetEntity> assets;
      
      if (widget.mediaType == MediaType.audio) {
        // Fetch all assets to get accurate count for audio
        assets = await widget.album.getAssetListRange(start: 0, end: 1000);
        count = assets.length;
      } else {
        // For video/image, assetCountAsync works fine
        count = await widget.album.assetCountAsync;
        assets = await widget.album.getAssetListRange(start: 0, end: 1);
      }
      
      // Get thumbnail from first asset
      Uint8List? thumb;
      if (assets.isNotEmpty) {
        try {
          thumb = await assets.first.thumbnailDataWithSize(
            const ThumbnailSize(300, 300),
            quality: 80,
          );
        } catch (_) {
          // Audio files may not have thumbnails
        }
      }
      
      if (mounted) {
        setState(() {
          _assetCount = count;
          _thumbnail = thumb;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: _buildThumbnail(),
            ),
            // Folder info
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    _buildTextSkeleton(width: 80)
                  else
                    Text(
                      _getFolderDisplayName(widget.album.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  if (_isLoading)
                    _buildTextSkeleton(width: 50)
                  else
                    Text(
                      '$_assetCount ${widget.mediaType.label.toLowerCase()}${_assetCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
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
  
  Widget _buildThumbnail() {
    if (_isLoading) {
      return _buildShimmer();
    }
    
    if (_thumbnail != null) {
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
      );
    }
    
    // Placeholder for empty folder or audio
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Icon(
          _getPlaceholderIcon(),
          size: 48,
          color: Colors.white24,
        ),
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
  
  Widget _buildTextSkeleton({required double width}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: width,
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
    );
  }
  
  IconData _getPlaceholderIcon() {
    switch (widget.mediaType) {
      case MediaType.video:
        return Icons.video_library_rounded;
      case MediaType.audio:
        return Icons.library_music_rounded;
      case MediaType.image:
        return Icons.photo_library_rounded;
    }
  }
  
  String _getFolderDisplayName(String name) {
    // Make common folder names more readable
    if (name.toLowerCase() == 'recent' || name.toLowerCase() == 'all') {
      return 'All ${widget.mediaType.label}s';
    }
    if (name.toLowerCase() == 'camera') {
      return 'Camera';
    }
    if (name.toLowerCase() == 'screenshots') {
      return 'Screenshots';
    }
    if (name.toLowerCase() == 'download' || name.toLowerCase() == 'downloads') {
      return 'Downloads';
    }
    return name;
  }
}
