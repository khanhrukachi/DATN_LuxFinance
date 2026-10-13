import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/analytic/analytic_screen.dart';
import 'package:personal_financial_management/features/main/debt/debt_book_screen.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/features/main/widget/main_style.dart';
import 'package:personal_financial_management/features/main/home/home_screen.dart';
import 'package:personal_financial_management/features/main/budget/budget_screen.dart';
import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:personal_financial_management/features/notification/notification_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_spending.dart';
import 'package:personal_financial_management/features/main/profile/profile_screen.dart';
import 'package:personal_financial_management/features/financial_chat/financial_chat_screen.dart';
import 'package:personal_financial_management/features/financial_chat/widget/chat_catalog.dart';
import 'package:personal_financial_management/features/spending/chat_box/chat_box.dart';
import 'package:personal_financial_management/features/spending/chat_box/widget/chat_firebase_adapter.dart';
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

  String _t(String vi, String en) =>
      Localizations.localeOf(context).languageCode == 'vi' ? vi : en;

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
    ).push(createRoute(screen: const AddSpendingPage()));
  }

  Future<void> _openAddBudget() async {
    _closeMenu();
    final result = await Navigator.of(
      context,
    ).push(createRoute(screen: const AddBudgetPage()));
    if (!mounted) return;
    if (result == true) {
      budgetKey.currentState?.fetchBudgets();
    }
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
                        _buildArcMenu(progress),
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
              ? _t('Đóng tiện ích', 'Close shortcuts')
              : _t('Mở tiện ích', 'Open shortcuts'),
          child: FloatingActionButton(
            heroTag: 'main_utilities',
            onPressed: _toggleMenu,
            tooltip: _t('Tiện ích', 'Shortcuts'),
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
                turns: _isMenuOpen ? .125 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: const Icon(
                  Icons.widgets_rounded,
                  color: MainStyle.ink,
                  size: 32,
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
                  _t('Trang chủ', 'Home'),
                  const FaIcon(FontAwesomeIcons.house),
                ),
                _tabItem(
                  1,
                  _t('Ngân sách', 'Budget'),
                  const Icon(Icons.account_balance_wallet_rounded),
                ),
                const SizedBox(width: 64),
                _tabItem(
                  2,
                  _t('Sổ nợ', 'Debt book'),
                  const Icon(Icons.menu_book_rounded),
                ),
                _tabItem(
                  3,
                  _t('Tài khoản', 'Account'),
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

  Widget _buildArcMenu(double progress) {
    final actions = <_ArcAction>[
      _ArcAction(
        _t('Phân tích', 'Analytics'),
        Icons.bar_chart_rounded,
        () => _openPage(const AnalyticPage()),
      ),
      _ArcAction(
        _t('Hỏi đáp thu chi', 'Finance Q&A'),
        Icons.question_answer_rounded,
        _openFinancialChat,
      ),
      _ArcAction(
        _t('Trợ lý thu chi', 'Finance assistant'),
        Icons.smart_toy_rounded,
        () => _openPage(
          ChatBox(onCreateTransaction: ChatFirebaseAdapter.addDraft),
        ),
      ),
      _ArcAction(
        _t('Thông báo', 'Notifications'),
        Icons.notifications_rounded,
        () => _openPage(const NotificationScreen()),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tileWidth = math.min(92.0, width * .22);
        final radius = math.min(185.0, width * .36);
        final arcLift = 42.0 * progress;
        // Lift the shortcut arc above the separate create-action row.
        const angles = [158.0, 112.0, 68.0, 22.0];
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ArcGuidePainter(
                    radius: radius,
                    progress: progress,
                    lift: arcLift,
                    color: MainStyle.cyan.withOpacity(.22),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < actions.length; i++)
              Positioned(
                left:
                    width / 2 +
                    math.cos(angles[i] * math.pi / 180) * radius * progress -
                    tileWidth / 2,
                bottom:
                    18 +
                    math.sin(angles[i] * math.pi / 180) * radius * progress -
                    40 +
                    arcLift,
                width: tileWidth,
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: .65 + .35 * progress,
                    child: _arcAction(actions[i]),
                  ),
                ),
              ),
            Positioned(
              left: (width - math.min(150.0, width - 32)) / 2,
              right: (width - math.min(150.0, width - 32)) / 2,
              bottom: 80,
              child: Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - progress)),
                  child: _createActionButton(
                    label: _t('Thêm sổ nợ', 'Add debt'),
                    icon: Icons.menu_book_rounded,
                    onTap: _openAddDebt,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - progress)),
                  child: Row(
                    children: [
                      Expanded(
                        child: _createActionButton(
                          label: _t('Thêm chi tiêu', 'Add expense'),
                          icon: Icons.remove_circle_outline_rounded,
                          onTap: _openAddSpending,
                        ),
                      ),
                      const SizedBox(width: 68),
                      Expanded(
                        child: _createActionButton(
                          label: _t('Thêm ngân sách', 'Add budget'),
                          icon: Icons.add_chart_rounded,
                          onTap: _openAddBudget,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _createActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: MainStyle.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MainStyle.cyan.withOpacity(.3)),
            boxShadow: [
              BoxShadow(
                color: MainStyle.teal.withOpacity(.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: MainStyle.accent(context), size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MainStyle.text(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arcAction(_ArcAction action) {
    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: MainStyle.gradient,
                    border: Border.all(
                      color: Colors.white.withOpacity(.65),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MainStyle.teal.withOpacity(.3),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(action.icon, color: MainStyle.ink, size: 26),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: MainStyle.card(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MainStyle.cyan.withOpacity(.22)),
                  ),
                  child: Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MainStyle.text(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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

class _ArcAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ArcAction(this.label, this.icon, this.onTap);
}

class _ArcGuidePainter extends CustomPainter {
  final double radius, progress, lift;
  final Color color;

  const _ArcGuidePainter({
    required this.radius,
    required this.progress,
    required this.lift,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 18 - lift);
    final paint = Paint()
      ..color = color.withOpacity(color.opacity * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * progress),
      -158 * math.pi / 180,
      136 * math.pi / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGuidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.radius != radius ||
      oldDelegate.lift != lift ||
      oldDelegate.color != color;
}
