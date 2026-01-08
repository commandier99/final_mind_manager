import 'package:flutter/material.dart';
import '/features/tasks/datasources/models/task_model.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int? _bottomNavIndex = null;
  int? _sideMenuIndex = null;
  String _currentTitle = 'Home';
  Task? _selectedTask;

  int get selectedIndex => _selectedIndex;
  int? get bottomNavIndex => _bottomNavIndex;
  int? get sideMenuIndex => _sideMenuIndex;
  String get currentTitle => _currentTitle;
  bool get isViewingTaskDetails => _selectedTask != null;
  Task? get selectedTask => _selectedTask;

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

  void viewTaskDetails(Task task) {
    _selectedTask = task;
    notifyListeners();
  }

  void backFromTaskDetails() {
    _selectedTask = null;
    notifyListeners();
  }
}
