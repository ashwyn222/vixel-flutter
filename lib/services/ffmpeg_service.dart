import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'hardware_acceleration_service.dart';
import 'job_queue_service.dart';

typedef ProgressCallback = void Function(int progress, Statistics? stats);

/// Get the appropriate video encoder (hardware or software)
String get _videoEncoder => HardwareAccelerationService.videoEncoder;

/// Helper to write FFmpeg logs to a file for debugging
Future<void> _writeToLogFile(String message) async {
  try {
    if (Platform.isAndroid) {
      final logFile = File('/storage/emulated/0/Download/vixel_ffmpeg_log.txt');
      final timestamp = DateTime.now().toIso8601String();
      await logFile.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
    }
  } catch (e) {
    // Ignore log errors
  }
}

class FFmpegService {
  /// Compress video with specified settings
  /// Direct port from Python server's /compress endpoint
  static Future<FFmpegResult> compressVideo({
    required String inputPath,
    required String outputPath,
    required String resolution, // e.g., "1280:-1" or "-1:-1" for original
    required String videoBitrate, // e.g., "1000k"
    required String audioBitrate, // e.g., "128k"
    required String preset, // e.g., "fast", "medium", "slow"
    bool removeAudio = false,
    double? duration,
    ProgressCallback? onProgress,
  }) async {
    final args = <String>['-i', inputPath];

    // Video codec (hardware or software based on device support)
    args.addAll(['-c:v', _videoEncoder]);

    // Resolution scaling
    if (resolution.isNotEmpty && resolution != '-1:-1') {
      args.addAll(['-vf', 'scale=$resolution']);
    }

    // Video bitrate (only if specified)
    if (videoBitrate.isNotEmpty) {
      args.addAll(['-b:v', videoBitrate]);
    }

    // Preset
    args.addAll(['-preset', preset]);

    // Audio handling
    if (removeAudio) {
      args.add('-an');
    } else {
      args.addAll(['-c:a', 'aac']);
      if (audioBitrate.isNotEmpty) {
        args.addAll(['-b:a', audioBitrate]);
      }
    }

    // Overwrite output
    args.addAll(['-y', outputPath]);

    return _executeWithProgress(
      args: args,
      duration: duration,
      onProgress: onProgress,
    );
  }

  /// Cut/trim video
  /// Direct port from Python server's /cut-video endpoint
  static Future<FFmpegResult> cutVideo({
    required String inputPath,
    required String outputPath,
    required double startTime,
    required double endTime,
    ProgressCallback? onProgress,
  }) async {
    final args = <String>[
      '-i', inputPath,
      '-ss', startTime.toString(),
      '-to', endTime.toString(),
      '-c', 'copy',
      '-avoid_negative_ts', '1',
      '-y', outputPath,
    ];

    return _executeWithProgress(
      args: args,
      duration: endTime - startTime,
      onProgress: onProgress,
    );
  }

  /// Merge multiple videos
  /// Direct port from Python server's /merge-videos endpoint
  static Future<FFmpegResult> mergeVideos({
    required List<String> inputPaths,
    required String outputPath,
    required String resolution, // e.g., "1280x720" or "-1:-1"
    required String videoBitrate,
    required String audioBitrate,
    required String preset,
    double? totalDuration,
    ProgressCallback? onProgress,
  }) async {
    final args = <String>[];
    final scaleFilters = <String>[];
    final concatStreams = <String>[];

    // Add input files
    for (int i = 0; i < inputPaths.length; i++) {
      args.addAll(['-i', inputPaths[i]]);

      // Scale each input if resolution specified
      if (resolution != '-1:-1' && resolution.isNotEmpty) {
        // Parse resolution
        final parts = resolution.split('x');
        final width = parts[0];
        final height = parts[1];
        
        // Scale with force_original_aspect_ratio and pad to handle different aspect ratios
        // This ensures all videos have exactly the same dimensions
        scaleFilters.add(
          '[$i:v]scale=$width:$height:force_original_aspect_ratio=decrease,'
          'pad=$width:$height:(ow-iw)/2:(oh-ih)/2:black,'
          'setsar=1[v$i]'
        );
        concatStreams.add('[v$i][$i:a]');
      } else {
        concatStreams.add('[$i:v][$i:a]');
      }
    }

    // Build filter_complex
    String filterComplex = '';
    if (resolution != '-1:-1' && resolution.isNotEmpty) {
      filterComplex = '${scaleFilters.join(';')};';
    }
    filterComplex += '${concatStreams.join('')}concat=n=${inputPaths.length}:v=1:a=1[outv][outa]';

    args.addAll(['-filter_complex', filterComplex]);
    args.addAll(['-map', '[outv]', '-map', '[outa]']);
    args.addAll(['-preset', preset]);

    if (audioBitrate.isNotEmpty) {
      args.addAll(['-b:a', audioBitrate]);
    }
    args.addAll(['-b:v', videoBitrate]);
    args.addAll(['-y', outputPath]);

    return _executeWithProgress(
      args: args,
      duration: totalDuration,
      onProgress: onProgress,
    );
  }

