import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../models/video_info.dart';

class FFprobeService {
  /// Analyze a video file and return its metadata
  static Future<VideoInfo?> analyzeVideo(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();

      if (info == null) {
        return null;
      }

      int? width;
      int? height;
      int? videoBitrate;
      bool hasAudio = false;
      int? audioBitrate;
      String? videoCodec;
      String? audioCodec;

      final streams = info.getStreams();
      for (final stream in streams) {
        final codecType = stream.getType();

        if (codecType == 'video') {
          width = stream.getWidth();
          height = stream.getHeight();
          videoCodec = stream.getCodec();
          final bitrate = stream.getBitrate();
          if (bitrate != null) {
            videoBitrate = int.tryParse(bitrate);
            if (videoBitrate != null) {
              videoBitrate = videoBitrate ~/ 1000; // Convert to kbps
            }
          }
        } else if (codecType == 'audio') {
          hasAudio = true;
          audioCodec = stream.getCodec();
          final bitrate = stream.getBitrate();
          if (bitrate != null) {
            audioBitrate = int.tryParse(bitrate);
            if (audioBitrate != null) {
              audioBitrate = audioBitrate ~/ 1000; // Convert to kbps
            }
          }
        }
      }

      // Get duration from format
      double? duration;
      final durationStr = info.getDuration();
      if (durationStr != null) {
        duration = double.tryParse(durationStr);
      }

      // Get overall bitrate if video bitrate not available
      if (videoBitrate == null) {
        final formatBitrate = info.getBitrate();
        if (formatBitrate != null) {
          videoBitrate = int.tryParse(formatBitrate);
          if (videoBitrate != null) {
            videoBitrate = videoBitrate ~/ 1000;
          }
        }
      }

      // Get file size
      int? fileSize;
      final file = File(filePath);
      if (await file.exists()) {
        fileSize = await file.length();
      }

      return VideoInfo(
        width: width,
        height: height,
        videoBitrate: videoBitrate,
        hasAudio: hasAudio,
        audioBitrate: audioBitrate,
        duration: duration,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        fileSize: fileSize,
      );
    } catch (e) {
      print('Error analyzing video: $e');
      return null;
    }
  }

  /// Get video duration in seconds
  static Future<double?> getVideoDuration(String filePath) async {
    final info = await analyzeVideo(filePath);
    return info?.duration;
  }

  /// Check if video has audio stream
  static Future<bool> hasAudioStream(String filePath) async {
    final info = await analyzeVideo(filePath);
    return info?.hasAudio ?? false;
  }

  /// Get audio duration
  static Future<double?> getAudioDuration(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();

      if (info == null) return null;

      final durationStr = info.getDuration();
      if (durationStr != null) {
        return double.tryParse(durationStr);
      }
      return null;
    } catch (e) {
      print('Error getting audio duration: $e');
      return null;
    }
  }
}

