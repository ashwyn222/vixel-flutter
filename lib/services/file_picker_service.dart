import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/media_picker/media_picker.dart';
import '../widgets/file_manager/file_manager.dart';
import '../models/media_item.dart';
import '../models/file_item.dart';

/// Enum for picker type preference
enum PickerType {
  files,   // Files - File Browser (browse file system)
  gallery, // Gallery - Gallery picker (media library)
}

/// Service to handle file picking with configurable picker type and concurrent jobs
class FilePickerService extends ChangeNotifier {
  static const String _prefsKey = 'file_picker_type';
  static const String _concurrentJobsKey = 'max_concurrent_jobs';
  
  PickerType _pickerType = PickerType.gallery;
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
    if (savedType == 'files') {
      _pickerType = PickerType.files;
    } else {
      _pickerType = PickerType.gallery;
    }
    
    _maxConcurrentJobs = prefs.getInt(_concurrentJobsKey) ?? 1;
    notifyListeners();
  }
  
  Future<void> setPickerType(PickerType type) async {
    _pickerType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, type == PickerType.files ? 'files' : 'gallery');
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
      return _pickVideoFromFiles(context);
    }
  }
  
  /// Pick multiple video files
  Future<List<File>> pickVideos(BuildContext context, {int? maxCount}) async {
    if (_pickerType == PickerType.gallery) {
      return _pickVideosFromGallery(context, maxCount: maxCount);
    } else {
      return _pickVideosFromFiles(context, maxCount: maxCount);
    }
  }
  
  /// Pick a single audio file
  Future<File?> pickAudio(BuildContext context) async {
    if (_pickerType == PickerType.gallery) {
      return _pickAudioFromGallery(context);
    } else {
      return _pickAudioFromFiles(context);
    }
  }
  
  /// Pick multiple image files
  Future<List<File>> pickImages(BuildContext context, {int? maxCount}) async {
    if (_pickerType == PickerType.gallery) {
      return _pickImagesFromGallery(context, maxCount: maxCount);
    } else {
      return _pickImagesFromFiles(context, maxCount: maxCount);
    }
  }
  
  /// Pick a single image file (for watermark)
  Future<File?> pickImage(BuildContext context) async {
    if (_pickerType == PickerType.gallery) {
      final images = await _pickImagesFromGallery(context, maxCount: 1);
      return images.isNotEmpty ? images.first : null;
    } else {
      return _pickImageFromFiles(context);
    }
  }
  
  // ============ File Manager Methods (Files Browser) ============
  
  Future<File?> _pickVideoFromFiles(BuildContext context) async {
    final result = await FileManager.show(
      context: context,
      mediaType: FileMediaType.video,
      allowMultiple: false,
      maxSelection: 1,
      title: 'Select Video',
    );
    
    if (result != null && result.isNotEmpty) {
      return File(result.first.path);
    }
    return null;
  }
  
  Future<List<File>> _pickVideosFromFiles(BuildContext context, {int? maxCount}) async {
    final result = await FileManager.show(
      context: context,
      mediaType: FileMediaType.video,
      allowMultiple: true,
      maxSelection: maxCount ?? 10,
      title: 'Select Videos',
    );
    
    if (result != null && result.isNotEmpty) {
      return result.map((f) => File(f.path)).toList();
    }
    return [];
  }
  
  Future<File?> _pickAudioFromFiles(BuildContext context) async {
    final result = await FileManager.show(
      context: context,
      mediaType: FileMediaType.audio,
      allowMultiple: false,
      maxSelection: 1,
      title: 'Select Audio',
    );
    
    if (result != null && result.isNotEmpty) {
      return File(result.first.path);
    }
    return null;
  }
  
  Future<List<File>> _pickImagesFromFiles(BuildContext context, {int? maxCount}) async {
    final result = await FileManager.show(
      context: context,
      mediaType: FileMediaType.image,
      allowMultiple: true,
      maxSelection: maxCount ?? 20,
      title: 'Select Photos',
    );
    
    if (result != null && result.isNotEmpty) {
      return result.map((f) => File(f.path)).toList();
    }
    return [];
  }
  
  Future<File?> _pickImageFromFiles(BuildContext context) async {
    final result = await FileManager.show(
      context: context,
      mediaType: FileMediaType.image,
      allowMultiple: false,
      maxSelection: 1,
      title: 'Select Photo',
    );
    
    if (result != null && result.isNotEmpty) {
      return File(result.first.path);
    }
    return null;
  }
  
  // ============ Gallery Picker Methods (MediaPicker) ============
  
  Future<File?> _pickVideoFromGallery(BuildContext context) async {
    final result = await MediaPicker.show(
      context: context,
      mediaType: MediaType.video,
      allowMultiple: false,
      maxSelection: 1,
      title: 'Select Video',
    );
    
    if (result != null && result.isNotEmpty && result.first.path != null) {
      return File(result.first.path!);
    }
    return null;
  }
  
  Future<List<File>> _pickVideosFromGallery(BuildContext context, {int? maxCount}) async {
    final result = await MediaPicker.show(
      context: context,
      mediaType: MediaType.video,
      allowMultiple: true,
      maxSelection: maxCount ?? 10,
      title: 'Select Videos',
    );
    
    if (result != null && result.isNotEmpty) {
      return result
          .where((m) => m.path != null)
          .map((m) => File(m.path!))
          .toList();
    }
    return [];
  }
  
  Future<List<File>> _pickImagesFromGallery(BuildContext context, {int? maxCount}) async {
    final result = await MediaPicker.show(
      context: context,
      mediaType: MediaType.image,
      allowMultiple: true,
      maxSelection: maxCount ?? 20,
      title: 'Select Photos',
    );
    
    if (result != null && result.isNotEmpty) {
      return result
          .where((m) => m.path != null)
          .map((m) => File(m.path!))
          .toList();
    }
    return [];
  }
  
  Future<File?> _pickAudioFromGallery(BuildContext context) async {
    final result = await MediaPicker.show(
      context: context,
      mediaType: MediaType.audio,
      allowMultiple: false,
      maxSelection: 1,
      title: 'Select Audio',
    );
    
    if (result != null && result.isNotEmpty && result.first.path != null) {
      return File(result.first.path!);
    }
    return null;
  }
}
