import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_app/core/config/app_config.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/core/widgets/searchable_picker.dart';
import 'package:mobile_app/core/widgets/transaction_settings_sheet.dart';
import 'package:mobile_app/modules/auth/services/auth_service.dart';
import 'package:mobile_app/modules/home/models/dashboard_data.dart';
import 'package:mobile_app/modules/home/models/transaction_category.dart';
import 'package:mobile_app/modules/home/screens/transaction_detail_screen.dart';
import 'package:mobile_app/modules/home/services/categories_service.dart';
import 'package:mobile_app/modules/home/services/dashboard_service.dart';
import 'package:provider/provider.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final List<RecentTransaction> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  String? _selectedCategoryId;
  String? _selectedAccountId;
  List<dynamic> _accounts = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions(reset: true);
    _fetchAccounts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchTransactions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    final dashboard = context.read<DashboardService>();
    final result = await dashboard.fetchAccounts();
    result.fold(
      (failure) => debugPrint('Error fetching accounts: ${failure.message}'),
      (accounts) {
        if (mounted) {
          setState(() => _accounts = accounts);
        }
      },
    );
  }

  Future<void> _fetchTransactions({bool reset = false}) async {
    if (_isLoading || (!reset && !_hasMore)) return;

    if (reset) {
      setState(() {
        _page = 1;
        _hasMore = true;
      });
    }

    setState(() => _isLoading = true);

    final config = context.read<AppConfig>();
    final auth = context.read<AuthService>();
    final dashboard = context.read<DashboardService>();

    final url = Uri.parse('${config.backendUrl}/api/v1/mobile/transactions')
        .replace(
      queryParameters: {
        'page': _page.toString(),
        'page_size': '20',
        if (dashboard.selectedMonth != null)
          'month': dashboard.selectedMonth.toString(),
        if (dashboard.selectedYear != null)
          'year': dashboard.selectedYear.toString(),
        if (dashboard.selectedMemberId != null)
          'member_id': dashboard.selectedMemberId,
        if (_selectedCategoryId != null) 'category': _selectedCategoryId,
        if (_selectedAccountId != null) 'account_id': _selectedAccountId,
      },
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${auth.accessToken}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['data'] as List<dynamic>? ?? [])
            .map((i) => RecentTransaction.fromJson(i as Map<String, dynamic>))
            .where((t) => !t.isHidden)
            .toList();
        final dynamic nextPage = data['next_page'];

        if (mounted) {
          setState(() {
            if (reset) _transactions.clear();
            _transactions.addAll(items);
            _hasMore = nextPage != null;
            _page++;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMonthPicker() async {
    final dashboard = context.read<DashboardService>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        dashboard.selectedYear ?? DateTime.now().year,
        dashboard.selectedMonth ?? DateTime.now().month,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      dashboard.setMonth(picked.month, picked.year);
      _fetchTransactions(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardService>();
    final categories = context.watch<CategoriesService>().categories;

    return Column(
      children: [
        _buildFilterBar(dashboard, categories),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await dashboard.refresh();
              await _fetchTransactions(reset: true);
            },
            child: _transactions.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _transactions.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _transactions.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildTransactionItem(_transactions[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(DashboardService dashboard, List<dynamic> categories) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: DateFormat('MMM yyyy').format(
                DateTime(
                  dashboard.selectedYear ?? DateTime.now().year,
                  dashboard.selectedMonth ?? DateTime.now().month,
                ),
              ),
              icon: Icons.calendar_today,
              onTap: _showMonthPicker,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: dashboard.selectedMemberId != null
                  ? (dashboard.members.firstWhere(
                      (m) => (m as Map<String, dynamic>)['id'] == dashboard.selectedMemberId,
                      orElse: () => {'name': 'Member'}) as Map<String, dynamic>)['name'] as String
                  : 'Family',
              icon: Icons.people_outline,
              onTap: () => _showMemberPicker(dashboard),
              isActive: dashboard.selectedMemberId != null,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _selectedCategoryId ?? 'Category',
              icon: Icons.category_outlined,
              onTap: () => _showCategoryPicker(categories),
              isActive: _selectedCategoryId != null,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _selectedAccountId != null
                  ? ((_accounts.firstWhere(
                      (a) => (a as Map<String, dynamic>)['id'] == _selectedAccountId,
                      orElse: () => {'name': 'Account'}) as Map<String, dynamic>)['name'] as String)
                  : 'Account',
              icon: Icons.account_balance_outlined,
              onTap: _showAccountPicker(),
              isActive: _selectedAccountId != null,
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberPicker(DashboardService dashboard) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Full Family'),
            onTap: () {
              dashboard.setMember(null);
              Navigator.pop(context);
              _fetchTransactions(reset: true);
            },
          ),
          ...dashboard.members.map((m) {
            final member = m as Map<String, dynamic>;
            return ListTile(
                title: Text(member['name'] as String),
                onTap: () {
                  dashboard.setMember(member['id'] as String?);
                  Navigator.pop(context);
                  _fetchTransactions(reset: true);
                },
              );
          }),
        ],
      ),
    );
  }

  void _showCategoryPicker(List<dynamic> categories) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchablePickerModal(
        title: 'Select Category',
        items: categories,
        labelMapper: (c) => (c as TransactionCategory).name,
        onSelected: (val) {
          setState(() => _selectedCategoryId = (val as TransactionCategory).name);
          _fetchTransactions(reset: true);
        },
      ),
    );
  }

  VoidCallback _showAccountPicker() {
    return () {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SearchablePickerModal(
          title: 'Select Account',
          items: _accounts,
          labelMapper: (a) => (a as Map<String, dynamic>)['name'] as String,
          onSelected: (val) {
            final account = val as Map<String, dynamic>;
            setState(() => _selectedAccountId = account['id'] as String);
            _fetchTransactions(reset: true);
          },
        ),
      );
    };
  }

  Widget _buildTransactionItem(RecentTransaction txn) {
    final dashboard = context.read<DashboardService>();
    final isNegative = txn.amount < Decimal.zero;
    final currency = dashboard.currencySymbol;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailScreen(transaction: txn),
          ),
        ),
        onLongPress: () => TransactionSettingsSheet.show(context, txn),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Text(
            txn.category.isNotEmpty ? txn.category[0].toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          txn.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${txn.accountName} • ${txn.formattedDate}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Text(
          '$currency${(txn.amount.abs().toDouble() / dashboard.maskingFactor).toStringAsFixed(0)}',
          style: TextStyle(
            color: isNegative ? AppTheme.danger : AppTheme.success,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No transactions found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const Text('Try adjusting your filters', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withValues(alpha: 0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.primary : theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppTheme.primary : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppTheme.primary : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
