import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class AppLanguage {
  final String code;
  final String flag;
  final String label;

  const AppLanguage({
    required this.code,
    required this.flag,
    required this.label,
  });
}

/// Extensible language list — add entries here and strings in app_strings.dart.
const kAppLanguages = <AppLanguage>[
  AppLanguage(code: 'en', flag: '🇬🇧', label: 'English'),
  AppLanguage(code: 'az', flag: '🇦🇿', label: 'Azerbaijani'),
  AppLanguage(code: 'ru', flag: '🇷🇺', label: 'Russian'),
];

AppLanguage languageByCode(String code) {
  return kAppLanguages.firstWhere(
    (l) => l.code == code,
    orElse: () => kAppLanguages.first,
  );
}

Future<String?> showLanguagePickerSheet(
  BuildContext context, {
  required String selectedCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _LanguagePickerSheet(selectedCode: selectedCode),
  );
}

class _LanguagePickerSheet extends StatefulWidget {
  final String selectedCode;
  const _LanguagePickerSheet({required this.selectedCode});

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppLanguage> get _filtered {
    if (_query.isEmpty) return kAppLanguages;
    return kAppLanguages.where((l) {
      return l.code.contains(_query) ||
          l.label.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered = _filtered;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search language…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...filtered.map((l) {
            final selected = l.code == widget.selectedCode;
            return ListTile(
              leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
              title: Text('${l.code.toUpperCase()} — ${l.label}'),
              trailing: selected
                  ? Icon(Icons.check, color: AppColors.primaryGreen(brightness))
                  : null,
              onTap: () => Navigator.pop(context, l.code),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class LanguagePickerTile extends StatelessWidget {
  final String label;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const LanguagePickerTile({
    super.key,
    required this.label,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final lang = languageByCode(selectedCode);
    return Material(
      color: Colors.transparent,
      child: ListTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        child: Icon(Icons.language, color: AppColors.primaryGreenDark, size: 24),
      ),
      title: Text(label, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${lang.flag} ${lang.code.toUpperCase()}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: () async {
        final picked = await showLanguagePickerSheet(
          context,
          selectedCode: selectedCode,
        );
        if (picked != null) onSelected(picked);
      },
    ),
    );
  }
}
