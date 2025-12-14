import 'dart:convert';

enum JobStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

enum JobType {
  compress,
  cut,
  merge,
  extractAudio,
  audioOnVideo,
  photosToVideo,
  addWatermark,
}

class Job {
  final String id;
  final JobType type;
  JobStatus status;
  int progress;
  final String filename;
  final String? outputFilename;
  final String? outputPath;
  final int? inputSize;
  int? outputSize;
  double? savingsPercent;
  final DateTime createdAt;
  DateTime? completedAt;
  String? error;
  final Map<String, dynamic> settings;
  bool cancelled;

  Job({
    required this.id,
    required this.type,
    this.status = JobStatus.pending,
    this.progress = 0,
    required this.filename,
    this.outputFilename,
    this.outputPath,
    this.inputSize,
    this.outputSize,
    this.savingsPercent,
    required this.createdAt,
    this.completedAt,
    this.error,
    this.settings = const {},
    this.cancelled = false,
  });

  String get typeDisplayName {
    switch (type) {
      case JobType.compress:
        return 'Compress';
      case JobType.cut:
        return 'Cut';
      case JobType.merge:
        return 'Merge';
      case JobType.extractAudio:
        return 'Extract Audio';
      case JobType.audioOnVideo:
        return 'Audio on Video';
      case JobType.photosToVideo:
        return 'Photos to Video';
      case JobType.addWatermark:
        return 'Add Watermark';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.processing:
        return 'Processing';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.failed:
        return 'Failed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'status': status.index,
      'progress': progress,
      'filename': filename,
      'outputFilename': outputFilename,
      'outputPath': outputPath,
      'inputSize': inputSize,
      'outputSize': outputSize,
      'savingsPercent': savingsPercent,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'error': error,
      'settings': settings,
      'cancelled': cancelled,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      type: JobType.values[json['type']],
      status: JobStatus.values[json['status']],
      progress: json['progress'] ?? 0,
      filename: json['filename'],
      outputFilename: json['outputFilename'],
      outputPath: json['outputPath'],
      inputSize: json['inputSize'],
      outputSize: json['outputSize'],
      savingsPercent: json['savingsPercent']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      error: json['error'],
      settings: json['settings'] ?? {},
      cancelled: json['cancelled'] ?? false,
    );
  }

  static String encodeJobs(List<Job> jobs) {
    return jsonEncode(jobs.map((j) => j.toJson()).toList());
  }

  static List<Job> decodeJobs(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((j) => Job.fromJson(j)).toList();
  }
}

