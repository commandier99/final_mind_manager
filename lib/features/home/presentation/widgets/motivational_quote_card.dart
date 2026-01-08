import 'package:flutter/material.dart';
import 'dart:math';

class MotivationalQuoteSection extends StatelessWidget {
  const MotivationalQuoteSection({super.key});

  String _getRandomQuote() {
    final quotes = [
      "The secret of getting ahead is getting started.",
      "Don't watch the clock; do what it does. Keep going.",
      "The way to get started is to quit talking and begin doing.",
      "Success is not final, failure is not fatal: it is the courage to continue that counts.",
      "Believe you can and you're halfway there.",
      "Your limitation—it's only your imagination.",
      "Great things never come from comfort zones.",
      "Dream it. Wish it. Do it.",
      "Success doesn't just find you. You have to go out and get it.",
      "The harder you work for something, the greater you'll feel when you achieve it.",
      "Dream bigger. Do bigger.",
      "Don't stop when you're tired. Stop when you're done.",
      "Wake up with determination. Go to bed with satisfaction.",
      "Do something today that your future self will thank you for.",
      "Little things make big days.",
      "It's going to be hard, but hard does not mean impossible.",
      "Don't wait for opportunity. Create it.",
      "Sometimes we're tested not to show our weaknesses, but to discover our strengths.",
      "The key to success is to focus on goals, not obstacles.",
      "Success is walking from failure to failure with no loss of enthusiasm.",
    ];
    return quotes[Random().nextInt(quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amber.shade600,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  _getRandomQuote(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
