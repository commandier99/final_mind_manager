import 'package:flutter/material.dart';
import '../../../plans/datasources/models/plans_model.dart';
import 'greeting_section.dart';
import 'features_carousel_widget.dart';
import 'plans_for_today_widget.dart';

class MainHomeSection extends StatelessWidget {
  final void Function(Plan)? onPlanTap;

  const MainHomeSection({super.key, this.onPlanTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GreetingSection(),
        const SizedBox(height: 20),
        PlansForTodayWidget(onPlanTap: onPlanTap),
        const SizedBox(height: 32),
        const FeaturesCarouselWidget(),
      ],
    );
  }
}
