import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/models/plans_model.dart';
import '../../datasources/providers/plan_provider.dart';
import '../widgets/cards/plan_card.dart';
import 'create_plan_page.dart';
import 'plan_details_page.dart';

class PlansPage extends StatefulWidget {
  final void Function(VoidCallback)? onSearchToggleReady;
  final void Function(bool, TextEditingController, ValueChanged<String>, VoidCallback)? onSearchStateChanged;
  final void Function(VoidCallback)? onFilterPressedReady;
  final void Function(VoidCallback)? onSortPressedReady;

  const PlansPage({
    super.key,
    this.onSearchToggleReady,
    this.onSearchStateChanged,
    this.onFilterPressedReady,
    this.onSortPressedReady,
  });

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  String? _userId;
  final bool _initialized = false;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedFilters = {allFilter};
  String _sortBy = 'created_desc';

  static const String allFilter = 'All';
  static const List<String> styleFilters = [
    'style_Pomodoro',
    'style_Timeblocking',
    'style_GTD',
    'style_Checklist',
  ];
  static const List<String> deadlineFilters = [
    'deadline_Overdue',
    'deadline_Today',
    'deadline_Upcoming',
    'deadline_None',
  ];
  static final List<String> allFilters = [
    allFilter,
    ...styleFilters,
    ...deadlineFilters,
  ];

