import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../screens/family_screen.dart';
import 'family_service.dart';
import 'supabase_access.dart';

/// Handles `balanzo://join?invite=<uuid>` deep links and deferred accept after login.
class FamilyInviteLinkService {
  static const _pendingInviteKey = 'pending_family_invite_id';
  static const _pendingInviteAtKey = 'pending_family_invite_at_ms';
  static const _pendingMaxAge = Duration(days: 7);

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSub;
  static bool _initialized = false;
  static bool _processing = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    _linkSub = _appLinks.uriLinkStream.listen(_handleUri);
    unawaited(_appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    }));
  }

  static void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
    _initialized = false;
  }

  static String buildInviteLink(String inviteId) =>
      'balanzo://join?invite=$inviteId';

  static String? parseInviteId(Uri uri) {
    if (uri.scheme != 'balanzo') return null;
    if (uri.host != 'join') return null;
    final id = uri.queryParameters['invite']?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Future<void> _handleUri(Uri uri) async {
    final inviteId = parseInviteId(uri);
    if (inviteId == null) return;

    if (!supabaseReady || SupabaseAccess.currentUserId == null) {
      await _storePending(inviteId);
      return;
    }
    await _acceptAndNavigate(inviteId);
  }

  /// Call after login when [DashboardScreen] mounts.
  static Future<void> tryConsumePendingInvite() async {
    if (_processing) return;
    if (!supabaseReady || SupabaseAccess.currentUserId == null) return;

    final inviteId = await _loadPendingIfValid();
    if (inviteId == null) return;

    await _acceptAndNavigate(inviteId);
    await _clearPending();
  }

  static Future<void> _acceptAndNavigate(String inviteId) async {
    if (_processing) return;
    _processing = true;
    try {
      final familyId = await FamilyService.acceptInvite(inviteId);
      final family = await FamilyService.fetchFamilyById(familyId);
      final lang = currentLanguage.value;
      final familyName = family?.name ?? '';

      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      final message = familyName.isNotEmpty
          ? AppStrings.familyInviteSuccess(familyName, lang)
          : AppStrings.get('family_invite_success_generic', lang);

      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: Text(AppStrings.get('family_invite_joined_title', lang)),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const FamilyScreen()),
                );
              },
              child: Text(AppStrings.get('family', lang)),
            ),
          ],
        ),
      );
      await _clearPending();
    } on FamilyInviteException catch (e) {
      _showError(_localizedInviteError(e));
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _processing = false;
    }
  }

  static String _localizedInviteError(FamilyInviteException e) {
    final lang = currentLanguage.value;
    switch (e.reason) {
      case FamilyInviteFailure.invalid:
        return AppStrings.get('family_invite_invalid', lang);
      case FamilyInviteFailure.expired:
        return AppStrings.get('family_invite_expired', lang);
      case FamilyInviteFailure.other:
        return e.rawMessage ??
            AppStrings.get('family_invite_error_generic', lang);
    }
  }

  static void _showError(String message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> _storePending(String inviteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteKey, inviteId);
    await prefs.setInt(
      _pendingInviteAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<String?> _loadPendingIfValid() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_pendingInviteKey);
    if (id == null || id.isEmpty) return null;
    final atMs = prefs.getInt(_pendingInviteAtKey);
    if (atMs != null) {
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(atMs),
      );
      if (age > _pendingMaxAge) {
        await _clearPending();
        return null;
      }
    }
    return id;
  }

  static Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteKey);
    await prefs.remove(_pendingInviteAtKey);
  }
}
