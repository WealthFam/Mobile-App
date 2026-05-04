import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/core/services/navigation_service.dart';
import 'package:mobile_app/core/widgets/app_shell.dart';
import 'package:mobile_app/modules/home/screens/add_transaction_screen.dart';
import 'package:mobile_app/modules/home/services/dashboard_service.dart';
import 'package:mobile_app/modules/home/widgets/expenses_tab.dart';
import 'package:mobile_app/modules/ingestion/screens/transaction_review_screen.dart';
import 'package:provider/provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = context.read<NavigationProvider>().initialTransactionsTab;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: (initialTab < 2) ? initialTab : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nav = context.read<NavigationProvider>();
    if (_tabController.index != nav.initialTransactionsTab) {
      _tabController.animateTo(nav.initialTransactionsTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final triageCount =
        context.watch<DashboardService>().data?.pendingTriageCount ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(110 + (triageCount > 0 ? 0 : 0)), // Standard TabBar (48) + Avatar Row (60)
          child: Column(
            children: [
              _buildMemberAvatarRow(context),
              TabBar(
                controller: _tabController,
                onTap: (index) {
                  if (_tabController.index != index) {
                    HapticFeedback.selectionClick();
                  }
                },
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  const Tab(text: 'Expenses'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Triage'),
                        if (triageCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              triageCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ExpensesTab(),
          TransactionReviewScreen(isEmbedded: true),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () async {
                final val = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const AppShell(body: AddTransactionScreen()),
                  ),
                );
                if (val == true && context.mounted) {
                  context.read<DashboardService>().refresh();
                }
              },
              backgroundColor: theme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildMemberAvatarRow(BuildContext context) {
    final dashboard = context.watch<DashboardService>();
    final theme = Theme.of(context);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildMemberAvatar(
            context,
            'Family',
            null,
            Icons.groups_outlined,
            dashboard.selectedMemberId == null,
          ),
          ...dashboard.members.map((m) {
            final member = m as Map<String, dynamic>;
            final id = member['id'] as String?;
            final isSelected = dashboard.selectedMemberId == id;
            return _buildMemberAvatar(
              context,
              member['name'] as String,
              id,
              null,
              isSelected,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(
    BuildContext context,
    String name,
    String? id,
    IconData? icon,
    bool isSelected,
  ) {
    final dashboard = context.read<DashboardService>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.lightImpact();
            dashboard.setMember(id);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: icon != null
                    ? Icon(icon, size: 14, color: isSelected ? Colors.white : theme.disabledColor)
                    : Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.disabledColor,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