  /// Extract audio from video
  /// Direct port from Python server's /extract-audio endpoint
  static Future<FFmpegResult> extractAudio({
    required String inputPath,
    required String outputPath,
    required String format, // e.g., "mp3", "aac"
    required String bitrate, // e.g., "128k"
    ProgressCallback? onProgress,
  }) async {
    final args = <String>[
      '-i', inputPath,
      '-vn', // No video
      '-b:a', bitrate,
      '-y', outputPath,
    ];

    return _executeWithProgress(
      args: args,
      onProgress: onProgress,
    );
  }

  /// Add/mix audio on video
  /// Direct port from Python server's /audio-on-video endpoint
  static Future<FFmpegResult> audioOnVideo({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    required double originalVolume, // 0.0 to 1.0
    required double newAudioVolume, // 0.0 to 1.0
    required double videoDuration,
    required double audioDuration,
    required bool videoHasAudio,
    ProgressCallback? onProgress,
  }) async {
    final args = <String>['-y'];
    
    // If audio is shorter than video, we need to loop it
    // Use -stream_loop to loop the audio input
    if (audioDuration > 0 && audioDuration < videoDuration) {
      // Calculate how many times to loop (round up)
      final loopCount = (videoDuration / audioDuration).ceil();
      args.addAll(['-i', videoPath, '-stream_loop', '${loopCount - 1}', '-i', audioPath]);
    } else {
      args.addAll(['-i', videoPath, '-i', audioPath]);
    }

    String filterComplex;

    if (videoHasAudio) {
      // Video has audio - mix both tracks
      // Trim new audio to video duration (after looping if needed)
      final audioFilter = '[1:a]volume=$newAudioVolume,atrim=0:$videoDuration,asetpts=PTS-STARTPTS[a1]';
      filterComplex = '$audioFilter;[0:a]volume=$originalVolume[a0];[a0][a1]amix=inputs=2:duration=first:dropout_transition=0[aout]';

      args.addAll([
        '-filter_complex', filterComplex,
        '-map', '0:v',
        '-map', '[aout]',
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-shortest',
        outputPath,
      ]);
    } else {
      // Video has no audio - just add the new audio track
      // Trim to video duration (after looping if needed)
      final audioFilter = '[1:a]volume=$newAudioVolume,atrim=0:$videoDuration,asetpts=PTS-STARTPTS[aout]';

      args.addAll([
        '-filter_complex', audioFilter,
        '-map', '0:v',
        '-map', '[aout]',
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-shortest',
        outputPath,
      ]);
    }

    return _executeWithProgress(
      args: args,
      duration: videoDuration,
      onProgress: onProgress,
    );
  }

