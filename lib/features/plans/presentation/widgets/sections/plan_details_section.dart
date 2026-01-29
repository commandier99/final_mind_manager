import 'package:flutter/material.dart';
import '../../../datasources/models/plans_model.dart';

class PlanDetailsSection extends StatefulWidget {
  final Plan plan;
  final bool isOwner;

  const PlanDetailsSection({
    super.key,
    required this.plan,
    required this.isOwner,
  });

  @override
  State<PlanDetailsSection> createState() => _PlanDetailsSectionState();
}

class _PlanDetailsSectionState extends State<PlanDetailsSection> {
  bool _isDescriptionExpanded = false;

  Color _getStyleColor(String style) {
    switch (style.toLowerCase()) {
      case 'pomodoro':
        return Colors.red.shade400;
      case 'timeblocking':
        return Colors.blue.shade400;
      case 'gtd':
        return Colors.purple.shade400;
      default:
        return Colors.teal.shade400;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final styleColor = _getStyleColor(widget.plan.planStyle);
    final progress = widget.plan.totalTasks > 0
        ? widget.plan.completedTasks / widget.plan.totalTasks
        : 0.0;
    final percentage = widget.plan.totalTasks > 0
        ? (progress * 100).toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with style badge
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (widget.plan.planTitle.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Plan Title'),
                          content: SingleChildScrollView(
                            child: Text(widget.plan.planTitle),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: Text(
                    widget.plan.planTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: styleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.plan.planStyle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: styleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Owner
          Text(
            'by ${widget.plan.planOwnerName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          if (widget.plan.planDescription.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.plan.planDescription,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: _isDescriptionExpanded ? null : 2,
                      overflow: _isDescriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isDescriptionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Progress Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${widget.plan.completedTasks}/${widget.plan.totalTasks} tasks',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metadata
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (widget.plan.planScheduledFor != null)
                _buildMetadataItem(
                  icon: Icons.calendar_today,
                  label: 'Scheduled',
                  value: _formatDate(widget.plan.planScheduledFor!),
                ),
              if (widget.plan.planDeadline != null)
                _buildMetadataItem(
                  icon: Icons.flag,
                  label: 'Deadline',
                  value: _formatDate(widget.plan.planDeadline!),
                ),
              _buildMetadataItem(
                icon: Icons.access_time,
                label: 'Created',
                value: _formatDate(widget.plan.planCreatedAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildMetadataItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
