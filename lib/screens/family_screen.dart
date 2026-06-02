import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../models/family.dart';
import '../services/family_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: Text(AppStrings.get('family', currentLanguage.value), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5))),
        backgroundColor: const Color(0xFF09090B),
        foregroundColor: const Color(0xFFF2F2F5),
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
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Color(0xFF8888A0))),
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
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF18181C),
        title: Text(AppStrings.get('create_family', currentLanguage.value), style: const TextStyle(color: Color(0xFFF2F2F5))),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Color(0xFFF2F2F5)),
          decoration: InputDecoration(
            hintText: 'Family name (e.g. Əliyev family)',
            hintStyle: const TextStyle(color: Color(0xFF8888A0)),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFF2C2C34)),
            ),
            fillColor: const Color(0xFF09090B),
            filled: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.get('cancel', currentLanguage.value), style: const TextStyle(color: Color(0xFF8888A0))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('create_family', currentLanguage.value)),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFF18181C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_add, size: 44, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.get('no_family_yet', currentLanguage.value),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5)),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.get('no_family_desc', currentLanguage.value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8888A0)),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add),
                label: Text(AppStrings.get('create_family', currentLanguage.value)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  double _combinedSpend = 0;
  bool _spendLoaded = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = FamilyService.fetchMembers(widget.family.id);
    _loadCombinedSpend();
  }

  void _refreshMembers() {
    setState(() => _membersFuture = FamilyService.fetchMembers(widget.family.id));
    _loadCombinedSpend();
  }

  Future<void> _loadCombinedSpend() async {
    try {
      final supabase = Supabase.instance.client;
      final members = await FamilyService.fetchMembers(widget.family.id);
      final memberIds = members.map((m) => m.userId).toList();
      if (memberIds.isEmpty) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      double total = 0;
      for (final uid in memberIds) {
        final rows = await supabase
            .from('receipts')
            .select('total_amount')
            .eq('user_id', uid)
            .gte('purchase_date', startOfMonth);
        for (final r in rows as List) {
          total += (r['total_amount'] as num?)?.toDouble() ?? 0;
        }
      }
      if (mounted) setState(() { _combinedSpend = total; _spendLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _spendLoaded = true);
    }
  }

  Future<void> _addMember() async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF18181C),
        title: Text(AppStrings.get('add_member', currentLanguage.value), style: const TextStyle(color: Color(0xFFF2F2F5))),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Color(0xFFF2F2F5)),
          decoration: const InputDecoration(
            hintText: '+994501234567',
            hintStyle: TextStyle(color: Color(0xFF8888A0)),
            border: OutlineInputBorder(),
            labelText: 'Phone number',
            labelStyle: TextStyle(color: Color(0xFF8888A0)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.get('cancel', currentLanguage.value), style: const TextStyle(color: Color(0xFF8888A0))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('add_member', currentLanguage.value)),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty || !mounted) return;
    try {
      await FamilyService.addMemberByPhone(widget.family.id, phone);
      if (mounted) _refreshMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _inviteViaWhatsApp() async {
    final msg = Uri.encodeComponent(
      'Join our family on Balanzo to track shared expenses! Download at https://balanzo.app',
    );
    final url = Uri.parse('https://wa.me/?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Family header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home, color: Colors.white, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.family.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (_spendLoaded) ...[
                const SizedBox(height: 12),
                Text(AppStrings.get('combined_spend', currentLanguage.value), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '${_combinedSpend.toStringAsFixed(2)} AZN',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // WhatsApp invite button
        OutlinedButton.icon(
          onPressed: _inviteViaWhatsApp,
          icon: const Icon(Icons.share, size: 18),
          label: Text(AppStrings.get('invite_whatsapp', currentLanguage.value)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
            side: const BorderSide(color: Color(0xFF2C2C34)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.get('members', currentLanguage.value),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5))),
            TextButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF4CAF50)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<FamilyMember>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final members = snapshot.data ?? [];
            return Column(
              children: members.map((m) => _MemberCard(member: m, onRemoved: _refreshMembers)).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF18181C),
                title: Text(AppStrings.get('leave_family', currentLanguage.value), style: const TextStyle(color: Color(0xFFF2F2F5))),
                content: const Text('Are you sure you want to leave this family?',
                    style: TextStyle(color: Color(0xFF8888A0))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppStrings.get('cancel', currentLanguage.value), style: const TextStyle(color: Color(0xFF8888A0))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(AppStrings.get('leave', currentLanguage.value), style: const TextStyle(color: Colors.red)),
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
          label: Text(AppStrings.get('leave_family', currentLanguage.value), style: const TextStyle(color: Colors.red)),
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
  final VoidCallback onRemoved;
  const _MemberCard({required this.member, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C34)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1E2F1E),
          child: Text(
            member.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member.displayName,
            style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFF2F2F5))),
        subtitle: Text(member.role,
            style: const TextStyle(color: Color(0xFF8888A0), fontSize: 12)),
        trailing: member.role != 'admin'
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () async {
                  await FamilyService.removeMember(member.id);
                  onRemoved();
                },
              )
            : const Icon(Icons.star, color: Color(0xFFFFB300), size: 18),
      ),
    );
  }
}
