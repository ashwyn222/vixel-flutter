import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to detect and manage hardware acceleration support
class HardwareAccelerationService {
  static const String _prefsKey = 'hardware_acceleration_supported';
  static const String _probeCompletedKey = 'hardware_probe_completed';
  
  static bool _isSupported = false;
  static bool _probeCompleted = false;
  
  /// Whether hardware acceleration is supported on this device
  static bool get isSupported => _isSupported;
  
  /// Whether the probe has been completed
  static bool get probeCompleted => _probeCompleted;
  
  /// Get the appropriate video encoder based on hardware support
  static String get videoEncoder => _isSupported ? 'h264_mediacodec' : 'libx264';
  
  /// Initialize the service - loads cached result or runs probe
  static Future<void> init() async {
    // Only run on Android - iOS/macOS use different hardware encoders
    if (!Platform.isAndroid) {
      _isSupported = false;
      _probeCompleted = true;
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _probeCompleted = prefs.getBool(_probeCompletedKey) ?? false;
      
      if (_probeCompleted) {
        // Use cached result
        _isSupported = prefs.getBool(_prefsKey) ?? false;
        _log('Using cached hardware acceleration result: $_isSupported');
      } else {
        // Run probe on first launch
        _log('Running hardware acceleration probe...');
        await _runProbe();
        
        // Save results
        await prefs.setBool(_prefsKey, _isSupported);
        await prefs.setBool(_probeCompletedKey, true);
        _probeCompleted = true;
        _log('Probe completed. Hardware acceleration supported: $_isSupported');
      }
    } catch (e) {
      _log('Error during hardware acceleration detection: $e');
      _isSupported = false;
      _probeCompleted = true;
    }
  }
  
  /// Run a quick probe to test hardware encoder
  static Future<void> _runProbe() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final testInput = '${tempDir.path}/hw_probe_input.mp4';
      final testOutput = '${tempDir.path}/hw_probe_output.mp4';
      
      // Step 1: Create a tiny test video using software encoder (guaranteed to work)
      // Generate a 1-second black video
      final createCmd = '-f lavfi -i color=black:s=320x240:d=1 -c:v libx264 -t 1 -y $testInput';
      
      _log('Creating test video...');
      final createSession = await FFmpegKit.execute(createCmd);
      final createReturnCode = await createSession.getReturnCode();
      
      if (!ReturnCode.isSuccess(createReturnCode)) {
        _log('Failed to create test video');
        _isSupported = false;
        return;
      }
      
      // Step 2: Try to encode with hardware acceleration
      final hwCmd = '-i $testInput -c:v h264_mediacodec -t 1 -y $testOutput';
      
      _log('Testing hardware encoder (h264_mediacodec)...');
      final hwSession = await FFmpegKit.execute(hwCmd);
      final hwReturnCode = await hwSession.getReturnCode();
      
      _isSupported = ReturnCode.isSuccess(hwReturnCode);
      
      // Cleanup test files
      try {
        final inputFile = File(testInput);
        final outputFile = File(testOutput);
        if (await inputFile.exists()) await inputFile.delete();
        if (await outputFile.exists()) await outputFile.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
      
    } catch (e) {
      _log('Probe error: $e');
      _isSupported = false;
    }
  }
  
  /// Force re-run the probe (useful if user wants to retest)
  static Future<void> rerunProbe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_probeCompletedKey);
    await prefs.remove(_prefsKey);
    _probeCompleted = false;
    await init();
  }
  
  static void _log(String message) {
    // ignore: avoid_print
    print('[HardwareAcceleration] $message');
  }
}

