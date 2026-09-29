import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';

import 'package:personal_financial_management/features/ai_insights/ai_insights_screen.dart';
import 'package:personal_financial_management/features/notification/notification_page.dart';

import 'package:personal_financial_management/features/main/analytic/analytic_screen.dart';
import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:personal_financial_management/features/main/budget/budget_screen.dart';
import 'package:personal_financial_management/features/main/home/home_screen.dart';
import 'package:personal_financial_management/features/main/profile/profile_screen.dart';

import 'package:personal_financial_management/features/spending/add_spending/add_spending.dart';
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

  // Giữ dữ liệu mẫu từ code cũ.
  // Thay bằng số thông báo chưa đọc thực tế khi kết nối dữ liệu.
  int unreadNotification = 3;

  DateTime? currentBackPressTime;

  final GlobalKey<BudgetPageState> budgetKey =
  GlobalKey<BudgetPageState>();

  final PageStorageBucket bucket = PageStorageBucket();

  late final List<Widget> screens;

  late final AnimationController _menuController;
  late final CurvedAnimation _menuAnimation;

  @override
  void initState() {
    super.initState();

    screens = [
      const HomePage(),
      BudgetPage(key: budgetKey),
      const AnalyticPage(),
      const ProfilePage(),
    ];

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _menuAnimation.dispose();
    _menuController.dispose();
    super.dispose();
  }

  String _t(String vi, String en) {
    return Localizations.localeOf(context).languageCode == 'vi'
        ? vi
        : en;
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
      return;
    }

    setState(() => _isMenuOpen = true);
    _menuController.forward();
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;

    setState(() => _isMenuOpen = false);
    _menuController.reverse();
  }

  Future<bool> _handleBack() async {
    // Nhấn Back lần đầu chỉ đóng menu.
    if (_isMenuOpen) {
      _closeMenu();
      return false;
    }

    return await onWillPop(
      action: (now) => currentBackPressTime = now,
      currentBackPressTime: currentBackPressTime,
    );
  }

  void _openPage(Widget page) {
    _closeMenu();

    Navigator.of(context).push(
      createRoute(screen: page),
    );
  }

  Future<void> _addItem() async {
    _closeMenu();

    if (currentTab == 1) {
      final result = await Navigator.of(context).push(
        createRoute(screen: const AddBudgetPage()),
      );

      if (!mounted) return;

      if (result == true) {
        budgetKey.currentState?.fetchBudgets();
      }
    } else {
      await Navigator.of(context).push(
        createRoute(screen: const AddSpendingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageStorage(
              bucket: bucket,
              child: screens[currentTab],
            ),

            // Lớp nền mờ khi menu mở.
            // Chỉ phủ nội dung, không che thanh điều hướng phía dưới.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isMenuOpen,
                child: FadeTransition(
                  opacity: _menuAnimation,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeMenu,
                    child: ColoredBox(
                      color: Colors.black.withOpacity(
                        isDark ? 0.35 : 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Nút tiện ích và các chức năng bung lên.
            Positioned(
              right: 16,
              bottom: 20,
              child: SafeArea(
                top: false,
                left: false,
                child: _buildQuickMenu(),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'main_add_transaction',
          elevation: 6,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: const CircleBorder(),
          tooltip: currentTab == 1
              ? _t('Thêm ngân sách', 'Add budget')
              : _t('Thêm giao dịch', 'Add transaction'),
          onPressed: _addItem,
          child: const Icon(Icons.add_rounded),
        ),
        floatingActionButtonLocation:
        FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          elevation: 8,
          shape: const CircularNotchedRectangle(),
          notchMargin: 12,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _tabItem(
                  index: 0,
                  text: AppLocalizations.of(context).translate('home'),
                  icon: const FaIcon(FontAwesomeIcons.house),
                ),
                _tabItem(
                  index: 1,
                  text: AppLocalizations.of(context).translate('budget'),
                  icon: const Icon(Icons.menu_book),
                ),
                const Expanded(child: SizedBox()),
                _tabItem(
                  index: 2,
                  text: AppLocalizations.of(context).translate('analytic'),
                  icon: const FaIcon(FontAwesomeIcons.chartPie),
                ),
                _tabItem(
                  index: 3,
                  text: AppLocalizations.of(context).translate('account'),
                  icon: const FaIcon(FontAwesomeIcons.user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabItem({
    required int index,
    required String text,
    required Widget icon,
  }) {
    final theme = Theme.of(context);
    final selected = currentTab == index;

    final iconColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.55);

    return Expanded(
      child: InkWell(
        onTap: () {
          _closeMenu();
          setState(() => currentTab = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: iconColor,
                  size: 20,
                ),
                child: icon,
              ),
              const SizedBox(height: 3),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizeTransition(
          sizeFactor: _menuAnimation,
          axisAlignment: 1,
          child: FadeTransition(
            opacity: _menuAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(_menuAnimation),
              child: IgnorePointer(
                ignoring: !_isMenuOpen,
                child: ExcludeSemantics(
                  excluding: !_isMenuOpen,
                  child: Padding(
                    // Chừa chỗ cho badge và bóng đổ.
                    padding: const EdgeInsets.fromLTRB(8, 8, 0, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _menuAction(
                          label: _t('Thông báo', 'Notifications'),
                          icon: Icons.notifications_rounded,
                          colors: const [
                            Color(0xFF299BFF),
                            Color(0xFF1565C0),
                          ],
                          badge: unreadNotification,
                          onTap: () {
                            setState(() => unreadNotification = 0);
                            _openPage(const NotificationPage());
                          },
                        ),
                        const SizedBox(height: 12),
                        _menuAction(
                          label: _t('Phân tích AI', 'AI insights'),
                          icon: Icons.insights_rounded,
                          colors: const [
                            Color(0xFF8E2DE2),
                            Color(0xFF4A00E0),
                          ],
                          onTap: () {
                            _openPage(const AiInsightsScreen());
                          },
                        ),
                        const SizedBox(height: 12),
                        _menuAction(
                          label: _t(
                            'Trợ lý thu chi',
                            'Finance assistant',
                          ),
                          icon: Icons.smart_toy_rounded,
                          colors: const [
                            Color(0xFF00BFA6),
                            Color(0xFF0072FF),
                          ],
                          onTap: () {
                            _openPage(
                              ChatBox(
                                onCreateTransaction:
                                ChatFirebaseAdapter.addDraft,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Nút duy nhất khi menu đang đóng.
        Material(
          color: Colors.transparent,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(
            isDark ? 0.45 : 0.25,
          ),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00BFA6),
                  Color(0xFF1976D2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: IconButton(
              tooltip: _isMenuOpen
                  ? _t('Đóng tiện ích', 'Close shortcuts')
                  : _t('Mở tiện ích', 'Open shortcuts'),
              onPressed: _toggleMenu,
              icon: AnimatedRotation(
                turns: _isMenuOpen ? 0.25 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    _isMenuOpen
                        ? Icons.close_rounded
                        : Icons.widgets_rounded,
                    key: ValueKey<bool>(_isMenuOpen),
                    color: Colors.white,
                    size: 27,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuAction({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    int? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeCount = badge ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tên chức năng nằm bên trái và có thể nhấn.
        Material(
          color: isDark ? const Color(0xFF252D3A) : Colors.white,
          elevation: 2,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.55,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF263238),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Icon chức năng.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: IconButton(
                  tooltip: label,
                  onPressed: onTap,
                  icon: Icon(
                    icon,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF121212)
                            : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}