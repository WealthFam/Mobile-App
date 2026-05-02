import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 1; // Dashboard
  int _initialTransactionsTab = 0;

  int get selectedIndex => _selectedIndex;
  int get initialTransactionsTab => _initialTransactionsTab;

  void setTab(int index, {int transactionsTab = 0}) {
    _initialTransactionsTab = transactionsTab;
    if (_selectedIndex != index) {
      _selectedIndex = index;
    }
    notifyListeners();
  }

  void switchToDashboard() => setTab(1);
  void switchToInsights() => setTab(0);
  void switchToTransactions({int tab = 0}) => setTab(2, transactionsTab: tab);
  void switchToMutualFunds() => setTab(3);
}