  @override
  void initState() {
    super.initState();
    widget.onSearchToggleReady?.call(_toggleSearch);
    widget.onFilterPressedReady?.call(_showFilterMenu);
    widget.onSortPressedReady?.call(_showSortMenu);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<UserProvider>().userId;
    if (userId != null && userId != _userId) {
      setState(() {
        _userId = userId;
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _searchQuery = '';
      }
      widget.onSearchStateChanged?.call(
        _isSearchExpanded,
        _searchController,
        (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        () {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        },
      );
    });
  }

  List<Plan> _filterPlans(List<Plan> plans) {
    if (_searchQuery.isEmpty) return plans;
    return plans.where((plan) {
      final titleMatch = plan.planTitle.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final descMatch = plan.planDescription.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final styleMatch = plan.planStyle.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return titleMatch || descMatch || styleMatch;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _matchesDeadlineFilter(Plan plan, String filter) {
    final deadline = plan.planDeadline;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (filter == 'deadline_None') {
      return deadline == null;
    }

    if (deadline == null) {
      return false;
    }

    final deadlineDate = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
    );

    switch (filter) {
      case 'deadline_Overdue':
        return deadlineDate.isBefore(todayDate);
      case 'deadline_Today':
        return _isSameDay(deadlineDate, todayDate);
      case 'deadline_Upcoming':
        return deadlineDate.isAfter(todayDate);
      default:
        return false;
    }
  }

  List<Plan> _applyFilters(List<Plan> plans) {
    if (_selectedFilters.contains(allFilter)) return plans;

    final selectedStyles = _selectedFilters
        .where((filter) => styleFilters.contains(filter))
        .map((filter) => filter.replaceFirst('style_', ''))
        .toSet();
    final selectedDeadlines = _selectedFilters
        .where((filter) => deadlineFilters.contains(filter))
        .toSet();

    return plans.where((plan) {
      final styleMatch = selectedStyles.isEmpty ||
          selectedStyles.contains(plan.planStyle);
      final deadlineMatch = selectedDeadlines.isEmpty ||
          selectedDeadlines.any((filter) => _matchesDeadlineFilter(plan, filter));
      return styleMatch && deadlineMatch;
    }).toList();
  }

  List<Plan> _applySorting(List<Plan> plans) {
    final sortedPlans = List<Plan>.from(plans);

    switch (_sortBy) {
      case 'alphabetical_asc':
        sortedPlans.sort((a, b) =>
            a.planTitle.toLowerCase().compareTo(b.planTitle.toLowerCase()));
        break;
      case 'alphabetical_desc':
        sortedPlans.sort((a, b) =>
            b.planTitle.toLowerCase().compareTo(a.planTitle.toLowerCase()));
        break;
      case 'created_asc':
        sortedPlans.sort((a, b) => a.planCreatedAt.compareTo(b.planCreatedAt));
        break;
      case 'created_desc':
        sortedPlans.sort((a, b) => b.planCreatedAt.compareTo(a.planCreatedAt));
        break;
      case 'deadline_asc':
        sortedPlans.sort((a, b) {
          final aDeadline = a.planDeadline ?? DateTime(2099);
          final bDeadline = b.planDeadline ?? DateTime(2099);
          return aDeadline.compareTo(bDeadline);
        });
        break;
      case 'deadline_desc':
        sortedPlans.sort((a, b) {
          final aDeadline = a.planDeadline ?? DateTime(1970);
          final bDeadline = b.planDeadline ?? DateTime(1970);
          return bDeadline.compareTo(aDeadline);
        });
        break;
      case 'completion_desc':
        sortedPlans.sort(
            (a, b) => b.completionPercentage.compareTo(a.completionPercentage));
        break;
      case 'completion_asc':
        sortedPlans.sort(
            (a, b) => a.completionPercentage.compareTo(b.completionPercentage));
        break;
    }

    return sortedPlans;
  }

  String _getFilterLabel(String filter) {
    if (filter == allFilter) return 'All plans';
    if (filter.startsWith('style_')) {
      return 'Style: ${filter.replaceFirst('style_', '')}';
    }
    if (filter.startsWith('deadline_')) {
      return 'Deadline: ${filter.replaceFirst('deadline_', '')}';
    }
    return filter;
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        var tempFilters = Set<String>.from(_selectedFilters);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter plans',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allFilters.map((filter) {
                        final isSelected = tempFilters.contains(filter);
                        return FilterChip(
                          label: Text(_getFilterLabel(filter)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (filter == allFilter) {
                                tempFilters = {allFilter};
                              } else {
                                tempFilters.remove(allFilter);
                                if (selected) {
                                  tempFilters.add(filter);
                                } else {
                                  tempFilters.remove(filter);
                                  if (tempFilters.isEmpty) {
                                    tempFilters.add(allFilter);
                                  }
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilters = tempFilters;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort plans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Alphabetical (A-Z)', 'alphabetical_asc'),
                _buildSortOption('Alphabetical (Z-A)', 'alphabetical_desc'),
                _buildSortOption('Created (Newest)', 'created_desc'),
                _buildSortOption('Created (Oldest)', 'created_asc'),
                _buildSortOption('Deadline (Soonest)', 'deadline_asc'),
                _buildSortOption('Deadline (Latest)', 'deadline_desc'),
                _buildSortOption('Completion (High → Low)', 'completion_desc'),
                _buildSortOption('Completion (Low → High)', 'completion_asc'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSelectedFiltersRow() {
    final filters = _selectedFilters.where((f) => f != allFilter).toList();
    if (filters.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(_getFilterLabel(filter)),
              onDeleted: () {
                setState(() {
                  _selectedFilters.remove(filter);
                  if (_selectedFilters.isEmpty) {
                    _selectedFilters.add(allFilter);
                  }
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1565C0), // Dark Blue
              Color(0xFF42A5F5), // Light Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final createdPlan = await Navigator.push<Plan?>(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatePlanPage(),
                ),
              );

              if (createdPlan != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Plan "${createdPlan.planTitle}" has been made successfully!',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'New Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: _userId == null
            ? const Center(child: CircularProgressIndicator())
            : Consumer<PlanProvider>(
                builder: (context, planProvider, _) {
                  return StreamBuilder<List<Plan>>(
                    stream: planProvider.streamUserPlans(_userId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading plans: ${snapshot.error}'),
                        );
                      }

                      final plans = snapshot.data ?? [];
                      final filteredPlans = _applySorting(
                        _applyFilters(
                          _filterPlans(plans),
                        ),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          if (_selectedFilters.isNotEmpty &&
                              !_selectedFilters.contains(allFilter))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: _buildSelectedFiltersRow(),
                            ),
                          Expanded(
                            child: planProvider.isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : filteredPlans.isEmpty && _searchQuery.isNotEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 32,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 56,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No plans found',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Try a different search term',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : plans.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 32,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.event_note,
                                            size: 56,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No plans yet',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    itemCount: filteredPlans.length,
                                    itemBuilder: (context, index) {
                                      final plan = filteredPlans[index];
                                      return PlanCard(
                                        plan: plan,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlanDetailsPage(
                                                plan: plan,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

}
