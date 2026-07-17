import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/notification_service.dart';
import '../config/app_colors.dart';
import '../widgets/balanzo_header_styles.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await NotificationService.fetchHistory();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markUnread(int index) async {
    await NotificationService.markAsUnread(index);
    await _load();
  }

  void _showDetail(Map<String, dynamic> item) {
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          item['title'] as String? ??
              AppStrings.get('notif_detail_title', lang),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((item['ts'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _formatTs(item['ts'] as String, lang),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Text(
                item['body'] as String? ?? '',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang)),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'restock':
        return Icons.shopping_cart_outlined;
      case 'vat':
        return Icons.receipt_long_outlined;
      case 'summary':
        return Icons.bar_chart_outlined;
      case 'price':
        return Icons.trending_up_outlined;
      case 'budget':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'restock':
        return Colors.blue;
      case 'vat':
        return Colors.orange;
      case 'summary':
        return AppColors.primaryGreenDark;
      case 'price':
        return Colors.red;
      case 'budget':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTs(String iso, String locale) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return locale == 'az'
            ? '${diff.inMinutes} dəq əvvəl'
            : locale == 'ru'
                ? '${diff.inMinutes} мин назад'
                : '${diff.inMinutes}m ago';
      }
      if (diff.inHours < 24) {
        return locale == 'az'
            ? '${diff.inHours} saat əvvəl'
            : locale == 'ru'
                ? '${diff.inHours} ч назад'
                : '${diff.inHours}h ago';
      }
      return locale == 'az'
          ? '${diff.inDays} gün əvvəl'
          : locale == 'ru'
              ? '${diff.inDays} дн назад'
              : '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          AppStrings.get('notifications', lang),
          style: BalanzoHeaderStyles.titleStyle.copyWith(color: Colors.white),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await NotificationService.markAllAsRead();
                _load();
              },
              child: Text(
                AppStrings.get('notif_mark_all_read', lang),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.get('notif_empty', lang),
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final type = item['type'] as String? ?? 'info';
                    final color = _colorForType(type);
                    final isRead = item['read'] == true;
                    final index = item['_index'] as int? ?? i;

                    return Dismissible(
                      key: ValueKey('notif_${item['ts']}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppStrings.get('notif_mark_unread', lang),
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        await _markUnread(index);
                        return false;
                      },
                      child: Material(
                        color: AppColors.card(Theme.of(context).brightness),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showDetail(item),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Opacity(
                              opacity: isRead ? 0.65 : 1,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_iconForType(type),
                                        color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['title'] as String? ?? '',
                                                style: TextStyle(
                                                  fontWeight: isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: onSurface,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTs(
                                                  item['ts'] as String? ?? '',
                                                  lang),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['body'] as String? ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
