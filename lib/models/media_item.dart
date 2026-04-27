import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

/// Enum for media types supported by the picker
enum MediaType {
  video,
  audio,
  image,
}

/// Extension to convert MediaType to PhotoManager's RequestType
extension MediaTypeExtension on MediaType {
  RequestType get requestType {
    switch (this) {
      case MediaType.video:
        return RequestType.video;
      case MediaType.audio:
        return RequestType.audio;
      case MediaType.image:
        return RequestType.image;
    }
  }
  
  String get label {
    switch (this) {
      case MediaType.video:
        return 'Video';
      case MediaType.audio:
        return 'Audio';
      case MediaType.image:
        return 'Photo';
    }
  }
}

/// Wrapper class for selected media with additional metadata
class SelectedMedia {
  final AssetEntity asset;
  final String? path;
  final Uint8List? thumbnail;
  
  SelectedMedia({
    required this.asset,
    this.path,
    this.thumbnail,
  });
  
  String get name => asset.title ?? 'Unknown';
  
  Duration get duration => Duration(seconds: asset.duration);
  
  String get formattedDuration {
    final d = duration;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
  
  int get sizeInBytes => asset.size.width.toInt() * asset.size.height.toInt();
  
  DateTime? get createDate => asset.createDateTime;
}
