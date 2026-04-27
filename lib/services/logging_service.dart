import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Centralized logging service for error tracking.
///
/// Privacy:
///  * No email or display name is ever sent.
///  * File paths are reduced to `<file>.ext` placeholders before upload.
///  * Free-form text (FFmpeg stderr, exception messages) has absolute paths
///    masked with `<path>` before upload.
///  * Reporting can be disabled by the user via the in-app toggle, which is
///    persisted in SharedPreferences.
class LoggingService extends ChangeNotifier {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static const String _prefsKey = 'vixel_send_error_reports';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthService? _authService;
  bool _enableRemoteLogging = true;

  bool get enableRemoteLogging => _enableRemoteLogging;

  /// Initialize logging service.
  Future<void> init({AuthService? authService}) async {
    _authService = authService;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enableRemoteLogging = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // keep default = true
    }
  }

  /// Toggle remote error reporting (user-facing setting).
  Future<void> setEnableRemoteLogging(bool value) async {
    if (_enableRemoteLogging == value) return;
    _enableRemoteLogging = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // ignore persistence errors; in-memory value is still respected
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sanitization helpers
  // ---------------------------------------------------------------------------

  // Anything that looks like an absolute path on Android, iOS, macOS or Windows.
  static final RegExp _absolutePathRegex = RegExp(
    r'(/storage/\S+|/data/\S+|/sdcard/\S+|/private/\S+|/var/\S+|/Users/\S+|file://\S+|[A-Za-z]:\\\S+)',
  );

  static final RegExp _safeExtRegex = RegExp(r'^[a-z0-9]{1,6}$');

  /// Reduce a file path/URI to a safe placeholder of the form `<file>.ext`.
  /// Used for fields that we know hold a path.
  static String sanitizePath(String? value) {
    if (value == null || value.isEmpty) return '';
    final clean = value.split('?').first;
    final dot = clean.lastIndexOf('.');
    final slash = clean.lastIndexOf(RegExp(r'[\\/]'));
    if (dot > slash && dot > -1 && dot < clean.length - 1) {
      final ext = clean.substring(dot + 1).toLowerCase();
      if (_safeExtRegex.hasMatch(ext)) {
        return '<file>.$ext';
      }
    }
    return '<file>';
  }

  /// Mask any absolute file paths embedded in free-form text (e.g. FFmpeg
  /// stderr, exception messages, stack traces).
  static String? sanitizeText(String? value) {
    if (value == null) return null;
    return value.replaceAll(_absolutePathRegex, '<path>');
  }

  /// Walks a context map. String values under "path-ish" keys are reduced to
  /// `<file>.ext`; other string values are scrubbed of absolute paths.
  static Map<String, dynamic>? sanitizeContext(Map<String, dynamic>? ctx) {
    if (ctx == null) return null;
    final out = <String, dynamic>{};
    ctx.forEach((k, v) {
      final low = k.toLowerCase();
      final looksLikePath = low.endsWith('path') ||
          low.endsWith('uri') ||
          low == 'filename' ||
          low == 'file' ||
          low == 'input' ||
          low == 'output';
      if (v is String) {
        out[k] = looksLikePath ? sanitizePath(v) : sanitizeText(v);
      } else if (v is List) {
        out[k] = v
            .map((e) => e is String
                ? (looksLikePath ? sanitizePath(e) : sanitizeText(e))
                : e)
            .toList();
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Logging API
  // ---------------------------------------------------------------------------

  /// Log an error with stack trace.
  Future<void> logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? operation,
  }) async {
    if (!_enableRemoteLogging) return;

    try {
      final userId = _authService?.userId ?? 'anonymous';

      await _firestore.collection('error_logs').add({
        'userId': userId,
        'level': 'error',
        'message': sanitizeText(message),
        'error': sanitizeText(error?.toString()),
        'stackTrace': sanitizeText(stackTrace?.toString()),
        'operation': operation,
        'context': sanitizeContext(context),
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': await _getDeviceInfo(),
      });

      debugPrint('[LoggingService] Error logged: $operation - $message');
    } catch (e, st) {
      debugPrint('[LoggingService] FAILED to send log to Firestore: $e');
      debugPrint('[LoggingService] Stack trace: $st');
    }
  }

  /// Log a warning.
  Future<void> logWarning(
    String message, {
    Map<String, dynamic>? context,
    String? operation,
  }) async {
    if (!_enableRemoteLogging) return;

    try {
      final userId = _authService?.userId ?? 'anonymous';

      await _firestore.collection('error_logs').add({
        'userId': userId,
        'level': 'warning',
        'message': sanitizeText(message),
        'operation': operation,
        'context': sanitizeContext(context),
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': await _getDeviceInfo(),
      });
    } catch (e) {
      debugPrint('[LoggingService] Failed to send log to Firestore: $e');
    }
  }

  /// Delete every `error_logs` document authored by the given uid.
  /// Used during account deletion. Best-effort: silently swallows errors.
  Future<void> deleteUserLogs(String uid) async {
    if (uid.isEmpty) return;
    try {
      QuerySnapshot snap;
      do {
        snap = await _firestore
            .collection('error_logs')
            .where('userId', isEqualTo: uid)
            .limit(200)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      } while (snap.docs.length == 200);
    } catch (e) {
      debugPrint('[LoggingService] Failed to delete user logs: $e');
    }
  }

  /// Coarse device information: OS name, version, and debug flag.
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'isDebug': kDebugMode,
    };
  }
}
