import 'package:flutter/material.dart';

import 'greeting_section.dart';
import 'features_carousel_widget.dart';
import 'plans_for_today_widget.dart';

class MainHomeSection extends StatelessWidget {
  const MainHomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        GreetingSection(),
        SizedBox(height: 20),
        PlansForTodayWidget(),
        SizedBox(height: 32),
        FeaturesCarouselWidget(),
      ],
    );
  }
}
