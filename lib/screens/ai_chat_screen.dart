import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../services/supabase_access.dart';
import '../config/anthropic_config.dart';
import '../l10n/app_strings.dart';
import '../services/analytics_service.dart';
import '../services/receipt_parser_service.dart';
import '../services/subscription_service.dart';
import '../services/budget_service.dart';
import '../services/income_service.dart';
import '../services/family_service.dart';
import 'upgrade_screen.dart';
import '../config/app_colors.dart';
import '../widgets/balanzo_header_styles.dart';

class AiChatScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AiChatScreen({super.key, this.onBack});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<_Message> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  AiAccessResult? _access;

  List<String> get _quickQuestions => AppStrings.aiQuickQuestions(currentLanguage.value);

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    _init();
  }

  void _onLangChange() {
    if (!mounted) return;
    setState(() {
      if (_messages.isNotEmpty && !_messages.first.isUser) {
        _messages[0] = _Message(
          text: AppStrings.aiGreeting(currentLanguage.value),
          isUser: false,
        );
      }
    });
  }

  Future<void> _init() async {
    final access = await SubscriptionService.checkAiAccess();
    if (!mounted) return;
    setState(() => _access = access);
    _messages.add(_Message(
      text: AppStrings.aiGreeting(currentLanguage.value),
      isUser: false,
    ));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 5));
    if (!mounted) return;
    final alreadyShown = prefs.getBool('milestone_sheet_shown') ?? false;
    if (access.isLoyalUser &&
        access.tier == SubscriptionTier.free &&
        !alreadyShown) {
      await prefs.setBool('milestone_sheet_shown', true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showMilestoneSheet(),
      );
    }
  }

  void _showMilestoneSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text(
              '6-Month Milestone!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'ve been tracking your budget for 6 months. Upgrade to see 30 days of data in AI chat and get unlimited questions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.darkOnSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen(
                    Theme.of(context).brightness,
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Unlock Premium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAzn(double amount) => '${amount.toStringAsFixed(2)} AZN';

  Future<String> _buildContext(int dataWindowDays) async {
    try {
      final supabase = SupabaseAccess.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return '';

      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final buffer = StringBuffer();

      final income = await IncomeService.totalForMonth(month, year);
      final budgets = await BudgetService.fetchForMonth(month, year);
      final spentMap = await BudgetService.spentByCategory(month, year);
      final personalSpent =
          spentMap.values.fold<double>(0, (sum, value) => sum + value);
      final budgetTotal =
          budgets.fold<double>(0, (sum, budget) => sum + budget.amount);

      final incomeStr = income > 0 ? _formatAzn(income) : 'not set';
      final String remainingStr;
      if (income > 0) {
        remainingStr = _formatAzn(income - personalSpent);
      } else if (budgetTotal > 0) {
        remainingStr = _formatAzn(budgetTotal - personalSpent);
      } else {
        remainingStr = 'not set';
      }

      buffer.writeln(
        'Personal budget: $incomeStr, spent: ${_formatAzn(personalSpent)}, remaining: $remainingStr',
      );

      // Privacy: family section uses aggregate totals only (budget + combined spend).
      // FamilyService.fetchFamilyPeriodSummary sums receipt totals server-side;
      // no per-member receipt rows are included in the AI context.
      final family = await FamilyService.fetchMyFamily();
      if (family != null) {
        final summary = await FamilyService.fetchFamilyPeriodSummary(
          familyId: family.id,
          familyName: family.name,
          month: month,
          year: year,
        );
        final familyBudgetStr = summary.hasBudget
            ? _formatAzn(summary.availableBudget)
            : 'not set';
        final familyRemainingStr = summary.hasBudget
            ? _formatAzn(summary.remaining)
            : 'not set';
        buffer.writeln(
          'Family budget (combined): $familyBudgetStr, spent: ${_formatAzn(summary.spent)}, remaining: $familyRemainingStr',
        );
      }

      final since = DateTime.now().subtract(Duration(days: dataWindowDays));
      final data = await supabase
          .from('receipts')
          .select(
            'store_name, purchase_date, total_amount, '
            'receipt_items(name_raw, unit_price, quantity)',
          )
          .eq('user_id', userId)
          .gte('purchase_date', since.toIso8601String())
          .order('purchase_date', ascending: false)
          .limit(30);
      buffer.write('Recent receipts: ${jsonEncode(data)}');

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  String _buildStaticSystemPrompt() {
    final lang = currentLanguage.value.toUpperCase();
    return '''You are Balanzo, the user's personal finance assistant inside the Balanzo app.

You only discuss:
- The user's personal spending, budgets, and income
- Receipt items, prices, and categories
- Household expenses and inflation trends
- Restock and shopping patterns
- Family combined spending and budget (aggregate totals only — you are never given, and must never assume, another family member's individual purchases or spend)

You do not discuss VAT, ƏDV, tax refunds, or government cashback programs in any form, even if asked directly. If asked, give a brief one-line redirect back to general spending help. Do not name VAT/ƏDV as a current, planned, or future feature.

If asked about anything unrelated to personal finance or spending, respond in the current language with a short variant of: "I can only help with questions about your spending and household finances. Try asking about your budget, recent purchases, or price trends."

Behavior rules:
- Never respond with a list of "things I can help with" or a menu of options. Answer the actual question directly and substantively.
- Default analysis period is the current calendar month unless the user names a different period. When no period is specified, give a detailed breakdown: total spend, top categories, notable individual purchases, and comparison against budget/income if available.
- If the user names a specific period (last month, this year, a named month), analyze exactly that period using the data provided.
- Use the conversation history to maintain context. Do not ask the user to repeat information already given earlier in this conversation.
- Never invent words. Never use rare, non-standard, or compound vocabulary you are not certain is correct in the response language. Prefer simple, standard, dictionary-correct words.
- Respond in the same language as the app interface: $lang. AZ = Azerbaijani, RU = Russian, EN = English.
- Use AZN (manat) as the currency.
- Be concise but substantive — lead with specific numbers from the data provided, not generic advice.
- If family aggregate data is included below, you may reference combined family totals. Do not speculate about any individual family member's spending beyond the user's own data.''';
  }

  List<Map<String, String>> _conversationHistoryForApi(String currentText) {
    final history = <Map<String, String>>[];
    var skipLeadingAssistant = true;

    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (skipLeadingAssistant && !message.isUser) continue;
      if (message.isUser) skipLeadingAssistant = false;
      if (i == _messages.length - 1 &&
          message.isUser &&
          message.text == currentText) {
        continue;
      }
      history.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': message.text,
      });
    }

    if (history.length > 10) {
      history.removeRange(0, history.length - 10);
    }
    return history;
  }

  Future<void> _incrementAiUsage() async {
    try {
      final supabase = SupabaseAccess.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final now = DateTime.now();
      final daysFromMonday = (now.weekday - 1) % 7;
      final weekStart = DateTime(now.year, now.month, now.day - daysFromMonday);
      final weekStr = weekStart.toIso8601String().substring(0, 10);
      final used = _access?.questionsUsed ?? 0;
      await supabase.from('ai_usage').upsert({
        'user_id': uid,
        'week_start': weekStr,
        'question_count': used + 1,
      }, onConflict: 'user_id,week_start');
    } catch (_) {}
  }

  bool get _isPremium => _access != null && _access!.tier != SubscriptionTier.free;
  int get _freeQuestionsLeft {
    if (_access == null) return 1;
    return (_access!.questionsLimit - _access!.questionsUsed).clamp(0, _access!.questionsLimit);
  }

  Widget _buildUsageBanner() {
    final lang = currentLanguage.value;
    final access = _access!;
    final brightness = Theme.of(context).brightness;

    if (_isPremium && access.premiumUnlimited) {
      return const SizedBox.shrink();
    }

    if (_isPremium && !access.premiumUnlimited) {
      final limitReached = !access.allowed;
      final message = limitReached
          ? AppStrings.aiPremiumLimitReached(access.monthResetsOn, lang)
          : AppStrings.aiPremiumMessagesLeft(access.premiumMessagesLeft, lang);

      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: limitReached
              ? AppColors.primaryGreen(brightness)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                limitReached ? Icons.lock_outline : Icons.info_outline,
                size: 16,
                color: limitReached ? Colors.white70 : Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: limitReached
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final limitReached = _freeQuestionsLeft == 0;
    final message = limitReached
        ? AppStrings.aiUpgradeLimitReached(lang)
        : AppStrings.aiUpgradeBanner(
            access.dataWindowDays,
            _freeQuestionsLeft,
            lang,
          );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: limitReached
            ? AppColors.primaryGreen(brightness)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              limitReached ? Icons.lock_outline : Icons.info_outline,
              size: 16,
              color: limitReached ? Colors.white70 : Colors.amber.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: limitReached
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppStrings.get('ai_upgrade', lang),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: limitReached ? Colors.white : AppColors.primaryGreenDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeSheet() {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.get('ai_free_limit_title', currentLanguage.value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.get('ai_free_limit_body', currentLanguage.value),
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green400,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
                },
                child: Text(
                  AppStrings.get('upgrade_to_premium', currentLanguage.value),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.get('ai_maybe_later', currentLanguage.value),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumLimitSheet() {
    if (!mounted) return;
    final lang = currentLanguage.value;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.get('ai_premium_limit_title', lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.aiPremiumLimitReached(_access?.monthResetsOn, lang),
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.get('ai_maybe_later', lang),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitSheet() {
    if (_access?.tier == SubscriptionTier.free) {
      _showUpgradeSheet();
    } else {
      _showPremiumLimitSheet();
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;

    AnalyticsService.log('ai_question_asked');

    final access = _access;
    if (access != null && !access.allowed) {
      _showLimitSheet();
      return;
    }

    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _loading = true;
    });
    _controller.clear();
    _scroll();

    try {
      if (!ReceiptParserService.isAvailable) {
        if (!mounted) return;
        setState(() {
          _messages.add(_Message(
            text: AppStrings.get('ai_assistant_unavailable', currentLanguage.value),
            isUser: false,
          ));
          _loading = false;
        });
        _scroll();
        return;
      }

      if (access != null) {
        if (access.tier == SubscriptionTier.free) {
          await _incrementAiUsage();
        } else if (!access.premiumUnlimited) {
          await SubscriptionService.incrementPremiumAiUsage(access.premiumMessagesUsed);
        }
      }
      if (!mounted) return;
      final dataWindowDays = access?.dataWindowDays ?? 7;
      final context = await _buildContext(dataWindowDays);
      final history = _conversationHistoryForApi(text);
      final staticPrompt = _buildStaticSystemPrompt();

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': AnthropicConfig.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 1024,
          'temperature': 0.3,
          'system': [
            {
              'type': 'text',
              'text': staticPrompt,
              'cache_control': {'type': 'ephemeral'},
            },
            {
              'type': 'text',
              'text': "User's financial context:\n$context",
              'cache_control': {'type': 'ephemeral'},
            },
          ],
          'messages': [
            ...history,
            {'role': 'user', 'content': text},
          ],
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final reply = (json['content'] as List).first['text'] as String;
        setState(() {
          _messages.add(_Message(text: reply, isUser: false));
          if (access != null && access.tier == SubscriptionTier.free) {
            _access = AiAccessResult(
              allowed: false,
              tier: access.tier,
              dataWindowDays: access.dataWindowDays,
              questionsUsed: access.questionsUsed + 1,
              questionsLimit: access.questionsLimit,
              isLoyalUser: access.isLoyalUser,
            );
          } else if (access != null &&
              access.tier != SubscriptionTier.free &&
              !access.premiumUnlimited) {
            final used = access.premiumMessagesUsed + 1;
            final limit = access.premiumMessagesLimit;
            _access = AiAccessResult(
              allowed: used < limit,
              tier: access.tier,
              dataWindowDays: access.dataWindowDays,
              premiumMessagesUsed: used,
              premiumMessagesLimit: limit,
              monthResetsOn: access.monthResetsOn,
            );
          }
        });
      } else {
        setState(() => _messages.add(
          _Message(
            text: AppStrings.get('ai_response_error', currentLanguage.value),
            isUser: false,
          ),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(
        _Message(
          text: AppStrings.get('ai_network_error', currentLanguage.value),
          isUser: false,
        ),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scroll();
    }
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: BalanzoHeaderStyles.toolbarHeight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              widget.onBack?.call();
            }
          },
        ),
        title: Text(
          AppStrings.get('ai_assistant', currentLanguage.value),
          style: BalanzoHeaderStyles.titleStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryGreen(Theme.of(context).brightness),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            width: double.infinity,
            color: Colors.black.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              AppStrings.get('ai_disclaimer', currentLanguage.value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_access != null) _buildUsageBanner(),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickQuestions.map((q) {
                  final accessLoaded = _access != null;
                  final canSend = accessLoaded && _access!.allowed;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return GestureDetector(
                    onTap: accessLoaded
                        ? () {
                            if (canSend) {
                              _send(q);
                            } else {
                              _showLimitSheet();
                            }
                          }
                        : () {
                            if (_access != null && !_access!.allowed) {
                              _showLimitSheet();
                            } else {
                              _send(q);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryGreenDark.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        q,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _BubbleTile(message: _messages[i]),
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreenDark),
                  ),
                  const SizedBox(width: 8),
                  Text(AppStrings.get('thinking', currentLanguage.value), style: const TextStyle(color: AppColors.darkOnSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          Container(
            color: AppColors.darkElevated,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.darkOnSurface),
                    decoration: InputDecoration(
                      hintText: AppStrings.get('ask_spending', currentLanguage.value),
                      hintStyle: const TextStyle(color: AppColors.darkOnSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.darkOutline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.green400),
                      ),
                      filled: true,
                      fillColor: AppColors.darkOutline,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      enabled: true,
                    ),
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_controller.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreenDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}

class _BubbleTile extends StatelessWidget {
  final _Message message;
  const _BubbleTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primaryGreenDark : AppColors.darkElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(message.isUser ? 18 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : AppColors.darkOnSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
