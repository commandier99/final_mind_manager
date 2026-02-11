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
  final bool _initialized = false;
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
                      ]);
                    },
                  );
                },
              ),
      ),
    );
  }

}
