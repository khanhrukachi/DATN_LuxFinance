import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_spending.dart';

import 'package:personal_financial_management/features/main/analytic/analytic_screen.dart';
import 'package:personal_financial_management/features/main/budget/budget_screen.dart';
import 'package:personal_financial_management/features/main/home/home_screen.dart';
import 'package:personal_financial_management/features/main/profile/profile_screen.dart';

import 'package:personal_financial_management/features/main/widget/item_bottom_tab.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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

      floatingActionButton: FloatingActionButton(
        elevation: 6,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 30,
        ),
        onPressed: () async {
          if (currentTab == 1) {
            final result = await Navigator.of(context).push(
              createRoute(screen: const AddBudgetPage()),
            );

            if (result == true) {
              budgetKey.currentState?.fetchBudgets();
            }
          } else {
            await Navigator.of(context).push(
              createRoute(screen: const AddSpendingPage()),
            );
          }
        },

      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

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
                icon: FontAwesomeIcons.house,
              ),
              _tabItem(
                index: 1,
                text: AppLocalizations.of(context).translate('budget'),
                icon: Icons.menu_book,
              ),

              const Expanded(child: SizedBox()),

              _tabItem(
                index: 2,
                text: AppLocalizations.of(context).translate('analytic'),
                icon: FontAwesomeIcons.chartPie,
              ),
              _tabItem(
                index: 3,
                text: AppLocalizations.of(context).translate('account'),
                icon: FontAwesomeIcons.user,
                activeIcon: FontAwesomeIcons.userLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabItem({
    required int index,
    required String text,
    required IconData icon,
    IconData? activeIcon,
    double iconSize = 24,
    double textSize = 12,
  }) {
    return Expanded(
      child: Center(
        child: itemBottomTab(
          text: text,
          index: index,
          current: currentTab,
          icon: icon,
          activeIcon: activeIcon,
          iconSize: iconSize,
          textSize: textSize,
          action: () => setState(() => currentTab = index),
        ),
      ),
    );
  }

  Future pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        setState(() => this.image = image);
      }
    } on PlatformException catch (_) {}
  }
}
