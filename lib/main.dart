import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'services/job_service.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/file_picker_service.dart';
import 'services/hardware_acceleration_service.dart';
import 'services/job_queue_service.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

// Global log file for debugging
File? _logFile;

Future<void> _writeLog(String message) async {
  try {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message\n';
    
    if (_logFile != null) {
      await _logFile!.writeAsString(logMessage, mode: FileMode.append);
    }
  } catch (e) {
    // Ignore log errors
  }
}

void main() async {
  // Wrap everything in error handling
  FlutterError.onError = (details) async {
    await _writeLog('FLUTTER ERROR: ${details.exception}\n${details.stack}');
  };
  
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Hide overflow error indicators (yellow/black stripes)
    // This handles cases where users have large font accessibility settings
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Return an empty widget instead of the error widget
      return const SizedBox.shrink();
    };
    
    await _writeLog('App starting...');
    
    // Initialize log file in Downloads folder (accessible via file manager)
    try {
      if (Platform.isAndroid) {
        // Use external storage Downloads folder
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          _logFile = File('${dir.path}/vixel_debug_log.txt');
          await _logFile!.writeAsString('=== Vixel Debug Log ===\nStarted: ${DateTime.now()}\n\n');
          await _writeLog('Log file initialized at: ${_logFile!.path}');
        }
      }
    } catch (e) {
      // Try app documents directory as fallback
      try {
        final dir = await getApplicationDocumentsDirectory();
        _logFile = File('${dir.path}/vixel_debug_log.txt');
        await _logFile!.writeAsString('=== Vixel Debug Log ===\nStarted: ${DateTime.now()}\n\n');
      } catch (e2) {
        // Ignore
      }
    }
    
    await _writeLog('Setting system UI overlay style...');

    await _writeLog('Requesting permissions on Android...');
    
    // Request permissions on Android
    if (Platform.isAndroid) {
      await _requestPermissions();
    }

    await _writeLog('Initializing storage...');
    
    // Initialize storage
    await StorageService.init();

    await _writeLog('Initializing job service...');
    
    // Initialize job service
    final jobService = JobService();
    await jobService.init();

    await _writeLog('Initializing theme...');
    
    // Initialize theme
    final appTheme = AppTheme();
    appTheme.updateActiveTheme();

    await _writeLog('Initializing localizations...');
    
    // Initialize localizations
    final appLocalizations = AppLocalizations();

    await _writeLog('Initializing file picker service...');
    
    // Initialize file picker service
    final filePickerService = FilePickerService();

    await _writeLog('Initializing job queue service...');
    
    // Initialize job queue service with file picker for concurrent jobs setting
    JobQueueService().init(filePickerService);

    await _writeLog('Detecting hardware acceleration support...');
    
    // Detect hardware acceleration support (runs probe on first launch)
    await HardwareAccelerationService.init();
    await _writeLog('Hardware acceleration: ${HardwareAccelerationService.isSupported ? "SUPPORTED" : "NOT SUPPORTED"}');

    await _writeLog('Initializing notifications...');
    
    // Initialize notification service
    await NotificationService.init();
    await NotificationService.requestPermissions();

    await _writeLog('Starting app UI...');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: jobService),
          ChangeNotifierProvider.value(value: appTheme),
          ChangeNotifierProvider.value(value: appLocalizations),
          ChangeNotifierProvider.value(value: filePickerService),
        ],
        child: const VixelApp(),
      ),
    );
    
    await _writeLog('App UI started successfully!');
  }, (error, stack) async {
    await _writeLog('ZONE ERROR: $error\n$stack');
  });
}

Future<void> _requestPermissions() async {
  await _writeLog('Starting permission requests...');
  
  // For Android 13+ (API 33+), we need specific media permissions
  // For older versions, we need storage permissions
  
  final permissions = <Permission>[
    Permission.videos,
    Permission.audio,
    Permission.photos,
  ];

  // Request all permissions
  for (final permission in permissions) {
    try {
      final status = await permission.status;
      await _writeLog('Permission $permission status: $status');
      if (!status.isGranted) {
        final result = await permission.request();
        await _writeLog('Permission $permission request result: $result');
      }
    } catch (e) {
      await _writeLog('Permission $permission error: $e');
    }
  }
  
  await _writeLog('Permission requests completed');
}

class VixelApp extends StatelessWidget {
  const VixelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppTheme>(
      builder: (context, appTheme, child) {
        // Update static theme reference
        appTheme.updateActiveTheme();
        
        // Update system UI based on theme
        final isDark = appTheme.currentThemeData.isDark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: appTheme.currentThemeData.background,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));
        
        return MaterialApp(
          title: 'Vixel',
          debugShowCheckedModeBanner: false,
          theme: appTheme.themeData,
          home: const HomeScreen(),
        );
      },
    );
  }
}
