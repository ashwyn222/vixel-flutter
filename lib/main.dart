import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/job_service.dart';
import 'services/logging_service.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/file_picker_service.dart';
import 'services/hardware_acceleration_service.dart';
import 'services/job_queue_service.dart';
import 'services/subscription_service.dart';
import 'services/operation_tracker_service.dart';
import 'services/auth_service.dart';
import 'services/review_service.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hide overflow error indicators (yellow/black stripes)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const SizedBox.shrink();
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase init failed - continue without cloud features
    print('Firebase init failed: $e');
  }

  // Request permissions on Android
  if (Platform.isAndroid) {
    try {
      await _requestPermissions();
    } catch (e) {
      // Continue even if permissions fail
    }
  }

  // Initialize storage
  try {
    await StorageService.init();
  } catch (e) {
    // Storage init failed
  }

  // Initialize job service (will be initialized after operationTrackerService)
  final jobService = JobService();

  // Initialize theme
  final appTheme = AppTheme();
  try {
    appTheme.updateActiveTheme();
  } catch (e) {
    // Theme init failed
  }

  // Initialize localizations
  final appLocalizations = AppLocalizations();

  // Initialize file picker service
  final filePickerService = FilePickerService();

  // Initialize job queue service
  try {
    JobQueueService().init(filePickerService);
  } catch (e) {
    // Job queue init failed
  }

  // Initialize auth service
  final authService = AuthService();
  try {
    await authService.init();
  } catch (e) {
    // Auth service init failed
    print('Auth service init failed: $e');
  }

  // Initialize subscription service
  final subscriptionService = SubscriptionService();
  try {
    await subscriptionService.init();
  } catch (e) {
    // Subscription service init failed
  }

  // Initialize operation tracker service (with auth for cloud sync)
  final operationTrackerService = OperationTrackerService();
  try {
    await operationTrackerService.init(
      subscriptionService,
      authService: authService,
    );
  } catch (e) {
    // Operation tracker init failed
    print('Operation tracker init failed: $e');
  }

  // Initialize job service with operation tracker
  try {
    await jobService.init(operationTrackerService: operationTrackerService);
  } catch (e) {
    // Job queue init failed
  }

  // Detect hardware acceleration support
  try {
    await HardwareAccelerationService.init();
  } catch (e) {
    // Hardware acceleration detection failed
  }

  // Initialize notification service
  try {
    await NotificationService.init();
    await NotificationService.requestPermissions();
  } catch (e) {
    // Notifications init failed
  }

  // Initialize review service
  try {
    await ReviewService().init();
  } catch (e) {
    // Review service init failed
  }

  // Initialize logging service
  final loggingService = LoggingService();
  try {
    await loggingService.init(authService: authService);
  } catch (e) {
    // Logging service init failed
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: jobService),
        ChangeNotifierProvider.value(value: appTheme),
        ChangeNotifierProvider.value(value: appLocalizations),
        ChangeNotifierProvider.value(value: filePickerService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: subscriptionService),
        ChangeNotifierProvider.value(value: operationTrackerService),
        ChangeNotifierProvider.value(value: loggingService),
      ],
      child: const VixelApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // For Android 13+ (API 33+), we need specific media permissions
  final permissions = <Permission>[
    Permission.videos,
    Permission.audio,
    Permission.photos,
  ];

  for (final permission in permissions) {
    try {
      final status = await permission.status;
      if (!status.isGranted) {
        await permission.request();
      }
    } catch (e) {
      // Ignore permission errors - app will request again when needed
    }
  }
}

class VixelApp extends StatelessWidget {
  const VixelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppTheme, AuthService>(
      builder: (context, appTheme, authService, child) {
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
          // Show sign-in screen if not authenticated
          home: authService.isSignedIn 
              ? const HomeScreen() 
              : const SignInScreen(),
        );
      },
    );
  }
}