  /// Create video from photos with transitions using xfade filter
  /// Direct port from Python server's /photos-to-video endpoint
  static Future<FFmpegResult> photosToVideo({
    required List<String> imagePaths,
    required List<double> durations, // Duration for each image
    required List<String> transitions, // Transition effect between images
    String? audioPath,
    required String outputPath,
    ProgressCallback? onProgress,
  }) async {
    final targetWidth = 1280;
    final targetHeight = 720;
    const double transitionDuration = 1.0; // 1 second transition (same as Python)
    
    // Ensure minimum duration of 2 seconds (same as Python)
    final adjustedDurations = durations.map((d) => d < 2.0 ? 2.0 : d).toList();
    
    // Calculate total output duration
    double totalDuration = 0;
    for (final d in adjustedDurations) {
      totalDuration += d;
    }
    // Subtract transition overlaps
    if (imagePaths.length > 1) {
      totalDuration -= (imagePaths.length - 1) * transitionDuration;
    }

    final args = <String>['-y', '-hide_banner'];
    
    if (imagePaths.length == 1) {
      // Single image - no transitions needed (same as Python)
      args.addAll([
        '-loop', '1',
        '-t', adjustedDurations[0].toString(),
        '-i', imagePaths[0],
        '-vf', 'scale=$targetWidth:-2,format=yuv420p',
        '-c:v', _videoEncoder,
        '-preset', 'medium',
        outputPath,
      ]);
      
      return await _executeWithProgress(
        args: args,
        onProgress: onProgress,
        duration: totalDuration,
      );
    }
    
    // Multiple images - use xfade transitions (same as Python)
    // Each input needs extra duration to cover the transition overlap
    for (int i = 0; i < imagePaths.length; i++) {
      // Add transition_duration to all inputs except the last one
      final inputDuration = i < imagePaths.length - 1 
          ? adjustedDurations[i] + transitionDuration 
          : adjustedDurations[i];
      args.addAll(['-loop', '1', '-t', inputDuration.toString(), '-i', imagePaths[i]]);
    }
    
    // Build filter_complex for xfade transitions (same as Python)
    final filterParts = <String>[];
    
    // Scale and pad all inputs to the same dimensions (1280x720)
    for (int i = 0; i < imagePaths.length; i++) {
      filterParts.add(
        '[$i:v]scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,'
        'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:black,'
        'format=yuv420p,setsar=1[v$i]'
      );
    }
    
    // Build xfade chain with individual transitions (same as Python)
    // First transition: starts at (duration[0] - transition_duration) into v0
    final firstTransition = transitions.isNotEmpty ? transitions[0] : 'fade';
    final firstOffset = adjustedDurations[0] - transitionDuration;
    filterParts.add('[v0][v1]xfade=transition=$firstTransition:duration=$transitionDuration:offset=$firstOffset[vtmp0]');
    
    // For subsequent transitions, offset is relative to the previous output
    for (int i = 1; i < imagePaths.length - 1; i++) {
      final prevLabel = 'vtmp${i - 1}';
      final currLabel = 'vtmp$i';
      
      // Calculate the length of the previous output stream
      // After i transitions, output length = sum(durations[0:i+1]) - i * transition_duration
      double prevOutputLength = 0;
      for (int j = 0; j <= i; j++) {
        prevOutputLength += adjustedDurations[j];
      }
      prevOutputLength -= i * transitionDuration;
      // Transition starts at (prev_output_length - transition_duration)
      final offset = prevOutputLength - transitionDuration;
      
      final currentTransition = transitions.length > i ? transitions[i] : 'fade';
      filterParts.add('[$prevLabel][v${i + 1}]xfade=transition=$currentTransition:duration=$transitionDuration:offset=$offset[$currLabel]');
    }
    
    final filterComplex = filterParts.join(';');
    final finalLabel = 'vtmp${imagePaths.length - 2}';
    
    // Add audio handling if audio is provided
    if (audioPath != null && audioPath.isNotEmpty) {
      // Add audio input
      args.addAll(['-i', audioPath]);
      
      args.addAll([
        '-filter_complex', filterComplex,
        '-map', '[$finalLabel]',
        '-map', '${imagePaths.length}:a',
        '-c:v', _videoEncoder,
        '-pix_fmt', 'yuv420p', // Force yuv420p for compatibility
        '-preset', 'fast',
        '-crf', '23',
        '-c:a', 'aac',
        '-shortest',
        outputPath,
      ]);
    } else {
      // No audio - just video
      args.addAll([
        '-filter_complex', filterComplex,
        '-map', '[$finalLabel]',
        '-c:v', _videoEncoder,
        '-pix_fmt', 'yuv420p', // Force yuv420p for compatibility
        '-preset', 'fast',
        '-crf', '23',
        outputPath,
      ]);
    }

    return await _executeWithProgress(
      args: args, 
      onProgress: onProgress,
      duration: totalDuration,
    );
  }

