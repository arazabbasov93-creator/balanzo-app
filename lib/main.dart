import 'dart:ui';
import 'package:flutter/material.dart';
// UI CONTRACT: Never use opacity below Colors.black54 on white/light backgrounds.
// Never use Colors.grey on white backgrounds. Monetary values and item names
// must use Colors.black87 minimum. This rule applies to all screens permanently.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app_state.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  debugPrint('[INIT] WidgetsFlutterBinding.ensureInitialized()');
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('[INIT] Supabase.initialize() starting...');
    await Supabase.initialize(
      url: 'https://mwookghnlhmseayeyycj.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13b29rZ2hubGhtc2VheWV5eWNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzMyMjEsImV4cCI6MjA5NDk0OTIyMX0.lTcGXJ2u5V_jJTzwDQFagCmLE7cRrrRcCPpuAM6E-d8',
    );
    debugPrint('[INIT] Supabase.initialize() OK');
  } catch (e, st) {
    debugPrint('[INIT] Supabase.initialize() FAILED: $e\n$st');
    // App still launches — auth screens will show an error state
  }

  try {
    debugPrint('[INIT] Firebase.initializeApp() starting...');
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('[INIT] Firebase.initializeApp() OK');
  } catch (e, st) {
    debugPrint('[INIT] Firebase.initializeApp() FAILED: $e\n$st');
    // Firebase/Crashlytics is optional — app works without it
  }

  try {
    debugPrint('[INIT] NotificationService.init() starting...');
    await NotificationService.init();
    debugPrint('[INIT] NotificationService.init() OK');
  } catch (e, st) {
    debugPrint('[INIT] NotificationService.init() FAILED: $e\n$st');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    currentLanguage.value = prefs.getString('app_language') ?? 'en';
    final themePref = prefs.getString('theme_mode') ?? 'light';
    currentThemeMode.value = themePref == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {}

  debugPrint('[INIT] runApp() called');
  runApp(const BalanzoApp());
}

class BalanzoApp extends StatefulWidget {
  const BalanzoApp({super.key});

  @override
  State<BalanzoApp> createState() => _BalanzoAppState();
}

class _BalanzoAppState extends State<BalanzoApp> {
  static const _navLabelStyle = NavigationBarThemeData(
    labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
  );

  ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
          surface: const Color(0xFF09090B),
          onSurface: const Color(0xFFF2F2F5),
          surfaceContainerHighest: const Color(0xFF18181C),
          outline: const Color(0xFF2C2C34),
          onSurfaceVariant: const Color(0xFF8888A0),
        ),
        scaffoldBackgroundColor: const Color(0xFF09090B),
        cardColor: const Color(0xFF111113),
        dividerColor: const Color(0xFF2C2C34),
        useMaterial3: true,
        navigationBarTheme: _navLabelStyle,
      );

  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1A1A1A),
          surfaceContainerHighest: const Color(0xFFF5F5F5),
          outline: const Color(0xFFDDDDDD),
          onSurfaceVariant: const Color(0xFF555566),
        ),
        scaffoldBackgroundColor: Colors.white,
        cardColor: const Color(0xFFF5F5F5),
        dividerColor: const Color(0xFFDDDDDD),
        useMaterial3: true,
        navigationBarTheme: _navLabelStyle,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
          bodySmall: TextStyle(color: Colors.black54),
          labelLarge: TextStyle(color: Colors.black87),
          labelMedium: TextStyle(color: Colors.black54),
          labelSmall: TextStyle(color: Colors.black45, letterSpacing: 1.2),
          titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
          headlineMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black54),
          hintStyle: TextStyle(color: Colors.black38),
          floatingLabelStyle: TextStyle(color: Colors.black87),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: currentThemeMode,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'Balanzo',
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeMode,
          home: const SplashScreen(),
          onUnknownRoute: (settings) =>
              MaterialPageRoute(builder: (_) => const AuthGateScreen()),
        ),
      ),
    );
  }
}

