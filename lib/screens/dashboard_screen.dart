import 'dart:async';

import 'package:flutter/material.dart';
import '../diag_log.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/family_service.dart';
import '../services/category_service.dart';
import '../services/home_data_cache.dart';
import '../services/user_profile_service.dart';
import '../widgets/add_receipt_sheet.dart';
import '../widgets/home/home_greeting_card.dart';
import '../widgets/home/home_scope_page.dart';
import 'receipts_screen.dart';
import 'restock_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/family_invite_link_service.dart';
import '../config/app_colors.dart';
import '../widgets/balanzo_header_styles.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  final _loadedTabs = {0};
  final _homeTabKey = GlobalKey<_HomeTabState>();

  @override
  void initState() {
    super.initState();
    diag('Dashboard.initState tab=$_tab');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(FamilyInviteLinkService.tryConsumePendingInvite());
    });
  }

  Widget? _tabWidget(int index) {
    switch (index) {
      case 0:
        return _HomeTab(key: _homeTabKey);
      case 1:
        return ReceiptsScreen(isActive: _tab == 1);
      case 2:
        return const RestockScreen();
      case 3:
        return AiChatScreen(onBack: () => setState(() => _tab = 0));
      case 4:
        return const ProfileScreen();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: List.generate(5, (i) {
          if (!_loadedTabs.contains(i)) return const SizedBox.shrink();
          return _tabWidget(i) ?? const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: ValueListenableBuilder<String>(
        valueListenable: currentLanguage,
        builder: (context2, lang, child2) => NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() {
            _tab = i;
            _loadedTabs.add(i);
          }),
          backgroundColor: Theme.of(context2).colorScheme.surfaceContainerHighest,
          indicatorColor: AppColors.primaryGreenDark,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined, color: AppColors.darkOnSurfaceVariant),
              selectedIcon: const Icon(Icons.home, color: Colors.white),
              label: AppStrings.get('nav_home', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined, color: AppColors.darkOnSurfaceVariant),
              selectedIcon: const Icon(Icons.receipt_long, color: Colors.white),
              label: AppStrings.get('nav_receipts', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.darkOnSurfaceVariant),
              selectedIcon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: AppStrings.get('nav_restock', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.smart_toy_outlined, color: AppColors.darkOnSurfaceVariant),
              selectedIcon: const Icon(Icons.smart_toy, color: Colors.white),
              label: AppStrings.get('nav_ai', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline, color: AppColors.darkOnSurfaceVariant),
              selectedIcon: const Icon(Icons.person, color: Colors.white),
              label: AppStrings.get('nav_profile', lang),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  late TabController _scopeTabCtrl;
  late int _periodMonth;
  late int _periodYear;
  int _scopeIndex = 0;
  bool _hasFamily = false;
  HomeHeaderSnapshot _headerPersonal = (
    insights: null,
    incomeTotal: 0.0,
    cachedName: null,
    periodSelectorEnabled: true,
    noFamily: false,
    familyName: null,
  );
  HomeHeaderSnapshot _headerFamily = (
    insights: null,
    incomeTotal: 0.0,
    cachedName: null,
    periodSelectorEnabled: false,
    noFamily: false,
    familyName: null,
  );

  @override
  void initState() {
    super.initState();
    diag('HomeTab.initState');
    UserProfileService.warmCache();
    UserProfileService.loadFullName();
    CategoryService.refreshCache();
    HomeDataCache.ensureRows(false);
    final now = DateTime.now();
    _periodMonth = now.month;
    _periodYear = now.year;
    homePeriod.value = HomePeriod(month: _periodMonth, year: _periodYear);
    _scopeTabCtrl = TabController(length: 2, vsync: this);
    _scopeTabCtrl.addListener(_onScopeTabChanged);
    homePeriod.addListener(_onGlobalPeriodChanged);
    _refreshFamilyStatus();
  }

  void _onGlobalPeriodChanged() {
    final p = homePeriod.value;
    if (_periodMonth == p.month && _periodYear == p.year) return;
    setState(() {
      _periodMonth = p.month;
      _periodYear = p.year;
    });
  }

  void _onScopeTabChanged() {
    if (_scopeTabCtrl.indexIsChanging) return;
    setState(() => _scopeIndex = _scopeTabCtrl.index);
  }

  Future<void> _refreshFamilyStatus() async {
    final family = await FamilyService.fetchMyFamily();
    if (mounted) setState(() => _hasFamily = family != null);
  }

  @override
  void dispose() {
    homePeriod.removeListener(_onGlobalPeriodChanged);
    _scopeTabCtrl.removeListener(_onScopeTabChanged);
    _scopeTabCtrl.dispose();
    super.dispose();
  }

  void refresh() => _refreshFamilyStatus();

  bool get _canScanReceipt => _scopeIndex == 0 || _hasFamily;

  void _onPeriodChanged(int month, int year) {
    homePeriod.value = HomePeriod(month: month, year: year);
    setState(() {
      _periodMonth = month;
      _periodYear = year;
    });
  }

  void _onHeaderUpdate(int scopeIndex, HomeHeaderSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      if (scopeIndex == 0) {
        _headerPersonal = snapshot;
      } else {
        _headerFamily = snapshot;
      }
    });
  }

  HomeHeaderSnapshot get _activeHeader =>
      _scopeIndex == 0 ? _headerPersonal : _headerFamily;

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final user = AuthService.currentUser;
    final identity = user?.phone ?? user?.email ?? 'User';
    final header = _activeHeader;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen(Theme.of(context).brightness),
                  AppColors.gradientEnd(Theme.of(context).brightness),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: BalanzoHeaderStyles.toolbarHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Balanzo',
                              style: BalanzoHeaderStyles.titleStyle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        _NotificationBellButton(lang: lang),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _scopeTabCtrl,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: BalanzoHeaderStyles.tabLabelStyle,
                    unselectedLabelStyle:
                        BalanzoHeaderStyles.tabUnselectedLabelStyle,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: [
                      Tab(text: AppStrings.get('tab_personal', lang)),
                      Tab(text: AppStrings.get('tab_family', lang)),
                    ],
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: cachedDisplayName,
                    builder: (context, cached, _) {
                      if (_scopeIndex == 1) {
                        return const SizedBox.shrink();
                      }
                      return HomeGreetingCard(
                        identity: identity,
                        insights: header.insights,
                        incomeTotal: header.incomeTotal,
                        cachedName: cached ?? header.cachedName,
                        familyName: null,
                        periodMonth: _periodMonth,
                        periodYear: _periodYear,
                        onPeriodChanged: _onPeriodChanged,
                        periodSelectorEnabled: header.periodSelectorEnabled,
                        attachedToHeader: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _scopeTabCtrl,
              children: [
                HomeScopePage(
                  key: const ValueKey('home-personal'),
                  scopeIndex: 0,
                  periodMonth: _periodMonth,
                  periodYear: _periodYear,
                  onPeriodChanged: _onPeriodChanged,
                  onGlobalRefresh: refresh,
                  hasFamily: _hasFamily,
                  isActive: _scopeIndex == 0,
                  embedGreeting: false,
                  onHeaderUpdate: (s) => _onHeaderUpdate(0, s),
                ),
                HomeScopePage(
                  key: const ValueKey('home-family'),
                  scopeIndex: 1,
                  periodMonth: _periodMonth,
                  periodYear: _periodYear,
                  onPeriodChanged: _onPeriodChanged,
                  onGlobalRefresh: refresh,
                  onFamilyStatusChanged: _refreshFamilyStatus,
                  hasFamily: _hasFamily,
                  isActive: _scopeIndex == 1,
                  embedGreeting: false,
                  onHeaderUpdate: (s) => _onHeaderUpdate(1, s),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _canScanReceipt
          ? FloatingActionButton.extended(
              heroTag: 'fab_home_add_receipt',
              backgroundColor: AppColors.primaryGreen(Theme.of(context).brightness),
              onPressed: () => showAddReceiptSheet(context, onDone: refresh),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                AppStrings.get('add_receipt', lang),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

class _NotificationBellButton extends StatefulWidget {
  final String lang;
  const _NotificationBellButton({required this.lang});

  @override
  State<_NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NotificationService.unreadCount();
    if (mounted) setState(() => _count = items);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text(_count > 99 ? '99+' : '$_count'),
        child: const Icon(Icons.notifications_outlined, color: Colors.white),
      ),
      tooltip: AppStrings.get('notifications', widget.lang),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        _load();
      },
    );
  }
}
