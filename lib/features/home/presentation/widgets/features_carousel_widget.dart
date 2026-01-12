import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'dart:async';

class FeaturesCarouselWidget extends StatefulWidget {
  const FeaturesCarouselWidget({super.key});

  @override
  State<FeaturesCarouselWidget> createState() => _FeaturesCarouselWidgetState();
}

class _FeaturesCarouselWidgetState extends State<FeaturesCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  late Timer _autoScrollTimer;

  final List<FeatureCard> features = [
    FeatureCard(
      icon: Icons.dashboard,
      title: 'Create a Board!',
      description: 'Breakdown your projects into manageable tasks!',
      isStaticCard: true,
    ),
    FeatureCard(
      icon: Icons.check_circle,
      title: 'Track Progress',
      description: 'Monitor your completed tasks and stay motivated!',
      isStaticCard: true,
    ),
    FeatureCard(
      icon: Icons.calendar_month,
      title: 'Plan Ahead',
      description: 'Schedule your tasks and never miss a deadline!',
      isStaticCard: true,
    ),
    FeatureCard(
      icon: Icons.lightbulb,
      title: 'Get Insights',
      description: 'Analyze your productivity patterns and improve!',
      isStaticCard: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _pageController.hasClients) {
        // Get the total number of pages from the current context
        int totalPages = features.length + 2; // +2 for the overdue and today cards
        _currentPage = (_currentPage + 1) % totalPages;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final userId = context.read<UserProvider>().userId;
        
        // Calculate overdue tasks
        final overdueTasks = _getOverdueTasks(taskProvider, userId);
        final overdueBoards = _getUniqueBoardCount(overdueTasks);
        
        // Calculate tasks due today
        final tasksDueToday = _getTasksDueToday(taskProvider, userId);
        final todayBoards = _getUniqueBoardCount(tasksDueToday);
        
        // Create dynamic feature list with status cards
        List<FeatureCard> dynamicFeatures = [
          ...features,
          FeatureCard(
            icon: Icons.warning_amber,
            title: 'Overdue Tasks',
            description: '${overdueTasks.length} overdue from ${overdueBoards} boards',
            isStaticCard: false,
            cardColor: Colors.red.shade400,
          ),
          FeatureCard(
            icon: Icons.today,
            title: 'Due Today',
            description: '${tasksDueToday.length} tasks from ${todayBoards} boards',
            isStaticCard: false,
            cardColor: Colors.orange.shade400,
          ),
        ];

        return Column(
          children: [
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: dynamicFeatures.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: _buildFeatureCard(dynamicFeatures[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildDotIndicators(dynamicFeatures.length),
          ],
        );
      },
    );
  }

  List<Task> _getOverdueTasks(TaskProvider taskProvider, String? userId) {
    if (userId == null) return [];
    
    final now = DateTime.now();
    return taskProvider.tasks
        .where((task) {
          if (task.taskDeadline == null || task.taskIsDone) return false;
          
          final deadline = task.taskDeadline!;
          final isOverdue = deadline.isBefore(now);
          final isUserInvolved = task.taskAssignedTo == userId || 
                                 task.taskOwnerId == userId ||
                                 task.taskHelpers.contains(userId);
          
          return isOverdue && isUserInvolved;
        })
        .toList();
  }

  List<Task> _getTasksDueToday(TaskProvider taskProvider, String? userId) {
    if (userId == null) return [];
    
    final now = DateTime.now();
    return taskProvider.tasks
        .where((task) {
          if (task.taskDeadline == null || task.taskIsDone) return false;
          
          final deadline = task.taskDeadline!;
          final isToday = deadline.year == now.year &&
              deadline.month == now.month &&
              deadline.day == now.day;
          final isDueToday = isToday && deadline.isAfter(now);
          
          final isUserInvolved = task.taskAssignedTo == userId || 
                                 task.taskOwnerId == userId ||
                                 task.taskHelpers.contains(userId);
          
          return isDueToday && isUserInvolved;
        })
        .toList();
  }

  int _getUniqueBoardCount(List<Task> tasks) {
    return tasks.map((task) => task.taskBoardId).toSet().length;
  }

  Widget _buildFeatureCard(FeatureCard feature) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: feature.isStaticCard
              ? LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [feature.cardColor!, feature.cardColor!.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                feature.icon,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      feature.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicators(int length) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 12 : 8,
          height: _currentPage == index ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.blue.shade600
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class FeatureCard {
  final IconData icon;
  final String title;
  final String description;
  final bool isStaticCard;
  final Color? cardColor;

  FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isStaticCard = true,
    this.cardColor,
  });
}
