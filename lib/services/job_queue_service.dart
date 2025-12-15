import 'dart:async';
import 'dart:collection';
import 'file_picker_service.dart';

/// A queued job that waits for execution
class QueuedJob {
  final String id;
  final Future<void> Function() execute;
  final Completer<void> completer;

  QueuedJob({
    required this.id,
    required this.execute,
  }) : completer = Completer<void>();
}

/// Service to manage job queue with concurrent execution limit
class JobQueueService {
  static final JobQueueService _instance = JobQueueService._internal();
  factory JobQueueService() => _instance;
  JobQueueService._internal();

  final Queue<QueuedJob> _queue = Queue<QueuedJob>();
  int _runningJobs = 0;
  FilePickerService? _pickerService;

  /// Initialize with FilePickerService to get max concurrent jobs setting
  void init(FilePickerService pickerService) {
    _pickerService = pickerService;
  }

  int get _maxConcurrentJobs => _pickerService?.maxConcurrentJobs ?? 1;
  int get runningJobs => _runningJobs;
  int get queuedJobs => _queue.length;

  /// Add a job to the queue and execute when slot is available
  Future<void> enqueue(String jobId, Future<void> Function() execute) async {
    final queuedJob = QueuedJob(id: jobId, execute: execute);
    _queue.add(queuedJob);
    _processQueue();
    return queuedJob.completer.future;
  }

  /// Process the queue - start jobs if slots are available
  void _processQueue() {
    while (_runningJobs < _maxConcurrentJobs && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _runJob(job);
    }
  }

  /// Run a single job
  Future<void> _runJob(QueuedJob job) async {
    _runningJobs++;
    try {
      await job.execute();
      job.completer.complete();
    } catch (e) {
      job.completer.completeError(e);
    } finally {
      _runningJobs--;
      _processQueue(); // Check if more jobs can be started
    }
  }

  /// Cancel a queued job (not yet running)
  bool cancelQueued(String jobId) {
    final job = _queue.firstWhere(
      (j) => j.id == jobId,
      orElse: () => QueuedJob(id: '', execute: () async {}),
    );
    if (job.id.isNotEmpty) {
      _queue.remove(job);
      job.completer.completeError('Job cancelled');
      return true;
    }
    return false;
  }
}

