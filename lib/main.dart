import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
// UI CONTRACT: Never use opacity below Colors.black54 on white/light backgrounds.
// Never use Colors.grey on white backgrounds. Monetary values and item names
// must use Colors.black87 minimum. This rule applies to all screens permanently.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'config/app_colors.dart';
import 'app_state.dart';
import 'diag_log.dart';
import 'screens/age_gate_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'services/user_profile_service.dart';
import 'services/family_invite_link_service.dart';
import 'utils/postgrest_errors.dart';

bool _handleGlobalError(Object error, StackTrace stack) {
  if (isIgnorablePostgrestAuthError(error)) {
    logIgnorablePostgrestAuthError(error);
    return true;
  }
  return false;
}

void _installGlobalErrorHandlers() {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_handleGlobalError(
      details.exception,
      details.stack ?? StackTrace.empty,
    )) {
      return;
    }
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_handleGlobalError(error, stack)) return true;
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return false;
  };
}

void _installCrashlyticsErrorHandlers() {
  FlutterError.onError = (details) {
    if (_handleGlobalError(
      details.exception,
      details.stack ?? StackTrace.empty,
    )) {
      return;
    }
    FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_handleGlobalError(error, stack)) return true;
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    return true;
  };
}

Future<void> _initializeServices() async {
  _initFirebaseInBackground();

  try {
    debugPrint('[INIT] Supabase.initialize() starting...');
    await Supabase.initialize(
      url: 'https://mwookghnlhmseayeyycj.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13b29rZ2hubGhtc2VheWV5eWNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzMyMjEsImV4cCI6MjA5NDk0OTIyMX0.lTcGXJ2u5V_jJTzwDQFagCmLE7cRrrRcCPpuAM6E-d8',
    ).timeout(const Duration(seconds: 15));
    supabaseReady = true;
    supabaseReadyNotifier.value = true;
    debugPrint('[INIT] Supabase.initialize() OK');
  } catch (e, st) {
    debugPrint('[INIT] Supabase.initialize() FAILED: $e\n$st');
  }

  try {
    UserProfileService.warmCache();
  } catch (_) {}

  if (supabaseReady) {
    unawaited(UserProfileService.loadFullName());
  }

  try {
    final prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 5));
    currentLanguage.value = prefs.getString('app_language') ?? 'en';
    final themePref = prefs.getString('theme_mode') ?? 'light';
    currentThemeMode.value = themePref == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {}
}

void _initFirebaseInBackground() {
  unawaited(Future(() async {
    try {
      debugPrint('[INIT] Firebase.initializeApp() starting...');
      await Firebase.initializeApp().timeout(const Duration(seconds: 15));
      _installCrashlyticsErrorHandlers();
      debugPrint('[INIT] Firebase.initializeApp() OK');
    } catch (e, st) {
      debugPrint('[INIT] Firebase.initializeApp() FAILED: $e\n$st');
    }
  }));
}

void main() {
  diag('main() enter');
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();
  diag('main() runApp');
  runApp(const BalanzoApp());
}

/// Picks age gate vs auth without a blocking green splash.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _ageConfirmed;

  @override
  void initState() {
    super.initState();
    diag('AppEntry.initState');
    _resolveAgeGate();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _ageConfirmed == null) {
        debugPrint('[INIT] AppEntry age-gate fallback timeout');
        setState(() => _ageConfirmed = false);
      }
    });
  }

  Future<void> _resolveAgeGate() async {
    var confirmed = false;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      confirmed = prefs.getBool('age_gate_confirmed') ?? false;
    } catch (_) {}
    if (mounted) {
      debugPrint('[INIT] AppEntry ageConfirmed=$confirmed');
      setState(() => _ageConfirmed = confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ageConfirmed == null) {
      diag('AppEntry.build loading');
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF1B5E20)),
              SizedBox(height: 16),
              Text('Loading Balanzo…', style: TextStyle(color: Colors.black87)),
            ],
          ),
        ),
      );
    }
    diag('AppEntry.build route', _ageConfirmed! ? 'AuthGate' : 'AgeGate');
    return _ageConfirmed! ? const AuthGateScreen() : const AgeGateScreen();
  }
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

  @override
  void initState() {
    super.initState();
    FamilyInviteLinkService.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[INIT] postFrame — starting background services');
      unawaited(_initializeServices());
    });
  }

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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF2F2F5)),
          bodyMedium: TextStyle(color: Color(0xFFF2F2F5)),
          bodySmall: TextStyle(color: Color(0xFFB8B8C8)),
          labelLarge: TextStyle(color: Color(0xFFF2F2F5)),
          labelMedium: TextStyle(color: Color(0xFFB8B8C8)),
          labelSmall: TextStyle(color: Color(0xFF8888A0), letterSpacing: 1.2),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: Color(0xFFF2F2F5), fontWeight: FontWeight.w500),
          headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFFB8B8C8)),
          hintStyle: TextStyle(color: Color(0xFF8888A0)),
          floatingLabelStyle: TextStyle(color: Color(0xFFF2F2F5)),
        ),
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
          backgroundColor: AppColors.primaryGreenLight,
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
          navigatorKey: rootNavigatorKey,
          title: 'Balanzo',
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeMode,
          home: const _AppEntry(),
          onUnknownRoute: (settings) =>
              MaterialPageRoute(builder: (_) => const AuthGateScreen()),
        ),
      ),
    );
  }
}