  /// Add watermark to video
  /// Direct port from Python server's /add-watermark endpoint
  static Future<FFmpegResult> addWatermark({
    required String videoPath,
    required String outputPath,
    required String watermarkType, // 'image' or 'text'
    required String positionMode, // 'preset' or 'custom'
    required String position, // 'top-left', 'top-right', 'bottom-left', 'bottom-right', 'center'
    double customX = 10,
    double customY = 10,
    required double opacity, // 0.0 to 1.0
    String? watermarkImagePath,
    String? watermarkText,
    double scale = 0.2, // For image watermark
    String durationType = 'full', // 'full' or 'custom'
    double startTime = 0,
    double endTime = 0,
    double? duration, // Video duration for progress calculation
    ProgressCallback? onProgress,
  }) async {
    final args = <String>['-y', '-i', videoPath];

    String x, y;

    if (watermarkType == 'image' && watermarkImagePath != null) {
      args.addAll(['-i', watermarkImagePath]);

      // Calculate position
      if (positionMode == 'custom') {
        x = customX.toString();
        y = customY.toString();
      } else {
        switch (position) {
          case 'top-left':
            x = '10';
            y = '10';
            break;
          case 'top-right':
            x = 'W-w-10';
            y = '10';
            break;
          case 'bottom-left':
            x = '10';
            y = 'H-h-10';
            break;
          case 'bottom-right':
            x = 'W-w-10';
            y = 'H-h-10';
            break;
          case 'center':
            x = '(W-w)/2';
            y = '(H-h)/2';
            break;
          default:
            x = 'W-w-10';
            y = 'H-h-10';
        }
      }

      // Build overlay filter
      String overlayFilter;
      
      if (durationType == 'custom') {
        // For custom range, use enable parameter with proper escaping
        // Format: enable='between(t,start,end)'
        final startInt = startTime.toInt();
        final endInt = endTime.toInt();
        overlayFilter = '[1:v]scale=iw*$scale:-1,format=rgba,colorchannelmixer=aa=$opacity[wm];';
        overlayFilter += '[0:v][wm]overlay=$x:$y:enable=between(t\\,$startInt\\,$endInt)';
      } else {
        overlayFilter = '[1:v]scale=iw*$scale:-1,format=rgba,colorchannelmixer=aa=$opacity[wm];';
        overlayFilter += '[0:v][wm]overlay=$x:$y';
      }

      args.addAll([
        '-filter_complex', overlayFilter,
        '-c:a', 'copy',
        '-c:v', _videoEncoder,
        '-pix_fmt', 'yuv420p',
        '-preset', 'fast',
        '-crf', '23',
        outputPath,
      ]);
    } else {
      // Text watermark
      final text = watermarkText ?? 'Watermark';

      // Calculate position for text
      if (positionMode == 'custom') {
        x = customX.toString();
        y = customY.toString();
      } else {
        switch (position) {
          case 'top-left':
            x = '10';
            y = '10';
            break;
          case 'top-right':
            x = 'w-tw-10';
            y = '10';
            break;
          case 'bottom-left':
            x = '10';
            y = 'h-th-10';
            break;
          case 'bottom-right':
            x = 'w-tw-10';
            y = 'h-th-10';
            break;
          case 'center':
            x = '(w-tw)/2';
            y = '(h-th)/2';
            break;
          default:
            x = 'w-tw-10';
            y = 'h-th-10';
        }
      }

      // Escape text for FFmpeg - need to escape special characters
      final textEscaped = text
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll(':', '\\:');
      final borderOpacity = (opacity * 0.7).toStringAsFixed(2);

      // Use fontfile with Android system font for compatibility
      // On Android, we can use /system/fonts/Roboto-Regular.ttf or /system/fonts/DroidSans.ttf
      String drawtextFilter;
      
      if (durationType == 'custom') {
        // For custom range, use enable parameter with proper escaping
        final startInt = startTime.toInt();
        final endInt = endTime.toInt();
        drawtextFilter = "drawtext=fontfile=/system/fonts/Roboto-Regular.ttf:text='$textEscaped':x=$x:y=$y:fontsize=48:fontcolor=white@$opacity:borderw=2:bordercolor=black@$borderOpacity:enable=between(t\\,$startInt\\,$endInt)";
      } else {
        drawtextFilter = "drawtext=fontfile=/system/fonts/Roboto-Regular.ttf:text='$textEscaped':x=$x:y=$y:fontsize=48:fontcolor=white@$opacity:borderw=2:bordercolor=black@$borderOpacity";
      }

      args.addAll([
        '-vf', drawtextFilter,
        '-c:a', 'copy',
        '-c:v', _videoEncoder,
        '-pix_fmt', 'yuv420p',
        '-preset', 'fast',
        '-crf', '23',
        outputPath,
      ]);
    }

    return _executeWithProgress(
      args: args,
      duration: duration,
      onProgress: onProgress,
    );
  }

