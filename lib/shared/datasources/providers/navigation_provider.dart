import 'package:flutter/material.dart';
import '/features/tasks/datasources/models/task_model.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int? _bottomNavIndex;
  int? _sideMenuIndex;
  String _currentTitle = 'Home';
  Task? _selectedTask;
  String? _selectedThoughtId;
  String? _selectedThoughtType;

  int get selectedIndex => _selectedIndex;
  int? get bottomNavIndex => _bottomNavIndex;
  int? get sideMenuIndex => _sideMenuIndex;
  String get currentTitle => _currentTitle;
  bool get isViewingTaskDetails => _selectedTask != null;
  Task? get selectedTask => _selectedTask;
  String? get selectedThoughtId => _selectedThoughtId;
  String? get selectedThoughtType => _selectedThoughtType;

  static const List<String> _titles = [
    // Bottom nav
    'Home',
    'Boards',
    'Plans',
    'Dashboard',

    // Side menu
    'Profile',
    'Search & Discover',
    'Notifications',
    'Thoughts',
    'Settings',
    'Help/FAQ',
    'About',
    'Mind:Set',
  ];

  void selectFromBottomNav(int index) {
    _selectedIndex = index;
    _bottomNavIndex = index;
    _sideMenuIndex = null;
    _currentTitle = _titles[index];
    notifyListeners();
  }

  void selectFromSideMenu(int index) {
    _selectedIndex = index;
    _bottomNavIndex = null; // hides bottom nav highlight
    _sideMenuIndex = index; // highlights side menu item
    _currentTitle = _titles[index];
    notifyListeners();
  }

  void openThoughts({String? thoughtId, String? thoughtType}) {
    _selectedIndex = 7;
    _bottomNavIndex = null;
    _sideMenuIndex = 7;
    _currentTitle = _titles[7];
    _selectedThoughtId = thoughtId;
    _selectedThoughtType = thoughtType;
    notifyListeners();
  }

  void clearThoughtSelection() {
    _selectedThoughtId = null;
    _selectedThoughtType = null;
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
