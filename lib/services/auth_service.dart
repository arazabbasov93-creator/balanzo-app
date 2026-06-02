import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '613777273688-s5to8t2nvu7v6d9stb2sjdlvfffj2vdu.apps.googleusercontent.com',
  );

  static Future<AuthResponse> signInWithGoogle() async {
    try {
      // Clear stale session so account picker always returns fresh tokens.
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception(
          'No ID token from Google. Check Firebase SHA-1 and Web client ID in Supabase.',
        );
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    } on AuthException catch (e) {
      debugPrint('[Auth] Supabase Google sign-in: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e, st) {
      debugPrint('[Auth] Google sign-in failed: $e\n$st');
      rethrow;
    }
  }

  static Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('No identity token from Apple.');
    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  /// Saves profile row; failures are logged but must not block sign-in.
  static Future<void> upsertUser(User user) async {
    try {
      final data = <String, dynamic>{'id': user.id};
      if (user.email != null) data['email'] = user.email;
      if (user.phone != null) data['phone'] = user.phone;
      final name = user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String?;
      if (name != null) data['full_name'] = name;
      await _supabase.from('users').upsert(data, onConflict: 'id');
    } catch (e, st) {
      debugPrint('[Auth] upsertUser failed (sign-in still OK): $e\n$st');
    }
  }

  static Future<String?> fetchAvatarUrl() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final row = await _supabase
          .from('users')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      return row?['avatar_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  static User? get currentUser => _supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
