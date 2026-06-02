import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../config/anthropic_config.dart';
import '../l10n/app_strings.dart';
import '../services/analytics_service.dart';
import '../services/subscription_service.dart';
import 'upgrade_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

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

  void _onLangChange() => setState(() {});

  Future<void> _init() async {
    final access = await SubscriptionService.checkAiAccess();
    if (!mounted) return;
    setState(() => _access = access);
    _messages.add(_Message(
      text: AppStrings.aiGreeting(currentLanguage.value),
      isUser: false,
    ));
    final prefs = await SharedPreferences.getInstance();
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              style: TextStyle(color: Color(0xFF8888A0), fontSize: 14),
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
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Future<String> _buildContext(int dataWindowDays) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return '';
      final since = DateTime.now().subtract(Duration(days: dataWindowDays));
      final data = await supabase
          .from('receipts')
          .select('store_name, purchase_date, total_amount, vat_amount, receipt_items(name_raw, unit_price, quantity)')
          .eq('user_id', userId)
          .gte('purchase_date', since.toIso8601String())
          .order('purchase_date', ascending: false)
          .limit(30);
      return 'Recent $dataWindowDays-day receipts (up to 30): ${jsonEncode(data)}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _incrementAiUsage() async {
    try {
      final supabase = Supabase.instance.client;
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

  void _showUpgradeSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Free tier includes 1 message per week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Upgrade to Premium for unlimited messages, 90 days of spending history, and full AI insights.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
                },
                child: const Text('Upgrade to Premium', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;

    AnalyticsService.log('ai_question_asked');

    final access = _access;
    if (access != null && !access.allowed) {
      _showUpgradeSheet();
      return;
    }

    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _loading = true;
    });
    _controller.clear();
    _scroll();

    try {
      if (access != null && access.tier == SubscriptionTier.free) {
        await _incrementAiUsage();
      }
      final dataWindowDays = access?.dataWindowDays ?? 7;
      final context = await _buildContext(dataWindowDays);
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': AnthropicConfig.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 512,
          'system': 'You are Balanzo, a personal finance assistant.\n'
              'You help users understand their household spending, track prices, manage budgets, and interpret their receipt and purchase data.\n\n'
              'You ONLY answer questions related to:\n'
              '- Personal spending and budgets\n'
              '- Receipt items, prices and categories\n'
              '- Household expenses and inflation\n'
              '- Restock suggestions and shopping\n'
              '- VAT and savings\n'
              '- Family spending\n\n'
              'If the user asks anything unrelated to personal finance or their spending data, respond with:\n'
              '\'I can only help with questions about your spending and household finances. Try asking about your budget, recent purchases, or price trends.\'\n\n'
              'Always be helpful, concise, and data-driven.\n'
              'Use the spending context provided to give specific answers.\n\n'
              'Always respond in the same language as the user interface. Current language: ${currentLanguage.value.toUpperCase()}. If AZ respond in Azerbaijani. If RU respond in Russian. If EN respond in English.\n'
              'Use AZN (manat) as currency.\n'
              'Here is the user\'s purchase data for context:\n$context',
          'messages': [
            {'role': 'user', 'content': text},
          ],
        }),
      );

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
          }
        });
      } else {
        setState(() => _messages.add(
          _Message(text: 'Sorry, I couldn\'t get a response right now.', isUser: false),
        ));
      }
    } catch (_) {
      setState(() => _messages.add(
        _Message(text: 'Network error. Please try again.', isUser: false),
      ));
    } finally {
      setState(() => _loading = false);
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
        title: Row(
          children: [
            Text(AppStrings.get('ai_assistant', currentLanguage.value), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (!_isPremium && _access != null && _freeQuestionsLeft > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_freeQuestionsLeft free left',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (!_isPremium)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              ),
              child: const Text('Upgrade', style: TextStyle(color: Colors.amber)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Data window banner for free users
          if (_access != null && !_isPremium)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF18181C),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber.shade300),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Seeing last ${_access!.dataWindowDays} days · Get Premium',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade300),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                    ),
                    child: Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Upgrade banner when free limit reached
          if (!_isPremium && _access != null && _freeQuestionsLeft == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1B5E20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Free tier: 1 message per week. Upgrade for unlimited.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                    ),
                    child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          // Quick question pills
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickQuestions.map((q) {
                  final accessLoaded = _access != null;
                  final canSend = accessLoaded && _access!.allowed;
                  return Opacity(
                    opacity: accessLoaded ? 1.0 : 0.4,
                    child: GestureDetector(
                      onTap: accessLoaded
                          ? () {
                              if (canSend) {
                                _send(q);
                              } else {
                                _showUpgradeSheet();
                              }
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181C),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.5)),
                        ),
                        child: Text(q, style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50))),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Messages
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20)),
                  ),
                  const SizedBox(width: 8),
                  Text(AppStrings.get('thinking', currentLanguage.value), style: const TextStyle(color: Color(0xFF8888A0), fontSize: 13)),
                ],
              ),
            ),
          // Input
          Container(
            color: const Color(0xFF18181C),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Color(0xFFF2F2F5)),
                    decoration: InputDecoration(
                      hintText: AppStrings.get('ask_spending', currentLanguage.value),
                      hintStyle: const TextStyle(color: Color(0xFF8888A0)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF2C2C34)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2C2C34),
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
                      color: Color(0xFF1B5E20),
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
          color: message.isUser ? const Color(0xFF1B5E20) : const Color(0xFF18181C),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
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
            color: message.isUser ? Colors.white : const Color(0xFFF2F2F5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
