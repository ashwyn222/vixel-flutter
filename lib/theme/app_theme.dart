import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light1,
  dark1,
  dark2,
  dark3,
}

class AppThemeData {
  final String name;
  final Color previewColor;
  final bool isDark;
  
  // Brand colors
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  
  // Background colors
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color cardBackground;
  
  // Text colors
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnCard;  // Text color for content on cards (for hybrid themes)
  
  // Status colors
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  
  // Feature card colors
  final Color compressColor;
  final Color cutColor;
  final Color mergeColor;
  final Color extractAudioColor;
  final Color audioOnVideoColor;
  final Color photosToVideoColor;
  final Color watermarkColor;

  const AppThemeData({
    required this.name,
    required this.previewColor,
    required this.isDark,
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnCard,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.compressColor,
    required this.cutColor,
    required this.mergeColor,
    required this.extractAudioColor,
    required this.audioOnVideoColor,
    required this.photosToVideoColor,
    required this.watermarkColor,
  });
}

class AppTheme extends ChangeNotifier {
  static const String _storageKey = 'vixel_theme';
  
  AppThemeMode _currentMode = AppThemeMode.dark1;
  
  AppThemeMode get currentMode => _currentMode;
  
  AppTheme() {
    _loadSavedTheme();
  }
  
  /// Load saved theme from SharedPreferences
  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_storageKey);
      if (savedTheme != null) {
        final mode = AppThemeMode.values.firstWhere(
          (m) => m.name == savedTheme,
          orElse: () => AppThemeMode.dark1,
        );
        _currentMode = mode;
        _activeTheme = currentThemeData;
        notifyListeners();
      }
    } catch (e) {
      // Ignore errors, use default theme
    }
  }
  
  /// Save theme to SharedPreferences
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _currentMode.name);
    } catch (e) {
      // Ignore errors
    }
  }
  
  void setTheme(AppThemeMode mode) {
    _currentMode = mode;
    _saveTheme();
    notifyListeners();
  }
  
  AppThemeData get currentThemeData => themes[_currentMode]!;
  
  // Static access for widgets that don't have context
  static AppThemeData? _activeTheme;
  static AppThemeData get active => _activeTheme ?? themes[AppThemeMode.dark1]!;
  
  void updateActiveTheme() {
    _activeTheme = currentThemeData;
  }

  // Theme definitions
  static final Map<AppThemeMode, AppThemeData> themes = {
    // Light 1 - Warm Cream with Teal accent (previously Light 2)
    AppThemeMode.light1: const AppThemeData(
      name: 'Light 1',
      previewColor: Color(0xFFFAF8F5),
      isDark: false,
      primary: Color(0xFF0D9488),
      primaryDark: Color(0xFF0F766E),
      secondary: Color(0xFFD97706),
      background: Color(0xFFFAF8F5),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFECE9E4),
      cardBackground: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF1F2937),
      textSecondary: Color(0xFF4B5563),
      textMuted: Color(0xFF9CA3AF),
      textOnCard: Color(0xFF1F2937),
      success: Color(0xFF059669),
      error: Color(0xFFDC2626),
      warning: Color(0xFFD97706),
      info: Color(0xFF2563EB),
      compressColor: Color(0xFF0D9488),
      cutColor: Color(0xFFDB2777),
      mergeColor: Color(0xFF7C3AED),
      extractAudioColor: Color(0xFF0891B2),
      audioOnVideoColor: Color(0xFF059669),
      photosToVideoColor: Color(0xFFD97706),
      watermarkColor: Color(0xFF7C3AED),
    ),
    
    // Dark 1 - Vibrant (dark theme with colorful card backgrounds by category)
    // Feature cards have colored backgrounds based on their category
    AppThemeMode.dark1: const AppThemeData(
      name: 'Dark 1',
      previewColor: Color(0xFF0A0A0F),
      isDark: true,
      primary: Color(0xFF10B981),  // Green accent
      primaryDark: Color(0xFF059669),
      secondary: Color(0xFF8B5CF6),
      background: Color(0xFF0A0A0F),  // Deep dark background
      surface: Color(0xFF12121A),
      surfaceVariant: Color(0xFF1A1A24),
      cardBackground: Color(0xFF16161F),  // Dark cards (for non-feature cards)
      textPrimary: Color(0xFFF5F5F7),
      textSecondary: Color(0xFF9CA3AF),
      textMuted: Color(0xFF6B7280),
      textOnCard: Color(0xFFF5F5F7),
      success: Color(0xFF10B981),
      error: Color(0xFFEF4444),
      warning: Color(0xFFF59E0B),
      info: Color(0xFF3B82F6),
      // Category-based CARD background colors:
      // Video Editing (Compress, Cut, Merge) - Dark Blue
      compressColor: Color(0xFF1E40AF),  // Blue-700
      cutColor: Color(0xFF1E40AF),  // Blue-700
      mergeColor: Color(0xFF1E40AF),  // Blue-700
      // Audio Operations - Dark Green
      extractAudioColor: Color(0xFF166534),  // Green-800
      audioOnVideoColor: Color(0xFF166534),  // Green-800
      // Creative Tools - Dark Red
      photosToVideoColor: Color(0xFF991B1B),  // Red-800
      watermarkColor: Color(0xFF991B1B),  // Red-800
    ),
    
    // Dark 2 - Deep Cinematic (previously Dark 1)
    AppThemeMode.dark2: const AppThemeData(
      name: 'Dark 2',
      previewColor: Color(0xFF0A0A0F),
      isDark: true,
      primary: Color(0xFFE85D04),
      primaryDark: Color(0xFFD45000),
      secondary: Color(0xFF6366F1),
      background: Color(0xFF0A0A0F),
      surface: Color(0xFF12121A),
      surfaceVariant: Color(0xFF1A1A24),
      cardBackground: Color(0xFF16161F),
      textPrimary: Color(0xFFF5F5F7),
      textSecondary: Color(0xFF9CA3AF),
      textMuted: Color(0xFF6B7280),
      textOnCard: Color(0xFFF5F5F7),
      success: Color(0xFF10B981),
      error: Color(0xFFEF4444),
      warning: Color(0xFFF59E0B),
      info: Color(0xFF3B82F6),
      compressColor: Color(0xFFE85D04),
      cutColor: Color(0xFFEC4899),
      mergeColor: Color(0xFF8B5CF6),
      extractAudioColor: Color(0xFF06B6D4),
      audioOnVideoColor: Color(0xFF10B981),
      photosToVideoColor: Color(0xFFF59E0B),
      watermarkColor: Color(0xFF6366F1),
    ),
    
    // Dark 3 - Midnight Blue (previously Dark 2)
    AppThemeMode.dark3: const AppThemeData(
      name: 'Dark 3',
      previewColor: Color(0xFF0F172A),
      isDark: true,
      primary: Color(0xFF3B82F6),
      primaryDark: Color(0xFF2563EB),
      secondary: Color(0xFFF472B6),
      background: Color(0xFF0F172A),
      surface: Color(0xFF1E293B),
      surfaceVariant: Color(0xFF334155),
      cardBackground: Color(0xFF1E293B),
      textPrimary: Color(0xFFF1F5F9),
      textSecondary: Color(0xFF94A3B8),
      textMuted: Color(0xFF64748B),
      textOnCard: Color(0xFFF1F5F9),
      success: Color(0xFF22C55E),
      error: Color(0xFFF43F5E),
      warning: Color(0xFFFBBF24),
      info: Color(0xFF38BDF8),
      compressColor: Color(0xFF3B82F6),
      cutColor: Color(0xFFF472B6),
      mergeColor: Color(0xFFA78BFA),
      extractAudioColor: Color(0xFF22D3EE),
      audioOnVideoColor: Color(0xFF22C55E),
      photosToVideoColor: Color(0xFFFBBF24),
      watermarkColor: Color(0xFFA78BFA),
    ),
  };

  // Legacy static accessors for backward compatibility
  static Color get primary => active.primary;
  static Color get primaryDark => active.primaryDark;
  static Color get secondary => active.secondary;
  static Color get background => active.background;
  static Color get surface => active.surface;
  static Color get surfaceVariant => active.surfaceVariant;
  static Color get cardBackground => active.cardBackground;
  static Color get textPrimary => active.textPrimary;
  static Color get textSecondary => active.textSecondary;
  static Color get textMuted => active.textMuted;
  static Color get textOnCard => active.textOnCard;
  static Color get success => active.success;
  static Color get error => active.error;
  static Color get warning => active.warning;
  static Color get info => active.info;
  static Color get compressColor => active.compressColor;
  static Color get cutColor => active.cutColor;
  static Color get mergeColor => active.mergeColor;
  static Color get extractAudioColor => active.extractAudioColor;
  static Color get audioOnVideoColor => active.audioOnVideoColor;
  static Color get photosToVideoColor => active.photosToVideoColor;
  static Color get watermarkColor => active.watermarkColor;

  ThemeData get themeData {
    final t = currentThemeData;
    return ThemeData(
      useMaterial3: true,
      brightness: t.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: t.background,
      primaryColor: t.primary,
      colorScheme: t.isDark
          ? ColorScheme.dark(
              primary: t.primary,
              secondary: t.secondary,
              surface: t.surface,
              error: t.error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: t.textPrimary,
              onError: Colors.white,
            )
          : ColorScheme.light(
              primary: t.primary,
              secondary: t.secondary,
              surface: t.surface,
              error: t.error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: t.textPrimary,
              onError: Colors.white,
            ),
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: t.textPrimary,
          letterSpacing: -1,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: t.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: t.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: t.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: t.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.surfaceVariant, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: t.textMuted),
        labelStyle: TextStyle(color: t.textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.primary,
        inactiveTrackColor: t.surfaceVariant,
        thumbColor: t.primary,
        overlayColor: t.primary.withAlpha(51),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return t.primary;
          }
          return t.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return t.primary.withAlpha(128);
          }
          return t.surfaceVariant;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return t.primary;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: t.textMuted, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceVariant,
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: t.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.surface,
        selectedItemColor: t.primary,
        unselectedItemColor: t.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: t.surfaceVariant,
        thickness: 1,
      ),
    );
  }

  // Legacy static method for backward compatibility
  static ThemeData get darkTheme {
    return AppTheme().themeData;
  }
}
