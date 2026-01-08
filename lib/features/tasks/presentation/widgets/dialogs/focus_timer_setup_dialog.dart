import 'package:flutter/material.dart';
import '../../../datasources/models/task_model.dart';
import 'focus_timer_dialog.dart';

class FocusTimerSetupDialog extends StatefulWidget {
  final Task task;

  const FocusTimerSetupDialog({
    super.key,
    required this.task,
  });

  @override
  State<FocusTimerSetupDialog> createState() => _FocusTimerSetupDialogState();
}

class _FocusTimerSetupDialogState extends State<FocusTimerSetupDialog> {
  late int _selectedMinutes = 25; // Default pomodoro time

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Focus Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How much time do you want to focus on "${widget.task.taskTitle}"?',
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Text(
              '$_selectedMinutes minutes',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick preset buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPresetButton(15),
              _buildPresetButton(25),
              _buildPresetButton(45),
              _buildPresetButton(60),
            ],
          ),
          const SizedBox(height: 20),

          // Custom slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom duration:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _selectedMinutes.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                label: '$_selectedMinutes min',
                onChanged: (value) {
                  setState(() {
                    _selectedMinutes = value.toInt();
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Show the timer with the selected duration
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => FocusTimerWidget(
                task: widget.task,
                plannedDurationMinutes: _selectedMinutes,
                onClose: () {
                  Navigator.pop(context);
                },
              ),
            );
          },
          child: const Text('Start Focus'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(int minutes) {
    final isSelected = _selectedMinutes == minutes;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMinutes = minutes;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Text(
          '$minutes m',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
