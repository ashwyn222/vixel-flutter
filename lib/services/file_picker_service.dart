import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum for picker type preference
enum PickerType {
  system,  // Default system file browser
  gallery, // Gallery-style grid picker (wechat_assets_picker)
}

/// Service to handle file picking with configurable picker type and concurrent jobs
class FilePickerService extends ChangeNotifier {
  static const String _prefsKey = 'file_picker_type';
  static const String _concurrentJobsKey = 'max_concurrent_jobs';
  
  PickerType _pickerType = PickerType.system;
  PickerType get pickerType => _pickerType;
  
  int _maxConcurrentJobs = 1;
  int get maxConcurrentJobs => _maxConcurrentJobs;
  
  // Track currently running jobs
  static int _currentRunningJobs = 0;
  static int get currentRunningJobs => _currentRunningJobs;
  
  FilePickerService() {
    _loadPreference();
  }
  
  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString(_prefsKey);
    if (savedType == 'gallery') {
      _pickerType = PickerType.gallery;
    } else {
      _pickerType = PickerType.system;
    }
    
    _maxConcurrentJobs = prefs.getInt(_concurrentJobsKey) ?? 1;
    notifyListeners();
  }
  
  Future<void> setPickerType(PickerType type) async {
    _pickerType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, type == PickerType.gallery ? 'gallery' : 'system');
    notifyListeners();
  }
  
  Future<void> setMaxConcurrentJobs(int count) async {
    _maxConcurrentJobs = count.clamp(1, 3);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrentJobsKey, _maxConcurrentJobs);
    notifyListeners();
  }
  
  /// Check if we can start a new job based on concurrent limit
  static bool canStartNewJob() {
    return true; // For now, always allow - actual limiting happens in job execution
  }
  
  /// Increment running job count
  static void jobStarted() {
    _currentRunningJobs++;
  }
  
  /// Decrement running job count
  static void jobFinished() {
    if (_currentRunningJobs > 0) {
      _currentRunningJobs--;
    }
  }
  
  /// Pick a single video file
  Future<File?> pickVideo(BuildContext context) async {
    if (_pickerType == PickerType.gallery) {
      return _pickVideoFromGallery(context);
    } else {
      return _pickVideoFromSystem();
    }
  }
  
  /// Pick multiple video files
  Future<List<File>> pickVideos(BuildContext context, {int? maxCount}) async {
    if (_pickerType == PickerType.gallery) {
      return _pickVideosFromGallery(context, maxCount: maxCount);
    } else {
      return _pickVideosFromSystem();
    }
  }
  
  /// Pick a single audio file
  Future<File?> pickAudio(BuildContext context) async {
    // Gallery picker doesn't support audio well, always use system picker
    return _pickAudioFromSystem();
  }
  
  /// Pick multiple image files
  Future<List<File>> pickImages(BuildContext context, {int? maxCount}) async {
    if (_pickerType == PickerType.gallery) {
      return _pickImagesFromGallery(context, maxCount: maxCount);
    } else {
      return _pickImagesFromSystem();
    }
  }
  
  /// Pick a single image file (for watermark)
  Future<File?> pickImage(BuildContext context) async {
    if (_pickerType == PickerType.gallery) {
      final images = await _pickImagesFromGallery(context, maxCount: 1);
      return images.isNotEmpty ? images.first : null;
    } else {
      return _pickImageFromSystem();
    }
  }
  
  // ============ System File Picker Methods ============
  
  Future<File?> _pickVideoFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      return File(result.files.first.path!);
    }
    return null;
  }
  
  Future<List<File>> _pickVideosFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
    }
    return [];
  }
  
  Future<File?> _pickAudioFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      return File(result.files.first.path!);
    }
    return null;
  }
  
  Future<List<File>> _pickImagesFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
    }
    return [];
  }
  
  Future<File?> _pickImageFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      return File(result.files.first.path!);
    }
    return null;
  }
  
  // ============ Gallery Picker Methods (wechat_assets_picker) ============
  
  Future<File?> _pickVideoFromGallery(BuildContext context) async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.video,
        themeColor: Theme.of(context).primaryColor,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final file = await result.first.file;
      return file;
    }
    return null;
  }
  
  Future<List<File>> _pickVideosFromGallery(BuildContext context, {int? maxCount}) async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxCount ?? 10,
        requestType: RequestType.video,
        themeColor: Theme.of(context).primaryColor,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final files = <File>[];
      for (final asset in result) {
        final file = await asset.file;
        if (file != null) {
          files.add(file);
        }
      }
      return files;
    }
    return [];
  }
  
  Future<List<File>> _pickImagesFromGallery(BuildContext context, {int? maxCount}) async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxCount ?? 20,
        requestType: RequestType.image,
        themeColor: Theme.of(context).primaryColor,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final files = <File>[];
      for (final asset in result) {
        final file = await asset.file;
        if (file != null) {
          files.add(file);
        }
      }
      return files;
    }
    return [];
  }
}

