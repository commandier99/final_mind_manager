import 'package:flutter/material.dart';
import '/features/tasks/datasources/models/task_model.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int? _bottomNavIndex;
  int? _sideMenuIndex;
  String _currentTitle = 'Home';
  Task? _selectedTask;
  String _memoryBankThoughtKey = memoryBankThoughtAll;

  int get selectedIndex => _selectedIndex;
  int? get bottomNavIndex => _bottomNavIndex;
  int? get sideMenuIndex => _sideMenuIndex;
  String get currentTitle => _currentTitle;
  bool get isViewingTaskDetails => _selectedTask != null;
  Task? get selectedTask => _selectedTask;
  String get memoryBankThoughtKey => _memoryBankThoughtKey;

  static const String memoryBankThoughtAll = 'all';
  static const String memoryBankThoughtBoardInvites = 'board_invites';
  static const String memoryBankThoughtTaskAssignments = 'task_assignments';
  static const String memoryBankThoughtFeedback = 'feedback';
  static const String memoryBankThoughtReminders = 'reminders';

  static const List<String> _titles = [
    // Bottom nav
    'Home',
    'Boards',
    'Plans',
    'Dashboard',

    // Side menu
    'Profile',
    'Notifications',
    'Search & Discover',
    'Settings',
    'Help/FAQ',
    'About',
    'Mind:Set',
    'Memory Bank',
  ];

  void selectFromBottomNav(int index) {
    _selectedIndex = index;
    _bottomNavIndex = index;
    _sideMenuIndex = null;
    _currentTitle = _titles[index];
    if (index != 11) {
      _memoryBankThoughtKey = memoryBankThoughtAll;
    }
    notifyListeners();
  }

  void selectFromSideMenu(int index) {
    _selectedIndex = index;
    _bottomNavIndex = null; // hides bottom nav highlight
    _sideMenuIndex = index; // highlights side menu item
    _currentTitle = _titles[index];
    if (index != 11) {
      _memoryBankThoughtKey = memoryBankThoughtAll;
    }
    notifyListeners();
  }

  void openMemoryBank({String thoughtKey = memoryBankThoughtAll}) {
    _selectedIndex = 11;
    _bottomNavIndex = null;
    _sideMenuIndex = 11;
    _currentTitle = _titles[11];
    _memoryBankThoughtKey = thoughtKey;
    notifyListeners();
  }

  void setMemoryBankThought(String thoughtKey) {
    _memoryBankThoughtKey = thoughtKey;
    if (_selectedIndex != 11) {
      _selectedIndex = 11;
      _bottomNavIndex = null;
      _sideMenuIndex = 11;
      _currentTitle = _titles[11];
    }
    notifyListeners();
  }

  void viewTaskDetails(Task task) {
    _selectedTask = task;
    notifyListeners();
  }

  void backFromTaskDetails() {
    _selectedTask = null;
    notifyListeners();
  }
}
