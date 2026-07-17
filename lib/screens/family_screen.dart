import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_access.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../models/family.dart';
import '../services/family_service.dart';
import '../services/family_invite_link_service.dart';
import '../config/app_colors.dart';
import '../widgets/decimal_text_field.dart';
import '../widgets/family_budget_header_card.dart';
import '../models/family_period_summary.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late Future<Family?> _future;

  @override
  void initState() {
    super.initState();
    _future = FamilyService.fetchMyFamily();
  }

  void _refresh() => setState(() => _future = FamilyService.fetchMyFamily());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          AppStrings.get('family', currentLanguage.value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: FutureBuilder<Family?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          }
          final family = snapshot.data;
          if (family == null) return _NoFamilyView(onCreated: _refresh);
          return _FamilyView(family: family, onUpdated: _refresh);
        },
      ),
    );
  }
}

// ── No Family ──────────────────────────────────────────────────────────────────

class _NoFamilyView extends StatefulWidget {
  final VoidCallback onCreated;
  const _NoFamilyView({required this.onCreated});

  @override
  State<_NoFamilyView> createState() => _NoFamilyViewState();
}

class _NoFamilyViewState extends State<_NoFamilyView> {
  bool _creating = false;

  Future<void> _create() async {
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          AppStrings.get('create_family', lang),
          style: TextStyle(color: scheme.onSurface),
        ),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: AppStrings.get('family_name_hint', lang),
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: scheme.outline),
            ),
            fillColor: scheme.surface,
            filled: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppStrings.get('cancel', lang),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen(
                Theme.of(context).brightness,
              ),
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('create_family', lang)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _creating = true);
    try {
      await FamilyService.createFamily(name);
      if (mounted) widget.onCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.group_add,
                size: 44,
                color: AppColors.primaryGreen(Theme.of(context).brightness),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.get('no_family_yet', currentLanguage.value),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.get('no_family_desc', currentLanguage.value),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(AppStrings.get('create_family', currentLanguage.value)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen(
                    Theme.of(context).brightness,
                  ),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Has Family ─────────────────────────────────────────────────────────────────

class _FamilyView extends StatefulWidget {
  final Family family;
  final VoidCallback onUpdated;
  const _FamilyView({required this.family, required this.onUpdated});

  @override
  State<_FamilyView> createState() => _FamilyViewState();
}

class _FamilyViewState extends State<_FamilyView> {
  late Future<List<FamilyMember>> _membersFuture;
  late Future<FamilyPeriodSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = FamilyService.fetchMembers(widget.family.id);
    _summaryFuture = _loadSummary();
    homePeriod.addListener(_onHomePeriodChanged);
  }

  @override
  void dispose() {
    homePeriod.removeListener(_onHomePeriodChanged);
    super.dispose();
  }

  void _onHomePeriodChanged() {
    setState(() => _summaryFuture = _loadSummary());
  }

  Future<FamilyPeriodSummary> _loadSummary() {
    final period = homePeriod.value;
    return FamilyService.fetchFamilyPeriodSummary(
      familyId: widget.family.id,
      familyName: widget.family.name,
      month: period.month,
      year: period.year,
    );
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = FamilyService.fetchMembers(widget.family.id);
      _summaryFuture = _loadSummary();
    });
  }

  Future<void> _inviteViaWhatsApp() async {
    final lang = currentLanguage.value;
    try {
      final inviteId = await FamilyService.createInvite(widget.family.id);
      final inviteLink = FamilyInviteLinkService.buildInviteLink(inviteId);
      final msg = Uri.encodeComponent(
        AppStrings.whatsAppInviteMessage(widget.family.name, inviteLink, lang),
      );
      final url = Uri.parse('https://wa.me/?text=$msg');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    final currentUserId = SupabaseAccess.currentUserId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<FamilyPeriodSummary>(
          future: _summaryFuture,
          builder: (context, summarySnap) {
            if (summarySnap.connectionState == ConnectionState.waiting &&
                !summarySnap.hasData) {
              return const SizedBox(
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              );
            }
            final summary = summarySnap.data;
            if (summary == null) return const SizedBox.shrink();
            return FamilyBudgetHeaderCard(
              summary: summary,
              onPeriodChanged: (m, y) =>
                  homePeriod.value = HomePeriod(month: m, year: y),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _inviteViaWhatsApp,
          icon: const Icon(Icons.share, size: 18),
          label: Text(AppStrings.get('invite_whatsapp', lang)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreen(Theme.of(context).brightness),
            side: BorderSide(color: scheme.outline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.get('members', lang),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<FamilyMember>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final members = snapshot.data ?? [];
            FamilyMember? myMember;
            for (final m in members) {
              if (m.userId == currentUserId) {
                myMember = m;
                break;
              }
            }
            final myRole = myMember?.role ?? 'member';
            return Column(
              children: members
                  .map(
                    (m) => _MemberCard(
                      member: m,
                      myRole: myRole,
                      currentUserId: currentUserId,
                      onUpdated: _refreshMembers,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: scheme.surfaceContainerHigh,
                title: Text(
                  AppStrings.get('leave_family', lang),
                  style: TextStyle(color: scheme.onSurface),
                ),
                content: Text(
                  AppStrings.get('leave_family_confirm', lang),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      AppStrings.get('cancel', lang),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      AppStrings.get('leave', lang),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              await FamilyService.leaveFamily(widget.family.id);
              widget.onUpdated();
            }
          },
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label: Text(
            AppStrings.get('leave_family', lang),
            style: const TextStyle(color: Colors.red),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  final String myRole;
  final String? currentUserId;
  final VoidCallback onUpdated;

  const _MemberCard({
    required this.member,
    required this.myRole,
    required this.currentUserId,
    required this.onUpdated,
  });

  bool get _isSelf => member.userId == currentUserId;
  bool get _canManageMembers =>
      myRole == 'admin' || myRole == 'co_admin';

  Future<void> _pickRelationship(BuildContext context) async {
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    final canEdit = _isSelf || _canManageMembers;
    if (!canEdit) return;

    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppStrings.get('family_relationship_label', lang),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  AppStrings.get('family_relationship_unset', lang),
                  style: TextStyle(color: scheme.onSurface),
                ),
                trailing: member.relationship == null
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ...AppStrings.familyRelationshipKeys.map(
                (key) => ListTile(
                  title: Text(
                    AppStrings.get('family_relationship_$key', lang),
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  trailing: member.relationship == key
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, key),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !context.mounted) return;
    try {
      await FamilyService.updateMemberRelationship(
        member.id,
        selected.isEmpty ? null : selected,
      );
      onUpdated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _setSpendLimit(BuildContext context) async {
    if (member.isSpendLimitLocked(DateTime.now())) return;

    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    final ctrl = TextEditingController(
      text: member.spendLimit?.toStringAsFixed(2) ?? '',
    );
    final amountText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          AppStrings.get('set_spend_limit', lang),
          style: TextStyle(color: scheme.onSurface),
        ),
        content: DecimalTextField(
          controller: ctrl,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            labelText: AppStrings.get('spend_limit', lang),
            labelStyle: TextStyle(color: scheme.onSurfaceVariant),
            suffixText: 'AZN',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppStrings.get('cancel', lang),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen(
                Theme.of(context).brightness,
              ),
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('save', lang)),
          ),
        ],
      ),
    );
    if (amountText == null || amountText.isEmpty || !context.mounted) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) return;

    try {
      if (_isSelf) {
        await FamilyService.proposeSpendLimit(member.id, amount);
      } else {
        final current = member.spendLimit;
        // Reductions (or first-time limits) require member confirmation.
        if (current == null || amount < current) {
          await FamilyService.proposeSpendLimit(member.id, amount);
        } else if (amount > current) {
          await FamilyService.applySpendLimitTopUp(member.id, amount - current);
        }
      }
      onUpdated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _confirmSpendLimit(BuildContext context) async {
    try {
      await FamilyService.confirmSpendLimit(member.id);
      onUpdated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    final canEditRelationship = _isSelf || _canManageMembers;
    final canSetLimit = (_isSelf || (_canManageMembers && !_isSelf)) &&
        !member.isSpendLimitLocked(DateTime.now());
    final spendLimitLocked = member.isSpendLimitLocked(DateTime.now());
    final hasPendingLimit =
        _isSelf && member.pendingSpendLimit != null;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.surface,
                    child: Text(
                      member.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primaryGreen(Theme.of(context).brightness),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _RoleBadge(role: member.role),
                            if (canEditRelationship)
                              InkWell(
                                onTap: () => _pickRelationship(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppStrings.familyRelationship(
                                          member.relationship,
                                          lang,
                                        ),
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 14,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Text(
                                AppStrings.familyRelationship(
                                  member.relationship,
                                  lang,
                                ),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (member.role != 'admin' && _canManageMembers)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () async {
                        await FamilyService.removeMember(member.id);
                        onUpdated();
                      },
                    )
                  else if (member.role == 'admin')
                    Tooltip(
                      message: AppStrings.get('family_admin_badge_hint', lang),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.star,
                          color: Color(0xFFFFB300),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
              if (member.spendLimit != null || canSetLimit) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (member.spendLimit != null)
                      Expanded(
                        child: Text(
                          '${AppStrings.get('spend_limit', lang)}: ${member.spendLimit!.toStringAsFixed(2)} AZN',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (canSetLimit)
                      TextButton.icon(
                        onPressed: () => _setSpendLimit(context),
                        icon: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: AppColors.primaryGreen(
                            Theme.of(context).brightness,
                          ),
                        ),
                        label: Text(AppStrings.get('set_spend_limit', lang)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen(
                            Theme.of(context).brightness,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ],
              if (spendLimitLocked && member.spendLimit != null) ...[
                const SizedBox(height: 4),
                Text(
                  AppStrings.get('spend_limit_locked_reason', lang),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (hasPendingLimit) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('spend_limit_proposed_hint', lang),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.spendLimitPending(
                          member.pendingSpendLimit!.toStringAsFixed(2),
                          lang,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _confirmSpendLimit(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen(
                              Theme.of(context).brightness,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(AppStrings.get('spend_limit_confirm', lang)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    final isCoAdmin = role == 'co_admin';
    final bg = isAdmin
        ? AppColors.primaryGreen(Theme.of(context).brightness).withValues(alpha: 0.15)
        : isCoAdmin
            ? scheme.primaryContainer
            : scheme.surface;
    final fg = isAdmin
        ? AppColors.primaryGreen(Theme.of(context).brightness)
        : isCoAdmin
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAdmin || isCoAdmin
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
      ),
      child: Text(
        AppStrings.familyRole(role, lang),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
