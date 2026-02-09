import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'dart:async';
import 'feature_card_widget.dart';
import '../features/mind_set/pages/mind_set_page.dart';

class FeaturesCarouselWidget extends StatefulWidget {
  const FeaturesCarouselWidget({super.key});

  @override
  State<FeaturesCarouselWidget> createState() => _FeaturesCarouselWidgetState();
}

class _FeaturesCarouselWidgetState extends State<FeaturesCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  late Timer _autoScrollTimer;
  static const int _initialPageMultiplier = 1000;
  static const Duration _autoScrollInterval = Duration(seconds: 6);
  static const int _loopMultiplier = 1000;

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
    FeatureCard(
      icon: Icons.psychology,
      title: 'Enter Mind:Set',
      description: 'Set your mind to be productive.',
      isStaticCard: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: features.length * _initialPageMultiplier,
    );
    _currentPage = _pageController.initialPage;
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (timer) {
      if (mounted && _pageController.hasClients) {
        _currentPage += 1;
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
          ...features.map((feature) {
            // Add navigation for Mind:Set card
            if (feature.title == 'Enter Mind:Set') {
              return FeatureCard(
                icon: feature.icon,
                title: feature.title,
                description: feature.description,
                isStaticCard: feature.isStaticCard,
                cardColor: feature.cardColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MindSetPage()),
                  );
                },
              );
            }
            return feature;
          }),
          FeatureCard(
            icon: Icons.warning_amber,
            title: 'Overdue Tasks',
            description: '${overdueTasks.length} overdue from $overdueBoards boards',
            isStaticCard: false,
            cardColor: Colors.red.shade400,
          ),
          FeatureCard(
            icon: Icons.today,
            title: 'Due Today',
            description: '${tasksDueToday.length} tasks from $todayBoards boards',
            isStaticCard: false,
            cardColor: Colors.orange.shade400,
          ),
        ];
        final totalFeatures = dynamicFeatures.length;
        final currentIndex = _currentPage % totalFeatures;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: totalFeatures * _loopMultiplier,
                itemBuilder: (context, index) {
                  final feature = dynamicFeatures[index % totalFeatures];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: FeatureCardWidget(feature: feature),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildDotIndicators(totalFeatures, currentIndex),
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

  Widget _buildDotIndicators(int length, int currentIndex) {
    if (length <= 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      );
    }

    final leftIndex = (currentIndex - 1 + length) % length;
    final rightIndex = (currentIndex + 1) % length;
    final indicatorOrder = [leftIndex, currentIndex, rightIndex];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        indicatorOrder.length,
        (index) {
          final dotIndex = indicatorOrder[index];
          final isActive = dotIndex == currentIndex;
          return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 12 : 8,
          height: isActive ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.blue.shade600
                : Colors.grey.shade400,
          ),
        );
        },
      ),
    );
  }
}
