import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/analytic/analytic_screen.dart';
import 'package:personal_financial_management/features/financial_chat/utils/build_chat_catalog.dart';
import 'package:personal_financial_management/features/main/debt/debt_book_screen.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/features/main/widget/main_style.dart';
import 'package:personal_financial_management/features/main/home/home_screen.dart';
import 'package:personal_financial_management/features/main/budget/budget_screen.dart';
import 'package:personal_financial_management/features/notification/notification_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_income.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_spending.dart';
import 'package:personal_financial_management/features/main/profile/profile_screen.dart';
import 'package:personal_financial_management/features/financial_chat/financial_chat_screen.dart';
import 'package:personal_financial_management/features/spending/chat_box/chat_box.dart';
import 'package:personal_financial_management/features/spending/chat_box/services/chat_firebase_adapter.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  int currentTab = 0;
  bool _isMenuOpen = false;
  final GlobalKey<BudgetPageState> budgetKey = GlobalKey<BudgetPageState>();
  final PageStorageBucket bucket = PageStorageBucket();
  final PageController _pageController = PageController();
  late final List<Widget> screens;
  late final AnimationController _menuController;
  late final CurvedAnimation _menuAnimation;

  @override
  void initState() {
    super.initState();
    screens = [
      const HomePage(),
      BudgetPage(key: budgetKey),
      const DebtBookScreen(),
      const ProfilePage(),
    ];
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _menuAnimation.dispose();
    _menuController.dispose();
    super.dispose();
  }


  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      setState(() => _isMenuOpen = true);
      _menuController.forward();
    }
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    setState(() => _isMenuOpen = false);
    _menuController.reverse();
  }

  void _openPage(Widget page) {
    _closeMenu();
    Navigator.of(context).push(createRoute(screen: page));
  }

  void _openFinancialChat() {
    final catalog = buildChatCatalog(
      listType,
          (key) => AppLocalizations.of(context).translate(key),
    );
    _openPage(FinancialChatScreen(categoryCatalog: catalog));
  }

  Future<void> _openAddSpending() async {
    _closeMenu();
    await Navigator.of(
      context,
    ).push(createRoute(screen: const AddSpendingScreen()));
  }

  Future<void> _openAddIncome() async {
    _closeMenu();
    await Navigator.of(
      context,
    ).push(createRoute(screen: const AddIncomeScreen()));
  }


  Future<void> _openAddDebt() async {
    _closeMenu();
    await Navigator.of(
      context,
    ).push(createRoute(screen: DebtEditor(service: DebtFirebase())));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && _isMenuOpen) {
          _closeMenu();
        }
      },
      child: Scaffold(
        backgroundColor: MainStyle.background(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageStorage(
              bucket: bucket,
              child: PageView(
                controller: _pageController,
                physics: _isMenuOpen
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                onPageChanged: (index) {
                  if (currentTab != index) {
                    setState(() => currentTab = index);
                  }
                },
                children: [
                  for (var index = 0; index < screens.length; index++)
                    _KeepAliveTab(key: ValueKey(index), child: screens[index]),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _menuAnimation,
              builder: (context, child) {
                final progress = _menuAnimation.value;
                if (progress == 0) return const SizedBox.shrink();
                return IgnorePointer(
                  ignoring: !_isMenuOpen,
                  child: ExcludeSemantics(
                    excluding: !_isMenuOpen,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _closeMenu,
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: 5 * progress,
                              sigmaY: 5 * progress,
                            ),
                            child: ColoredBox(
                              color: Colors.black.withOpacity(.32 * progress),
                            ),
                          ),
                        ),
                        _buildToolsMenu(progress),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: Semantics(
          button: true,
          label: _isMenuOpen
              ? AppLocalizations.of(context).translate('main_close_shortcuts')
              : AppLocalizations.of(context).translate('main_open_shortcuts'),
          child: FloatingActionButton(
            heroTag: 'main_utilities',
            onPressed: _toggleMenu,
            tooltip: AppLocalizations.of(context).translate('main_shortcuts'),
            elevation: _isMenuOpen ? 8 : 3,
            backgroundColor: MainStyle.cyan,
            foregroundColor: MainStyle.ink,
            shape: CircleBorder(
              side: BorderSide(
                color: MainStyle.teal.withOpacity(.45),
                width: 1.5,
              ),
            ),
            child: Ink(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: MainStyle.gradient,
                shape: BoxShape.circle,
              ),
              child: AnimatedRotation(
                turns: _isMenuOpen ? .25 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    _isMenuOpen ? Icons.close_rounded : Icons.widgets_rounded,
                    key: ValueKey(_isMenuOpen),
                    color: MainStyle.ink,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: MainStyle.card(context),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _tabItem(
                  0,
                  AppLocalizations.of(context).translate('main_home'),
                  const FaIcon(FontAwesomeIcons.house),
                ),
                _tabItem(
                  1,
                  AppLocalizations.of(context).translate('main_budget'),
                  const Icon(Icons.account_balance_wallet_rounded),
                ),
                const SizedBox(width: 64),
                _tabItem(
                  2,
                  AppLocalizations.of(context).translate('main_debt_book'),
                  const Icon(Icons.menu_book_rounded),
                ),
                _tabItem(
                  3,
                  AppLocalizations.of(context).translate('main_account'),
                  const FaIcon(FontAwesomeIcons.user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabItem(int index, String label, Widget icon) {
    final selected = currentTab == index;
    final color = selected
        ? MainStyle.accent(context)
        : MainStyle.muted(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: Material(
            color: selected
                ? MainStyle.accent(context).withOpacity(.1)
                : MainStyle.card(context),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _closeMenu();
                if (currentTab == index) return;
                _pageController.jumpToPage(index);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme(
                      data: IconThemeData(color: color, size: 20),
                      child: icon,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolsMenu(double progress) {
    final tr = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final actions = <_ToolAction>[
      _ToolAction(
        tr.translate('main_analytics'), Icons.bar_chart_rounded,
            () => _openPage(const AnalyticPage()), const Color(0xFF14988F),
      ),
      _ToolAction(
        tr.translate('financial_chat_title'), Icons.question_answer_rounded,
        _openFinancialChat, const Color(0xFF5279D7),
      ),
      _ToolAction(
        tr.translate('financial_secretary_title'), Icons.smart_toy_rounded,
            () => _openPage(ChatBox(onCreateTransaction: ChatFirebaseAdapter.addDraft)),
        const Color(0xFF9271CD),
      ),
      _ToolAction(
        tr.translate('main_notifications'), Icons.notifications_rounded,
            () => _openPage(const NotificationScreen()), const Color(0xFFBD8732),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottom = constraints.maxHeight > 180 ? 42.0 : 8.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 36 * (1 - progress)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.22),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: MainStyle.cyan.withOpacity(.09),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: MainStyle.card(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: MainStyle.cyan.withOpacity(dark ? .18 : .12),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _toolsHeader(),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _createActionButton(
                                            label: tr.translate('main_add_expense'),
                                            icon: Icons.remove_circle_outline_rounded,
                                            onTap: _openAddSpending,
                                            filled: true,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _createActionButton(
                                            label: tr.translate('main_add_income'),
                                            icon: Icons.add_circle_outline_rounded,
                                            onTap: _openAddIncome,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    child: Row(
                                      children: [
                                        Expanded(child: Divider(height: 1, color: MainStyle.muted(context).withOpacity(.12))),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Icon(Icons.apps_rounded, size: 16, color: MainStyle.muted(context).withOpacity(.5)),
                                        ),
                                        Expanded(child: Divider(height: 1, color: MainStyle.muted(context).withOpacity(.12))),
                                      ],
                                    ),
                                  ),
                                  for (var row = 0; row < 2; row++) ...[
                                    if (row > 0) const SizedBox(height: 10),
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (var col = 0; col < 2; col++) ...[
                                            if (col > 0) const SizedBox(width: 10),
                                            Expanded(
                                              child: _revealTool(
                                                progress, row * 2 + col,
                                                _toolTile(actions[row * 2 + col]),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toolsHeader() {
    final tr = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073D43), Color(0xFF116C6B)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24, top: -50,
            child: IgnorePointer(
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MainStyle.cyan.withOpacity(.12), width: 24),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: MainStyle.gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.widgets_rounded, size: 24, color: MainStyle.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr.translate('main_shortcuts'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _closeMenu,
                  tooltip: tr.translate('main_close_shortcuts'),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.12), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revealTool(double progress, int index, Widget child) {
    final value = ((progress - index * .07) / (1 - index * .07)).clamp(0.0, 1.0).toDouble();
    return Opacity(
      opacity: value,
      child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
    );
  }

  Widget _createActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = filled ? MainStyle.ink : MainStyle.accent(context);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: filled ? MainStyle.gradient : null,
            color: filled ? null : MainStyle.accent(context).withOpacity(dark ? .14 : .07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MainStyle.accent(context).withOpacity(.15)),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: foreground, size: 27),
                  const SizedBox(height: 8),
                  Text(
                    label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolTile(_ToolAction action) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Color.lerp(action.color, Colors.white, .3)! : action.color;
    return Tooltip(
      message: action.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint.withOpacity(dark ? .13 : .09), tint.withOpacity(.025)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tint.withOpacity(.16)),
          ),
          child: InkWell(
            onTap: action.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: tint.withOpacity(dark ? .18 : .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(action.icon, color: tint, size: 23),
                      ),
                      const Spacer(),
                      Icon(Icons.north_east_rounded, size: 16, color: tint.withOpacity(.6)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    action.label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: MainStyle.text(context), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({super.key, required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin<_KeepAliveTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ToolAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  final Color color;

  const _ToolAction(this.label, this.icon, this.onTap, this.color);
}
