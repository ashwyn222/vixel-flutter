import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/job.dart';
import 'notification_service.dart';
import 'review_service.dart';
import 'operation_tracker_service.dart';
import 'logging_service.dart';

class JobService extends ChangeNotifier {
  static const String _storageKey = 'vixel_jobs';
  final List<Job> _jobs = [];
  final Uuid _uuid = const Uuid();
  OperationTrackerService? _operationTrackerService;

  List<Job> get jobs => List.unmodifiable(_jobs);
  
  List<Job> get activeJobs => _jobs
      .where((j) => j.status == JobStatus.pending || j.status == JobStatus.processing)
      .toList();
  
  List<Job> get completedJobs => _jobs
      .where((j) => j.status == JobStatus.completed)
      .toList();
  
  List<Job> get failedJobs => _jobs
      .where((j) => j.status == JobStatus.failed)
      .toList();

  int get totalJobs => _jobs.length;
  int get activeJobCount => activeJobs.length;
  int get completedJobCount => completedJobs.length;

  /// Initialize and load jobs from storage
  Future<void> init({OperationTrackerService? operationTrackerService}) async {
    _operationTrackerService = operationTrackerService;
    await _loadJobs();
  }

  /// Load jobs from SharedPreferences
  Future<void> _loadJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final loadedJobs = Job.decodeJobs(jsonStr);
        _jobs.clear();
        _jobs.addAll(loadedJobs);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading jobs: $e');
    }
  }

  /// Save jobs to SharedPreferences
  Future<void> _saveJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = Job.encodeJobs(_jobs);
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      print('Error saving jobs: $e');
    }
  }

  /// Create a new job
  Job createJob({
    required JobType type,
    required String filename,
    String? outputFilename,
    String? outputPath,
    int? inputSize,
    Map<String, dynamic> settings = const {},
  }) {
    final job = Job(
      id: _uuid.v4(),
      type: type,
      filename: filename,
      outputFilename: outputFilename,
      outputPath: outputPath,
      inputSize: inputSize,
      createdAt: DateTime.now(),
      settings: settings,
    );
    
    _jobs.insert(0, job); // Add to beginning
    _saveJobs();
    notifyListeners();
    return job;
  }

  /// Get job by ID
  Job? getJob(String id) {
    try {
      return _jobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Update job status
  void updateJobStatus(String id, JobStatus status) {
    final job = getJob(id);
    if (job != null) {
      job.status = status;
      if (status == JobStatus.completed) {
        job.completedAt = DateTime.now();
      }
      _saveJobs();
      notifyListeners();
    }
  }

  /// Update job progress
  void updateJobProgress(String id, int progress) {
    final job = getJob(id);
    if (job != null) {
      job.progress = progress.clamp(0, 100);
      notifyListeners();
    }
  }

  /// Update job output info
  void updateJobOutput(String id, {
    String? outputPath,
    int? outputSize,
    double? savingsPercent,
  }) {
    final job = getJob(id);
    if (job != null) {
      if (outputSize != null) job.outputSize = outputSize;
      if (savingsPercent != null) job.savingsPercent = savingsPercent;
      _saveJobs();
      notifyListeners();
    }
  }

  /// Mark job as failed
  void markJobFailed(String id, String error) {
    final job = getJob(id);
    if (job != null) {
      job.status = JobStatus.failed;
      job.error = error;
      _saveJobs();
      notifyListeners();
      
      // Send failure notification
      NotificationService.showJobFailedNotification(job);
      
      // Log error to Firestore as fallback (in case operation screen didn't log it)
      // This ensures we capture all failures even if logging in operation screens fails
      LoggingService().logError(
        'Job failed: ${job.type.name}',
        error: error,
        operation: _getOperationName(job.type),
        context: {
          'jobId': id,
          'jobType': job.type.name,
          'filename': job.filename,
        },
      );
    }
  }

  /// Get operation name from job type
  String _getOperationName(JobType type) {
    switch (type) {
      case JobType.compress:
        return 'optimize_video';
      case JobType.cut:
        return 'cut_video';
      case JobType.merge:
        return 'merge_videos';
      case JobType.extractAudio:
        return 'extract_audio';
      case JobType.audioOnVideo:
        return 'audio_on_video';
      case JobType.photosToVideo:
        return 'photos_to_video';
      case JobType.addWatermark:
        return 'add_watermark';
    }
  }

  /// Mark job as completed
  void markJobCompleted(String id, {int? outputSize, double? savingsPercent}) {
    final job = getJob(id);
    if (job != null) {
      job.status = JobStatus.completed;
      job.progress = 100;
      job.completedAt = DateTime.now();
      if (outputSize != null) job.outputSize = outputSize;
      if (savingsPercent != null) job.savingsPercent = savingsPercent;
      _saveJobs();
      notifyListeners();
      
      // Send success notification
      NotificationService.showJobCompletedNotification(job);
      
      // Record successful operation for quota tracking (only on success)
      _operationTrackerService?.recordOperation();
      
      // Record successful operation for review prompt
      ReviewService().recordSuccessfulOperation();
    }
  }

  /// Cancel a job
  void cancelJob(String id) {
    final job = getJob(id);
    if (job != null && 
        (job.status == JobStatus.pending || job.status == JobStatus.processing)) {
      job.status = JobStatus.cancelled;
      job.cancelled = true;
      _saveJobs();
      notifyListeners();
    }
  }

  /// Delete a job
  void deleteJob(String id) {
    _jobs.removeWhere((j) => j.id == id);
    _saveJobs();
    notifyListeners();
  }

  /// Clear all jobs
  void clearAllJobs() {
    _jobs.clear();
    _saveJobs();
    notifyListeners();
  }

  /// Clear completed jobs
  void clearCompletedJobs() {
    _jobs.removeWhere((j) => j.status == JobStatus.completed);
    _saveJobs();
    notifyListeners();
  }

  /// Clear failed jobs
  void clearFailedJobs() {
    _jobs.removeWhere((j) => j.status == JobStatus.failed);
    _saveJobs();
    notifyListeners();
  }
}

