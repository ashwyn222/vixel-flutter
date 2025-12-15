import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  /// Copy a file to cache directory for FFmpeg access (needed on Android)
  /// Returns the new file path that FFmpeg can access
  static Future<String> copyToAccessiblePath(String sourcePath, String prefix) async {
    if (!Platform.isAndroid) {
      // On non-Android platforms, the original path should work
      return sourcePath;
    }
    
    final cacheDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Get extension from source path
    String extension = p.extension(sourcePath);
    if (extension.isEmpty) {
      // Try to infer extension from prefix type
      if (prefix == 'audio') {
        extension = '.mp3'; // Default audio extension
      } else if (prefix == 'video' || prefix == 'input_video') {
        extension = '.mp4'; // Default video extension
      } else if (prefix == 'photo' || prefix == 'image' || prefix == 'watermark') {
        extension = '.jpg'; // Default image extension
      }
    }
    
    // Create a clean filename without special characters
    final targetPath = p.join(cacheDir.path, '${prefix}_$timestamp$extension');
    
    final sourceFile = File(sourcePath);
    await sourceFile.copy(targetPath);
    
    return targetPath;
  }

  static Directory? _tempDir;
  static Directory? _outputDir;
  
  // Subfolder names for different operation types (Hindi)
  static const Map<String, String> _subfolderNames = {
    'compressed': 'संपीड़ित',        // Compressed
    'cut': 'कटा_हुआ',              // Cut
    'merged': 'जोड़ा_गया',          // Merged
    'extracted': 'ऑडियो_निकाला',    // Extracted Audio
    'audio_on_video': 'वीडियो_पर_ऑडियो', // Audio on Video
    'slideshow': 'फोटो_से_वीडियो',   // Photos to Video
    'watermarked': 'वॉटरमार्क',      // Watermarked
  };

  /// Initialize storage directories
  static Future<void> init() async {
    if (Platform.isAndroid) {
      // On Android:
      // - Temp files go to cache directory (private, auto-cleaned by system)
      // - Output files go to public Downloads/Vixel folder (accessible by file managers)
      final cacheDir = await getTemporaryDirectory();
      _tempDir = Directory(p.join(cacheDir.path, 'vixel_temp'));
      
      // Use public Downloads folder for output files
      _outputDir = Directory('/storage/emulated/0/Download/Vixel');
    } else {
      // On other platforms, use application documents directory
      final baseDir = await getApplicationDocumentsDirectory();
      _tempDir = Directory(p.join(baseDir.path, 'vixel_temp'));
      _outputDir = Directory(p.join(baseDir.path, 'vixel_output'));
    }

    if (!await _tempDir!.exists()) {
      await _tempDir!.create(recursive: true);
    }
    if (!await _outputDir!.exists()) {
      await _outputDir!.create(recursive: true);
    }
    
    // Create all subfolders
    for (final subfolder in _subfolderNames.values) {
      final subDir = Directory(p.join(_outputDir!.path, subfolder));
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
      }
    }
  }

  /// Get temp directory path
  static Future<String> getTempDir() async {
    if (_tempDir == null) await init();
    return _tempDir!.path;
  }

  /// Get output directory path
  static Future<String> getOutputDir() async {
    if (_outputDir == null) await init();
    return _outputDir!.path;
  }
  
  /// Get subfolder path for a specific operation type
  static Future<String> getSubfolderPath(String prefix) async {
    final outputDir = await getOutputDir();
    final subfolder = _subfolderNames[prefix] ?? 'Other';
    final subfolderPath = p.join(outputDir, subfolder);
    
    // Ensure subfolder exists
    final dir = Directory(subfolderPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return subfolderPath;
  }
  
  /// Generate human-readable timestamp string
  static String _getReadableTimestamp() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    return '$year-$month-${day}_$hour-$minute-$second';
  }

  /// Generate unique temp file path
  static Future<String> getTempFilePath(String extension) async {
    final tempDir = await getTempDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(tempDir, 'temp_$timestamp.$extension');
  }

  /// Generate output file path with prefix (now uses subfolders and readable timestamps)
  static Future<String> getOutputFilePath(String prefix, String extension) async {
    final subfolderPath = await getSubfolderPath(prefix);
    final timestamp = _getReadableTimestamp();
    return p.join(subfolderPath, '${prefix}_$timestamp.$extension');
  }

  /// Copy file to temp directory
  static Future<String> copyToTemp(String sourcePath) async {
    final file = File(sourcePath);
    final extension = p.extension(sourcePath).replaceFirst('.', '');
    final tempPath = await getTempFilePath(extension);
    await file.copy(tempPath);
    return tempPath;
  }

  /// Get storage info
  static Future<StorageInfo> getStorageInfo() async {
    int totalSize = 0;
    int totalFiles = 0;
    int tempFiles = 0;
    int outputFiles = 0;

    if (_tempDir != null && await _tempDir!.exists()) {
      await for (final entity in _tempDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
          totalFiles++;
          tempFiles++;
        }
      }
    }

    if (_outputDir != null && await _outputDir!.exists()) {
      await for (final entity in _outputDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
          totalFiles++;
          outputFiles++;
        }
      }
    }

    return StorageInfo(
      totalSize: totalSize,
      totalFiles: totalFiles,
      tempFiles: tempFiles,
      outputFiles: outputFiles,
    );
  }

  /// Clear temp files
  static Future<ClearResult> clearTempFiles() async {
    int deletedCount = 0;
    int freedSpace = 0;

    if (_tempDir != null && await _tempDir!.exists()) {
      await for (final entity in _tempDir!.list(recursive: true)) {
        if (entity is File) {
          try {
            final size = await entity.length();
            await entity.delete();
            deletedCount++;
            freedSpace += size;
          } catch (_) {}
        }
      }
    }

    return ClearResult(deletedCount: deletedCount, freedSpace: freedSpace);
  }

  /// Clear all files (temp + output)
  static Future<ClearResult> clearAllFiles() async {
    int deletedCount = 0;
    int freedSpace = 0;

    for (final dir in [_tempDir, _outputDir]) {
      if (dir != null && await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              final size = await entity.length();
              await entity.delete();
              deletedCount++;
              freedSpace += size;
            } catch (_) {}
          }
        }
      }
    }

    return ClearResult(deletedCount: deletedCount, freedSpace: freedSpace);
  }

  /// Clear old files (older than specified days)
  static Future<ClearResult> clearOldFiles(int days) async {
    if (days < 0) {
      return ClearResult(deletedCount: 0, freedSpace: 0);
    }

    int deletedCount = 0;
    int freedSpace = 0;
    final cutoffTime = DateTime.now().subtract(Duration(days: days));

    for (final dir in [_tempDir, _outputDir]) {
      if (dir != null && await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              if (stat.modified.isBefore(cutoffTime)) {
                final size = await entity.length();
                await entity.delete();
                deletedCount++;
                freedSpace += size;
              }
            } catch (_) {}
          }
        }
      }
    }

    return ClearResult(deletedCount: deletedCount, freedSpace: freedSpace);
  }

  /// Delete specific file
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if file exists
  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  /// Get file size
  static Future<int> getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class StorageInfo {
  final int totalSize;
  final int totalFiles;
  final int tempFiles;
  final int outputFiles;

  StorageInfo({
    required this.totalSize,
    required this.totalFiles,
    required this.tempFiles,
    required this.outputFiles,
  });

  String get totalSizeFormatted => StorageService.formatFileSize(totalSize);
}

class ClearResult {
  final int deletedCount;
  final int freedSpace;

  ClearResult({
    required this.deletedCount,
    required this.freedSpace,
  });

  String get freedSpaceFormatted => StorageService.formatFileSize(freedSpace);
}
