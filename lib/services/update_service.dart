import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service to handle in-app updates from Google Play Store
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  AppUpdateInfo? _updateInfo;
  bool _isUpdateAvailable = false;

  bool get isUpdateAvailable => _isUpdateAvailable;
  AppUpdateInfo? get updateInfo => _updateInfo;

  /// Check if an update is available from the Play Store
  Future<bool> checkForUpdate() async {
    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      _isUpdateAvailable = _updateInfo?.updateAvailability == 
          UpdateAvailability.updateAvailable;
      return _isUpdateAvailable;
    } catch (e) {
      debugPrint('Error checking for update: $e');
      _isUpdateAvailable = false;
      return false;
    }
  }

  /// Start a flexible update (non-blocking, user can continue using the app)
  /// Shows a download progress and prompts to install when ready
  Future<void> startFlexibleUpdate() async {
    if (!_isUpdateAvailable) return;
    
    try {
      await InAppUpdate.startFlexibleUpdate();
      // After download completes, prompt user to install
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('Error performing flexible update: $e');
    }
  }

  /// Start an immediate update (blocking, full-screen experience)
  /// User must update to continue using the app
  Future<void> startImmediateUpdate() async {
    if (!_isUpdateAvailable) return;
    
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Error performing immediate update: $e');
    }
  }

  /// Show a dialog to let user choose to update
  Future<void> showUpdateDialog(BuildContext context) async {
    if (!_isUpdateAvailable) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF00D9FF), size: 28),
            SizedBox(width: 12),
            Text(
              'Update Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Text(
          'A new version of Vixel is available. Update now to get the latest features and improvements.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Later',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Update Now',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldUpdate == true) {
      await startFlexibleUpdate();
    }
  }

  /// Check and prompt for update on app launch
  Future<void> checkAndPromptUpdate(BuildContext context) async {
    final hasUpdate = await checkForUpdate();
    if (hasUpdate && context.mounted) {
      await showUpdateDialog(context);
    }
  }
}
