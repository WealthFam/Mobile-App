import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/core/services/navigation_service.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/modules/auth/services/auth_service.dart';
import 'package:mobile_app/modules/config/screens/sync_settings_screen.dart';
import 'package:mobile_app/modules/home/screens/analytics_screen.dart';
import 'package:mobile_app/modules/home/screens/categories_management_screen.dart';
import 'package:mobile_app/modules/home/screens/expense_groups_screen.dart';
import 'package:mobile_app/modules/home/screens/goals_screen.dart';
import 'package:mobile_app/modules/home/screens/mutual_funds_screen.dart';
import 'package:mobile_app/modules/home/screens/transactions_screen.dart';
import 'package:mobile_app/modules/home/services/dashboard_service.dart';
import 'package:mobile_app/modules/ingestion/screens/sms_management_screen.dart';
import 'package:mobile_app/modules/vault/screens/vault_screen.dart';
import 'package:provider/provider.dart';

/// Global key logic removed in favor of Provider.

/// Wraps the screen body with the global drawer scaffold.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.body, 
    super.key,
    this.appBar,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Provider<GlobalKey<ScaffoldState>>.value(
      value: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
        appBar: widget.appBar,
        drawer: const AppDrawer(),
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomNavigationBar,
      ),
    );
  }
}

/// Hamburger button that opens the NEAREST scaffold's drawer.
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Menu',
      onPressed: () {
        // First try finding the scaffold from the global key provider
        final key = context.read<GlobalKey<ScaffoldState>?>();
        if (key?.currentState != null) {
          key!.currentState!.openDrawer();
          return;
        }

        // Fallback to the nearest scaffold in the context
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        } else {
          // If no local drawer, try finding a root scaffold
          context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
        }
      },
    );
  }
}

/// Public reusable drawer widget.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, String viewName, Widget screen, {int? tabIndex}) {
    final nav = context.read<NavigationProvider>();
    HapticFeedback.selectionClick();
    Navigator.pop(context); // Close drawer
    
    if (tabIndex != null) {
      nav.setTab(tabIndex, viewName: viewName);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      nav.setView(viewName);
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AppShell(body: screen),
        ),
      );
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out from WealthFam?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              context.read<AuthService>().logout();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final dashboard = context.watch<DashboardService>();
    final nav = context.watch<NavigationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: theme.primaryColor.withValues(alpha: 0.8),
          letterSpacing: 1.2,
        ),
      ),
    );

    Widget item(IconData icon, String label, Widget screen, {int? tabIndex}) {
      final isActive = nav.currentView == label;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          leading: Icon(
            icon, 
            color: isActive ? theme.primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
              color: isActive ? theme.primaryColor : (isDark ? Colors.grey[300] : Colors.grey[800]),
              fontSize: 14,
            ),
          ),
          selected: isActive,
          selectedTileColor: theme.primaryColor.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: () => _navigate(context, label, screen, tabIndex: tabIndex),
        ),
      );
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // Glassmorphism Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: isDark 
                  ? Colors.black.withValues(alpha: 0.7) 
                  : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(context, auth, dashboard, theme),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    section('Personal Hub'),
                    item(
                      Icons.grid_view_rounded,
                      'Dashboard',
                      const SizedBox.shrink(), // Dummy, handled by switchToDashboard
                      tabIndex: 2,
                    ),
                    item(
                      Icons.receipt_long_rounded,
                      'Transactions',
                      const TransactionsScreen(),
                      tabIndex: 1,
                    ),
                    item(
                      Icons.insights_rounded,
                      'Insights',
                      const AnalyticsScreen(),
                      tabIndex: 0,
                    ),
                    item(
                      Icons.security_rounded,
                      'SMS Guard',
                      const SmsManagementScreen(),
                      tabIndex: 4,
                    ),
                    section('Wealth Management'),
                    item(
                      Icons.show_chart_rounded,
                      'Mutual Funds',
                      const MutualFundsScreen(),
                      tabIndex: 3,
                    ),
                    item(
                      Icons.flag_rounded,
                      'Investment Goals',
                      const GoalsScreen(),
                    ),
                    item(
                      Icons.groups_rounded,
                      'Expense Groups',
                      const ExpenseGroupsScreen(),
                    ),
                    section('System Tools'),
                    item(
                      Icons.category_rounded,
                      'Categories',
                      const CategoriesManagementScreen(),
                    ),
                    item(
                      Icons.auto_awesome_motion_rounded,
                      'Vault',
                      const VaultScreen(),
                    ),
                  ],
                ),
              ),
              const Divider(indent: 20, endIndent: 20, height: 1),
              item(
                Icons.settings_rounded,
                'Settings',
                const SyncSettingsScreen(),
              ),
              _buildFooter(context, theme),
            ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthService auth, DashboardService dashboard, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'drawer_avatar',
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: auth.userAvatar != null && auth.userAvatar!.length <= 2
                    ? Text(
                        auth.userAvatar!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.userName ?? 'Family Member',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  auth.userRole?.toUpperCase() ?? 'MEMBER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(),
      ),
      child: ListTile(
        visualDensity: VisualDensity.standard,
        dense: false,
        leading: const Icon(Icons.logout_rounded, color: AppTheme.danger),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            color: AppTheme.danger,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _confirmSignOut(context),
      ),
    );
  }
}