  /// Cancel running FFmpeg session
  static Future<void> cancelAll() async {
    await FFmpegKit.cancel();
  }

  /// Internal method to execute FFmpeg with progress tracking (non-blocking)
  /// Respects the concurrent jobs limit from settings
  static Future<FFmpegResult> _executeWithProgress({
    required List<String> args,
    double? duration,
    ProgressCallback? onProgress,
    String? jobId,
  }) async {
    final command = args.join(' ');
    // Debug logging
    print('========== FFMPEG DEBUG ==========');
    print('FFmpeg command: ffmpeg $command');
    print('===================================');
    
    // Write to log file for debugging
    await _writeToLogFile('FFMPEG COMMAND:\nffmpeg $command\n');

    // If a jobId is provided, use the queue system
    final queueService = JobQueueService();
    final effectiveJobId = jobId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Wrap the FFmpeg execution in a queued job
    final resultCompleter = Completer<FFmpegResult>();
    
    queueService.enqueue(effectiveJobId, () async {
      final result = await _executeFFmpegCommand(
        command: command,
        duration: duration,
        outputPath: args.last,
        onProgress: onProgress,
      );
      resultCompleter.complete(result);
    });
    
    return resultCompleter.future;
  }
  
  /// Actually execute the FFmpeg command (called by queue)
  static Future<FFmpegResult> _executeFFmpegCommand({
    required String command,
    required String outputPath,
    double? duration,
    ProgressCallback? onProgress,
  }) async {
    // Use a Completer to handle async completion
    final completer = Completer<FFmpegResult>();

    FFmpegKit.executeAsync(
      command,
      // Completion callback
      (session) async {
        final returnCode = await session.getReturnCode();
        final logs = await session.getAllLogsAsString();

        print('========== FFMPEG RESULT ==========');
        print('Return code: ${returnCode?.getValue()}');
        print('===================================');
        
        // Write full logs to file
        await _writeToLogFile('FFMPEG RETURN CODE: ${returnCode?.getValue()}\n');
        await _writeToLogFile('FFMPEG FULL LOGS:\n$logs\n');
        await _writeToLogFile('========== END FFMPEG ==========\n\n');

        if (ReturnCode.isSuccess(returnCode)) {
          completer.complete(FFmpegResult(
            success: true,
            outputPath: outputPath,
          ));
        } else {
          final errorMessage = _parseErrorMessage(logs);
          completer.complete(FFmpegResult(
            success: false,
            error: errorMessage,
          ));
        }
      },
      // Log callback
      (log) {
        // Uncomment for verbose logging
        // print('FFmpeg: ${log.getMessage()}');
      },
      // Statistics callback for progress
      (statistics) {
        if (onProgress != null && duration != null && duration > 0) {
          final time = statistics.getTime();
          if (time > 0) {
            final progress = ((time / 1000) / duration * 100).clamp(0, 100).toInt();
            onProgress(progress, statistics);
          }
        }
      },
    );

    return completer.future;
  }

  /// Parse FFmpeg logs to extract meaningful error message
  static String _parseErrorMessage(String? logs) {
    if (logs == null || logs.isEmpty) {
      return 'FFmpeg execution failed';
    }

    // Look for common error patterns
    final lines = logs.split('\n');
    final errorLines = <String>[];
    
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      // Skip configuration and version info
      if (line.contains('configuration:') || 
          line.contains('built with') ||
          line.contains('Copyright') ||
          line.contains('libav') ||
          line.contains('libsw') ||
          line.contains('libpost') ||
          line.startsWith('  ')) {
        continue;
      }
      
      // Capture error-related lines
      if (lowerLine.contains('error') ||
          lowerLine.contains('no such file') ||
          lowerLine.contains('permission denied') ||
          lowerLine.contains('invalid') ||
          lowerLine.contains('failed') ||
          lowerLine.contains('cannot') ||
          lowerLine.contains('unable')) {
        errorLines.add(line.trim());
      }
    }

    if (errorLines.isNotEmpty) {
      // Return the last few error lines (most relevant)
      final relevantErrors = errorLines.take(3).join('\n');
      return relevantErrors;
    }

    // If no specific error found, return a generic message
    return 'FFmpeg processing failed. Please check the input file and try again.';
  }
}

class FFmpegResult {
  final bool success;
  final String? outputPath;
  final String? error;

  FFmpegResult({
    required this.success,
    this.outputPath,
    this.error,
  });
}

