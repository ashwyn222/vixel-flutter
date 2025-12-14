class VideoInfo {
  final int? width;
  final int? height;
  final int? videoBitrate; // in kbps
  final bool hasAudio;
  final int? audioBitrate; // in kbps
  final double? duration; // in seconds
  final String? videoCodec;
  final String? audioCodec;
  final int? fileSize; // in bytes

  VideoInfo({
    this.width,
    this.height,
    this.videoBitrate,
    this.hasAudio = false,
    this.audioBitrate,
    this.duration,
    this.videoCodec,
    this.audioCodec,
    this.fileSize,
  });

  String get resolution {
    if (width != null && height != null) {
      return '${width}x$height';
    }
    return 'Unknown';
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final d = Duration(milliseconds: (duration! * 1000).round());
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() {
    return 'VideoInfo(resolution: $resolution, duration: $durationFormatted, '
        'videoBitrate: ${videoBitrate}kbps, hasAudio: $hasAudio, '
        'audioBitrate: ${audioBitrate}kbps, videoCodec: $videoCodec, '
        'audioCodec: $audioCodec, fileSize: $fileSizeFormatted)';
  }
}

