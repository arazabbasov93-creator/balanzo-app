import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/analytics_service.dart';
import '../services/subscription_service.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _loading = false;
  SubscriptionTier _selected = SubscriptionTier.aiPremium;
  bool _aiAnnual = true;
  bool _familyAnnual = true;

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    AnalyticsService.log('upgrade_screen_viewed');
  }

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() => setState(() {});

  Future<void> _upgrade() async {
    setState(() => _loading = true);
    try {
      await SubscriptionService.upgradeTo(_selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('upgrade_success', currentLanguage.value)),
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.get('upgrade_screen_title', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.get('upgrade_hero_title', lang),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.get('upgrade_hero_subtitle', lang),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.get('upgrade_choose_plan', lang),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
            ),
            const SizedBox(height: 12),
            _FreePlanCard(
              lang: lang,
              selected: _selected == SubscriptionTier.free,
              onTap: () => setState(() => _selected = SubscriptionTier.free),
            ),
            const SizedBox(height: 10),
            _PaidPlanCard(
              title: AppStrings.get('ai_premium', lang),
              color: const Color(0xFF1B5E20),
              badge: AppStrings.get('upgrade_most_popular', lang),
              featureColor: const Color(0xFF212121),
              features: AppStrings.upgradeAiPremiumFeatures(lang),
              monthlyPrice: SubscriptionService.aiPremiumMonthly,
              annualPrice: SubscriptionService.aiPremiumAnnual,
              isAnnual: _aiAnnual,
              onToggle: (annual) => setState(() => _aiAnnual = annual),
              selected: _selected == SubscriptionTier.aiPremium,
              onTap: () => setState(() => _selected = SubscriptionTier.aiPremium),
              lang: lang,
            ),
            const SizedBox(height: 10),
            _PaidPlanCard(
              title: AppStrings.get('family_plan', lang),
              color: const Color(0xFF1B5E20),
              featureColor: const Color(0xFF212121),
              features: AppStrings.upgradeFamilyFeatures(lang),
              monthlyPrice: SubscriptionService.familyPlanMonthly,
              annualPrice: SubscriptionService.familyPlanAnnual,
              isAnnual: _familyAnnual,
              onToggle: (annual) => setState(() => _familyAnnual = annual),
              selected: _selected == SubscriptionTier.familyPlan,
              onTap: () => setState(() => _selected = SubscriptionTier.familyPlan),
              lang: lang,
            ),
            const SizedBox(height: 28),
            if (_selected != SubscriptionTier.free)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _upgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          AppStrings.get('upgrade_now', lang),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                AppStrings.get('upgrade_cancel_note', lang),
                style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  final String lang;
  final bool selected;
  final VoidCallback onTap;

  const _FreePlanCard({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.grey.shade600 : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('free_plan', lang),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.get('upgrade_free_forever', lang),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  ...AppStrings.upgradeFreeFeatures(lang).map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(f, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? Colors.grey.shade600 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidPlanCard extends StatelessWidget {
  final String title;
  final Color color;
  final String? badge;
  final List<String> features;
  final Color featureColor;
  final double monthlyPrice;
  final double annualPrice;
  final bool isAnnual;
  final ValueChanged<bool> onToggle;
  final bool selected;
  final VoidCallback onTap;
  final String lang;

  const _PaidPlanCard({
    required this.title,
    required this.color,
    this.badge,
    required this.features,
    required this.featureColor,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.isAnnual,
    required this.onToggle,
    required this.selected,
    required this.onTap,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final price = isAnnual
        ? '\$${annualPrice.toStringAsFixed(2)} / ${AppStrings.get('upgrade_annual', lang).toLowerCase()}'
        : '\$${monthlyPrice.toStringAsFixed(2)} / ${AppStrings.get('upgrade_monthly', lang).toLowerCase()}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? color : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _BillingPill(
                  label: AppStrings.get('upgrade_monthly', lang),
                  active: !isAnnual,
                  color: color,
                  onTap: () => onToggle(false),
                ),
                const SizedBox(width: 8),
                _BillingPill(
                  label: AppStrings.get('upgrade_annual', lang),
                  active: isAnnual,
                  color: color,
                  onTap: () => onToggle(true),
                ),
                if (isAnnual) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      AppStrings.get('upgrade_save_16', lang),
                      style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: TextStyle(fontSize: 13, color: featureColor))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _BillingPill extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _BillingPill({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
