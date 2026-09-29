import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:personal_financial_management/features/ai_insights/ai_insights_screen.dart';
import 'package:personal_financial_management/features/notification/notification_page.dart';

import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';

import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_spending.dart';

import 'package:personal_financial_management/features/main/analytic/analytic_screen.dart';
import 'package:personal_financial_management/features/main/budget/budget_screen.dart';
import 'package:personal_financial_management/features/main/home/home_screen.dart';
import 'package:personal_financial_management/features/main/profile/profile_screen.dart';

import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentTab = 0;

  final GlobalKey<BudgetPageState> budgetKey =
  GlobalKey<BudgetPageState>();

  late final List<Widget> screens = [
    const HomePage(),
    BudgetPage(key: budgetKey),
    const AnalyticPage(),
    const ProfilePage(),
  ];

  DateTime? currentBackPressTime;

  final PageStorageBucket bucket = PageStorageBucket();

  XFile? image;

  int unreadNotification = 3;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          body: WillPopScope(
            onWillPop: () => onWillPop(
              action: (now) => currentBackPressTime = now,
              currentBackPressTime: currentBackPressTime,
            ),
            child: PageStorage(
              bucket: bucket,
              child: screens[currentTab],
            ),
          ),

          // =========================================================
          // ADD BUTTON
          // =========================================================
          floatingActionButton: FloatingActionButton(
            elevation: 6,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
            ),
            onPressed: () async {
              if (currentTab == 1) {
                final result = await Navigator.of(context).push(
                  createRoute(
                    screen: const AddBudgetPage(),
                  ),
                );

                if (result == true) {
                  budgetKey.currentState?.fetchBudgets();
                }
              } else {
                await Navigator.of(context).push(
                  createRoute(
                    screen: const AddSpendingPage(),
                  ),
                );
              }
            },
          ),

          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,

          // =========================================================
          // BOTTOM NAVIGATION
          // =========================================================
          bottomNavigationBar: BottomAppBar(
            color: isDark
                ? const Color(0xFF121212)
                : Colors.white,
            elevation: 8,
            shape: const CircularNotchedRectangle(),
            notchMargin: 12,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  // HOME
                  _tabItem(
                    index: 0,
                    text: AppLocalizations.of(context)
                        .translate('home'),
                    icon: const FaIcon(
                      FontAwesomeIcons.house,
                    ),
                  ),

                  // BUDGET
                  _tabItem(
                    index: 1,
                    text: AppLocalizations.of(context)
                        .translate('budget'),
                    icon: const Icon(
                      Icons.menu_book,
                    ),
                  ),

                  // Khoảng trống cho FAB ở giữa
                  const Expanded(
                    child: SizedBox(),
                  ),

                  // ANALYTIC
                  _tabItem(
                    index: 2,
                    text: AppLocalizations.of(context)
                        .translate('analytic'),
                    icon: const FaIcon(
                      FontAwesomeIcons.chartPie,
                    ),
                  ),

                  // ACCOUNT
                  _tabItem(
                    index: 3,
                    text: AppLocalizations.of(context)
                        .translate('account'),
                    icon: const FaIcon(
                      FontAwesomeIcons.user,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ===========================================================
        // NOTIFICATION BUTTON
        // ===========================================================
        _floatingButton(
          context,
          bottom: 90,
          icon: Icons.notifications_rounded,
          color: isDark
              ? const Color(0xFF1487FF)
              : const Color(0xFF299BFF),
          onTap: () {
            setState(() {
              unreadNotification = 0;
            });

            Navigator.of(context).push(
              createRoute(
                screen: const NotificationPage(),
              ),
            );
          },
          badge: unreadNotification,
        ),

        // ===========================================================
        // AI INSIGHTS BUTTON
        // ===========================================================
        _floatingButton(
          context,
          bottom: 160,
          icon: Icons.insights,
          gradient: const [
            Color(0xFF7F00FF),
            Color(0xFF3F51B5),
          ],
          onTap: () {
            Navigator.of(context).push(
              createRoute(
                screen: const AiInsightsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===============================================================
  // BOTTOM TAB ITEM
  //
  // Font Awesome 11 sử dụng FaIconData, không còn kế thừa IconData.
  // Vì vậy nhận Widget để dùng được cả Icon và FaIcon.
  // ===============================================================
  Widget _tabItem({
    required int index,
    required String text,
    required Widget icon,
  }) {
    final bool selected = currentTab == index;

    final Color iconColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context)
        .colorScheme
        .onSurface
        .withOpacity(0.55);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            currentTab = index;
          });
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
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // FLOATING BUTTON
  //
  // Các button này đang dùng Icons.xxx của Flutter nên vẫn sử dụng
  // IconData + Icon(), KHÔNG sử dụng FaIcon.
  // ===============================================================
  Widget _floatingButton(
      BuildContext context, {
        required double bottom,
        required IconData icon,
        required VoidCallback onTap,
        Color? color,
        List<Color>? gradient,
        int? badge,
      }) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: bottom,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: gradient == null ? color : null,
                  gradient: gradient != null
                      ? LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        isDark ? 0.45 : 0.25,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                // Material Icons
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              // Badge thông báo
              if (badge != null && badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius:
                      BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}