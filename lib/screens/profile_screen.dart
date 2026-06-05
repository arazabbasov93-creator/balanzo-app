// Run in Supabase SQL Editor before testing:
// INSERT INTO storage.buckets (id, name, public)
//    VALUES ('avatars', 'avatars', true)
//    ON CONFLICT DO NOTHING;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/crash_service.dart';
import '../services/subscription_service.dart';
import 'upgrade_screen.dart';
import 'analytics_screen.dart';
import 'categories_screen.dart';
import 'family_screen.dart';
import 'legal_screen.dart';
import 'share_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _langKey = 'app_language';
  String _language = 'en';
  SubscriptionTier _tier = SubscriptionTier.free;
  bool _notificationsEnabled = true;
  bool _loading = true;
  bool _isDarkMode = false;
  String? _customAvatarUrl;

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    _load();
  }

  void _onLangChange() {
    if (mounted) setState(() => _language = currentLanguage.value);
  }

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final tier = await SubscriptionService.fetchTier();
    final avatarUrl = await AuthService.fetchAvatarUrl();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString(_langKey) ?? 'en';
      _tier = tier;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _isDarkMode = (prefs.getString('theme_mode') ?? 'light') == 'dark';
      _customAvatarUrl = avatarUrl;
      _loading = false;
    });
  }

  Future<void> _setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
    currentLanguage.value = lang;
    setState(() => _language = lang);
  }

  Future<void> _toggleNotifications(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', val);
    setState(() => _notificationsEnabled = val);
  }

  Future<void> _toggleDarkMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', val ? 'dark' : 'light');
    currentThemeMode.value = val ? ThemeMode.dark : ThemeMode.light;
    setState(() => _isDarkMode = val);
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final bytes = await picked.readAsBytes();
      await supabase.storage.from('avatars').uploadBinary(
        '$userId/$userId.jpg',
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      final url = supabase.storage.from('avatars').getPublicUrl('$userId/$userId.jpg');
      await supabase.from('users').update({'avatar_url': url}).eq('id', userId);
      if (mounted) setState(() => _customAvatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update avatar: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _themeModeLabel() {
    switch (_language) {
      case 'az': return _isDarkMode ? 'Tünd fon' : 'Açıq fon';
      case 'ru': return _isDarkMode ? 'Тёмная тема' : 'Светлая тема';
      default: return _isDarkMode ? 'Dark Mode' : 'Light Mode';
    }
  }

  String _tierLabel() {
    switch (_tier) {
      case SubscriptionTier.aiPremium:
        return 'AI Premium';
      case SubscriptionTier.familyPlan:
        return 'Family Plan';
      default:
        return 'Free';
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final confirmed2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'All receipts, budgets, and family data will be deleted forever.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed2 != true || !mounted) return;

    try {
      await _deleteAllUserData();
      await AuthService.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteAllUserData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('receipts').delete().eq('user_id', userId);
    await supabase.from('budgets').delete().eq('user_id', userId);
    await supabase.from('family_members').delete().eq('user_id', userId);
    await supabase.from('users').delete().eq('id', userId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = AuthService.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? user?.userMetadata?['name'] as String? ?? '';
    final identity = user?.phone ?? user?.email ?? 'User';
    final authAvatar = user?.userMetadata?['avatar_url'] as String? ?? user?.userMetadata?['picture'] as String?;
    final avatar = _customAvatarUrl ?? authAvatar;
    final initial = identity.isNotEmpty ? identity.substring(0, 1).toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppStrings.get('profile_settings', _language), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFF1E2F1E),
                        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? Text(initial, style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 24, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFAAFF45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Color(0xFF09090B), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      Text(identity, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _tier == SubscriptionTier.free ? const Color(0xFF1E1E24) : const Color(0xFF1E2F1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _tierLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _tier == SubscriptionTier.free ? const Color(0xFF8888A0) : const Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Language + Notifications
          _Section(title: AppStrings.get('preferences', _language), children: [
            _Tile(
              icon: Icons.language,
              label: AppStrings.get('language', _language),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: ['EN', 'AZ', 'RU'].map((display) {
                  final langCode = display.toLowerCase();
                  return GestureDetector(
                    onTap: () => _setLanguage(langCode),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _language == langCode
                            ? const Color(0xFF1B5E20)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _language == langCode
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              title: Row(
                children: [
                  Icon(Icons.notifications_outlined, color: const Color(0xFF8888A0), size: 20),
                  const SizedBox(width: 12),
                  Text(AppStrings.get('notifications', _language), style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              activeThumbColor: const Color(0xFF1B5E20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            SwitchListTile(
              value: _isDarkMode,
              onChanged: _toggleDarkMode,
              title: Row(
                children: [
                  Icon(_isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: const Color(0xFF8888A0), size: 20),
                  const SizedBox(width: 12),
                  Text(_themeModeLabel(), style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              activeThumbColor: const Color(0xFF1B5E20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ]),

          const SizedBox(height: 8),
          _Section(title: AppStrings.get('subscription', _language), children: [
            if (_tier == SubscriptionTier.free)
              _Tile(
                icon: Icons.workspace_premium,
                label: AppStrings.get('upgrade_to_premium', _language),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
                iconColor: const Color(0xFFFFD040),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFFFFD040), size: 20),
                    const SizedBox(width: 12),
                    Text('${_tierLabel()} Active', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFFF2F2F5))),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
              ),
          ]),

          const SizedBox(height: 8),
          _Section(title: 'App', children: [
            _Tile(
              icon: Icons.family_restroom_outlined,
              label: AppStrings.get('family', _language),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyScreen())),
            ),
            _Tile(icon: Icons.bar_chart_outlined, label: AppStrings.get('analytics', _language), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
            _Tile(icon: Icons.category_outlined, label: AppStrings.get('categories', _language), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
            // VAT TRACKER: Hidden — requires government ƏDV
            // API integration. Do not delete.
            // Re-enable when API is available.
            // HIDDEN: VAT tracker disabled — requires government DVX API (Phase 2). Do not delete.
            // VAT TRACKER: Hidden — requires government ƏDV
            // API integration. Do not delete.
            // Re-enable when API is available.
            // _Tile(icon: Icons.receipt_long_outlined, label: AppStrings.get('vat_tracker', _language), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VatTrackerScreen()))),
            _Tile(icon: Icons.share_outlined, label: AppStrings.get('share_my_stats', _language), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShareScreen()))),
            _Tile(
              icon: Icons.description_outlined,
              label: AppStrings.get('privacy_policy', _language),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacy))),
            ),
            _Tile(
              icon: Icons.gavel_outlined,
              label: AppStrings.get('terms', _language),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.terms))),
            ),
            _Tile(
              icon: Icons.info_outline,
              label: AppStrings.get('about', _language),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Balanzo'),
                  content: const Text('Version 1.0.0\n\n© 2025 Balanzo. All rights reserved.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  ],
                ),
              ),
            ),
          ]),

          const SizedBox(height: 8),
          _Section(title: AppStrings.get('account', _language), children: [
            _Tile(
              icon: Icons.logout,
              label: AppStrings.get('sign_out', _language),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Sign out of your account?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (ok == true) {
                  await CrashService.clearUser();
                  await AuthService.signOut();
                }
              },
            ),
            _Tile(
              icon: Icons.delete_forever_outlined,
              label: AppStrings.get('delete_account', _language),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: _deleteAccount,
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;
  final Widget? trailing;

  const _Tile({
    required this.icon,
    required this.label,
    this.onTap,
    this.textColor,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        child: Icon(icon, color: iconColor ?? const Color(0xFF1B5E20), size: 24),
      ),
      title: Text(label, style: TextStyle(fontSize: 15, color: textColor ?? Theme.of(context).colorScheme.onSurface)),
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18) : null),
      onTap: onTap,
      visualDensity: VisualDensity.standard,
    );
  }
}
