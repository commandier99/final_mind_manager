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

  const PlansPage({super.key, this.onSearchToggleReady, this.onSearchStateChanged});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  String? _userId;
  bool _initialized = false;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.onSearchToggleReady?.call(_toggleSearch);
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
    if (userId != null && !_initialized) {
      _userId = userId;
      _initialized = true;
      Provider.of<PlanProvider>(context, listen: false).loadUserPlans(userId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'plans_page_fab',
        onPressed: () async {
          final template = await _showTemplateDialog(context);
          if (template == null) return;

          final createdPlan = await Navigator.push<Plan?>(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlanPage(initialTechnique: template),
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
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _userId == null
            ? const Center(child: CircularProgressIndicator())
            : Consumer<PlanProvider>(
                builder: (context, planProvider, _) {
                  final plans = planProvider.userPlans;
                  final filteredPlans = _filterPlans(plans);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

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
              ),
      ),
    );
  }

  Future<String?> _showTemplateDialog(BuildContext context) {
    final templates = [
      (
        'quick_todo',
        'Quick To-Do',
        'Compile tasks you want to do together.',
      ),
      (
        'pomodoro',
        'Pomodoro',
        'Work in focused intervals with short breaks in-between.',
      ),
      (
        'eat_the_frog',
        'Eat the Frog',
        'Identify the hardest tasks, the Frog/s, and tackle them first.',
      ),
    ];

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose a template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, title, desc) in templates)
                  ListTile(
                    title: Text(title),
                    subtitle: Text(desc),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
