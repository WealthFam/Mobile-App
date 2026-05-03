import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 2; // Dashboard is now at center
  int _initialTransactionsTab = 0;
  String _currentView = 'Dashboard';

  int get selectedIndex => _selectedIndex;
  int get initialTransactionsTab => _initialTransactionsTab;
  String get currentView => _currentView;

  void setTab(int index, {int transactionsTab = 0, String? viewName}) {
    _initialTransactionsTab = transactionsTab;
    if (_selectedIndex != index) {
      _selectedIndex = index;
    }
    
    if (viewName != null) {
      _currentView = viewName;
    } else {
      // Default view names for tabs
      switch (index) {
        case 0: _currentView = 'Insights'; break;
        case 1: _currentView = 'Transactions'; break;
        case 2: _currentView = 'Dashboard'; break;
        case 3: _currentView = 'Mutual Funds'; break;
        case 4: _currentView = 'SMS Guard'; break;
      }
    }
    
    notifyListeners();
  }

  void setView(String viewName) {
    if (_currentView != viewName) {
      _currentView = viewName;
      notifyListeners();
    }
  }

  void switchToInsights() => setTab(0);
  void switchToTransactions({int tab = 0}) => setTab(1, transactionsTab: tab);
  void switchToDashboard() => setTab(2);
  void switchToMutualFunds() => setTab(3);
  void switchToSmsGuard() => setTab(4);
}
