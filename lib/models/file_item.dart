import 'dart:io';
import 'dart:typed_data';

/// Enum for file types supported by the file manager
enum FileMediaType {
  video,
  audio,
  image,
  all,
}

extension FileMediaTypeExtension on FileMediaType {
  String get label {
    switch (this) {
      case FileMediaType.video:
        return 'Video';
      case FileMediaType.audio:
        return 'Audio';
      case FileMediaType.image:
        return 'Photo';
      case FileMediaType.all:
        return 'Media';
    }
  }

  List<String> get extensions {
    switch (this) {
      case FileMediaType.video:
        return ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.3gp', '.m4v'];
      case FileMediaType.audio:
        return ['.mp3', '.wav', '.aac', '.flac', '.ogg', '.wma', '.m4a', '.opus'];
      case FileMediaType.image:
        return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif'];
      case FileMediaType.all:
        return [
          ...FileMediaType.video.extensions,
          ...FileMediaType.audio.extensions,
          ...FileMediaType.image.extensions,
        ];
    }
  }

  bool matchesFile(String fileName) {
    final lowerName = fileName.toLowerCase();
    return extensions.any((ext) => lowerName.endsWith(ext));
  }
}

/// Represents a folder in the file system
class FolderItem {
  final Directory directory;
  final String name;
  final int fileCount;
  final Uint8List? thumbnail;
  final DateTime? modifiedDate;

  FolderItem({
    required this.directory,
    required this.name,
    required this.fileCount,
    this.thumbnail,
    this.modifiedDate,
  });

  String get path => directory.path;
}

/// Represents a file in the file system
class FileItem {
  final File file;
  final String name;
  final int sizeInBytes;
  final DateTime? modifiedDate;
  final Duration? duration;
  final Uint8List? thumbnail;
  final FileMediaType mediaType;

  FileItem({
    required this.file,
    required this.name,
    required this.sizeInBytes,
    this.modifiedDate,
    this.duration,
    this.thumbnail,
    required this.mediaType,
  });

  String get path => file.path;

  String get extension {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < name.length - 1) {
      return name.substring(dotIndex).toUpperCase();
    }
    return '';
  }

  String get formattedSize {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String get formattedDuration {
    if (duration == null) return '';
    final d = duration!;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String get formattedDate {
    if (modifiedDate == null) return '';
    final d = modifiedDate!;
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// Wrapper for selected files from the file manager
class SelectedFile {
  final FileItem fileItem;
  final Uint8List? thumbnail;

  SelectedFile({
    required this.fileItem,
    this.thumbnail,
  });

  String get path => fileItem.path;
  String get name => fileItem.name;
  int get sizeInBytes => fileItem.sizeInBytes;
  String get formattedSize => fileItem.formattedSize;
  Duration? get duration => fileItem.duration;
}
