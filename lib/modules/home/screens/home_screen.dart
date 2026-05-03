import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mobile_app/core/services/navigation_service.dart';
import 'package:mobile_app/core/widgets/app_shell.dart';
import 'package:mobile_app/modules/home/screens/analytics_screen.dart';
import 'package:mobile_app/modules/home/screens/dashboard_screen.dart';
import 'package:mobile_app/modules/home/screens/mutual_funds_screen.dart';
import 'package:mobile_app/modules/home/screens/transactions_screen.dart';
import 'package:mobile_app/modules/ingestion/screens/sms_management_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = [
    const AnalyticsScreen(),
    const TransactionsScreen(),
    const DashboardScreen(),
    const MutualFundsScreen(),
    const SmsManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nav = context.watch<NavigationProvider>();

    final shellBody = SafeArea(
      child: IndexedStack(index: nav.selectedIndex, children: _screens),
    );

    final shellBottomNav = Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: nav.selectedIndex,
        onDestinationSelected: (int index) {
          if (nav.selectedIndex != index) {
            HapticFeedback.selectionClick();
            nav.setTab(index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Investments',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: 'SMS Guard',
          ),
        ],
      ),
    );

    final shell = WithForegroundTask(
      child: AppShell(
        body: shellBody,
        bottomNavigationBar: shellBottomNav,
      ),
    );

    if (kIsWeb) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border.symmetric(
              vertical: BorderSide(color: theme.dividerColor),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: shell,
        ),
      );
    }

    return shell;
  }
}
