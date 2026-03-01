import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/models/plans_model.dart';
import '../../datasources/providers/plan_provider.dart';
import '../controllers/plans_query_controller.dart';
import '../widgets/cards/plan_card.dart';
import 'create_plan_page.dart';
import 'plan_details_page.dart';

class PlansPage extends StatefulWidget {
  final void Function(VoidCallback)? onSearchToggleReady;
  final void Function(
    bool,
    TextEditingController,
    ValueChanged<String>,
    VoidCallback,
  )?
  onSearchStateChanged;
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
  final PlansQueryController _queryController = PlansQueryController();
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedFilters = {PlansQueryController.allFilter};
  String _sortBy = 'created_desc';

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
        (value) => setState(() => _searchQuery = value),
        () {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        },
      );
    });
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
                      children: PlansQueryController.allFilters.map((filter) {
                        final isSelected = tempFilters.contains(filter);
                        return FilterChip(
                          label: Text(_queryController.getFilterLabel(filter)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setSheetState(() {
                              tempFilters = selected
                                  ? _queryController.addFilter(
                                      selectedFilters: tempFilters,
                                      filter: filter,
                                    )
                                  : _queryController.removeFilter(
                                      selectedFilters: tempFilters,
                                      filter: filter,
                                    );
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Alphabetical (A-Z)', 'alphabetical_asc'),
                _buildSortOption('Alphabetical (Z-A)', 'alphabetical_desc'),
                _buildSortOption('Created (Newest)', 'created_desc'),
                _buildSortOption('Created (Oldest)', 'created_asc'),
                _buildSortOption('Deadline (Soonest)', 'deadline_asc'),
                _buildSortOption('Deadline (Latest)', 'deadline_desc'),
                _buildSortOption('Completion (High -> Low)', 'completion_desc'),
                _buildSortOption('Completion (Low -> High)', 'completion_asc'),
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
    final filters = _selectedFilters
        .where((f) => f != PlansQueryController.allFilter)
        .toList();
    if (filters.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(_queryController.getFilterLabel(filter)),
              onDeleted: () {
                setState(() {
                  _selectedFilters = _queryController.removeFilter(
                    selectedFilters: _selectedFilters,
                    filter: filter,
                  );
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
    final userId = context.select<UserProvider, String?>((p) => p.userId);
    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withValues(alpha: 0.4),
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
                MaterialPageRoute(builder: (context) => const CreatePlanPage()),
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
        child: userId == null
            ? const Center(child: CircularProgressIndicator())
            : Consumer<PlanProvider>(
                builder: (context, planProvider, _) {
                  return StreamBuilder<List<Plan>>(
                    stream: planProvider.streamUserPlans(userId),
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
                      final filteredPlans = _queryController.applyQuery(
                        plans: plans,
                        searchQuery: _searchQuery,
                        selectedFilters: _selectedFilters,
                        sortBy: _sortBy,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          if (_selectedFilters.isNotEmpty &&
                              !_selectedFilters.contains(
                                PlansQueryController.allFilter,
                              ))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: _buildSelectedFiltersRow(),
                            ),
                          Expanded(
                            child: planProvider.isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : filteredPlans.isEmpty &&
                                      _searchQuery.isNotEmpty
                                ? _buildNoSearchResults()
                                : plans.isEmpty
                                ? _buildNoPlansState()
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    itemCount: filteredPlans.length,
                                    itemBuilder: (context, index) {
                                      final plan = filteredPlans[index];
                                      return PlanCard(
                                        plan: plan,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PlanDetailsPage(plan: plan),
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

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No plans found',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlansState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No plans yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a plan to organize tasks for your Follow Through sessions.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
