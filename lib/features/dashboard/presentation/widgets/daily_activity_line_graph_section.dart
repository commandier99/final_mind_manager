import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../../../../shared/features/users/datasources/models/user_daily_activity_model.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_daily_activity_provider.dart';

enum _ProductivityMetric {
  productivityScore,
  tasksCompleted,
  subtasksCompleted,
  subtasksCreated,
  fileSubmissions,
  revisionsRequested,
}

class DailyActivityLineGraphSection extends StatefulWidget {
  const DailyActivityLineGraphSection({
    super.key,
    this.defaultMetricId = 'productivity_score',
    this.onMetricChanged,
    this.onTap,
  });

  final String defaultMetricId;
  final ValueChanged<String>? onMetricChanged;
  final VoidCallback? onTap;

  @override
  State<DailyActivityLineGraphSection> createState() =>
      _DailyActivityLineGraphSectionState();
}

class _DailyActivityLineGraphSectionState
    extends State<DailyActivityLineGraphSection> {
  late _ProductivityMetric _metric;

  @override
  void initState() {
    super.initState();
    _metric = _metricFromId(widget.defaultMetricId);
  }

  @override
  void didUpdateWidget(covariant DailyActivityLineGraphSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultMetricId != widget.defaultMetricId) {
      _metric = _metricFromId(widget.defaultMetricId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserDailyActivityProvider, ActivityEventProvider>(
      builder: (context, provider, eventProvider, _) {
        final baseData = _normalizeToLastNDays(provider.recentDays, 14);
        final values = _buildValues(baseData, eventProvider.events, _metric);
        final maxY = math.max(1, values.fold<int>(0, math.max));
        final todayValue = values.isNotEmpty ? values.last : 0;
        final avgValue = values.isEmpty
            ? 0
            : (values.reduce((a, b) => a + b) / values.length).round();

        final content = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daily Productivity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Today: $todayValue',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _legacyStatBox(
                      label: 'Today',
                      value: '$todayValue',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _legacyStatBox(
                      label: '14-Day Avg',
                      value: '$avgValue',
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _metricSubtitle(_metric),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metricChip(_ProductivityMetric.productivityScore, 'Score'),
                    _metricChip(_ProductivityMetric.tasksCompleted, 'Tasks Done'),
                    _metricChip(
                      _ProductivityMetric.subtasksCompleted,
                      'Subtasks Done',
                    ),
                    _metricChip(
                      _ProductivityMetric.subtasksCreated,
                      'Subtasks Created',
                    ),
                    _metricChip(_ProductivityMetric.fileSubmissions, 'Submissions'),
                    _metricChip(
                      _ProductivityMetric.revisionsRequested,
                      'Revisions',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    SizedBox(width: 36, child: _YAxis(maxValue: maxY)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomPaint(
                        painter: _LineChartPainter(values: values),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _xLabel(baseData.first.date),
                  _xLabel(baseData[baseData.length ~/ 2].date),
                  _xLabel(baseData.last.date),
                ],
              ),
            ],
          ),
        );

        return Card(
          elevation: 2,
          clipBehavior: widget.onTap != null ? Clip.antiAlias : Clip.none,
          child: widget.onTap == null
              ? content
              : InkWell(
                  onTap: widget.onTap,
                  child: content,
                ),
        );
      },
    );
  }

  Widget _metricChip(_ProductivityMetric metric, String label) {
    final selected = _metric == metric;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _metric = metric);
        widget.onMetricChanged?.call(_metricId(metric));
      },
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.white : Colors.grey.shade800,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: Colors.blue,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade300),
    );
  }

  Widget _legacyStatBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _metricSubtitle(_ProductivityMetric metric) {
    switch (metric) {
      case _ProductivityMetric.productivityScore:
        return 'Score = tasks done + subtasks done + subtasks created';
      case _ProductivityMetric.tasksCompleted:
        return 'Tasks completed per day';
      case _ProductivityMetric.subtasksCompleted:
        return 'Subtasks completed per day';
      case _ProductivityMetric.subtasksCreated:
        return 'Subtasks created per day';
      case _ProductivityMetric.fileSubmissions:
        return 'File submissions per day';
      case _ProductivityMetric.revisionsRequested:
        return 'Revision requests per day';
    }
  }

  List<int> _buildValues(
    List<UserDailyActivityModel> baseData,
    List<ActivityEvent> events,
    _ProductivityMetric metric,
  ) {
    if (metric == _ProductivityMetric.fileSubmissions ||
        metric == _ProductivityMetric.revisionsRequested) {
      final keyByDate = {for (final d in baseData) d.date: 0};
      final targetType = metric == _ProductivityMetric.fileSubmissions
          ? 'file_submitted'
          : 'submission_revision_requested';

      for (final e in events) {
        if (e.ActEvType != targetType) continue;
        final date =
            '${e.ActEvTimestamp.year}-${e.ActEvTimestamp.month.toString().padLeft(2, '0')}-${e.ActEvTimestamp.day.toString().padLeft(2, '0')}';
        if (keyByDate.containsKey(date)) {
          keyByDate[date] = (keyByDate[date] ?? 0) + 1;
        }
      }
      return baseData.map((d) => keyByDate[d.date] ?? 0).toList();
    }

    return baseData.map((d) {
      switch (metric) {
        case _ProductivityMetric.productivityScore:
          return d.tasksCompletedCount +
              d.subtasksCompletedCount +
              d.subtasksCreatedCount;
        case _ProductivityMetric.tasksCompleted:
          return d.tasksCompletedCount;
        case _ProductivityMetric.subtasksCompleted:
          return d.subtasksCompletedCount;
        case _ProductivityMetric.subtasksCreated:
          return d.subtasksCreatedCount;
        case _ProductivityMetric.fileSubmissions:
        case _ProductivityMetric.revisionsRequested:
          return 0;
      }
    }).toList();
  }

  Widget _xLabel(String date) {
    final parts = date.split('-');
    if (parts.length != 3) {
      return Text(date, style: const TextStyle(fontSize: 11));
    }
    return Text(
      '${parts[1]}/${parts[2]}',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  List<UserDailyActivityModel> _normalizeToLastNDays(
    List<UserDailyActivityModel> source,
    int days,
  ) {
    final byDate = <String, UserDailyActivityModel>{
      for (final item in source) item.date: item,
    };
    final today = DateTime.now();
    final normalized = <UserDailyActivityModel>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      final dateId =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      normalized.add(
        byDate[dateId] ??
            UserDailyActivityModel(
              userId: source.isNotEmpty ? source.first.userId : '',
              date: dateId,
            ),
      );
    }
    return normalized;
  }

  _ProductivityMetric _metricFromId(String metricId) {
    switch (metricId) {
      case 'tasks_completed':
        return _ProductivityMetric.tasksCompleted;
      case 'subtasks_completed':
        return _ProductivityMetric.subtasksCompleted;
      case 'subtasks_created':
        return _ProductivityMetric.subtasksCreated;
      case 'file_submissions':
        return _ProductivityMetric.fileSubmissions;
      case 'revisions_requested':
        return _ProductivityMetric.revisionsRequested;
      case 'productivity_score':
      default:
        return _ProductivityMetric.productivityScore;
    }
  }

  String _metricId(_ProductivityMetric metric) {
    switch (metric) {
      case _ProductivityMetric.tasksCompleted:
        return 'tasks_completed';
      case _ProductivityMetric.subtasksCompleted:
        return 'subtasks_completed';
      case _ProductivityMetric.subtasksCreated:
        return 'subtasks_created';
      case _ProductivityMetric.fileSubmissions:
        return 'file_submissions';
      case _ProductivityMetric.revisionsRequested:
        return 'revisions_requested';
      case _ProductivityMetric.productivityScore:
        return 'productivity_score';
    }
  }
}

class _YAxis extends StatelessWidget {
  const _YAxis({required this.maxValue});

  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final top = maxValue;
    final mid = (maxValue / 2).ceil();
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$top', style: _style()),
        Text('$mid', style: _style()),
        Text('0', style: _style()),
      ],
    );
  }

  TextStyle _style() => const TextStyle(fontSize: 10, color: Colors.black54);
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = math.max(1, values.reduce(math.max));

    final gridPaint = Paint()
      ..color = const Color(0x1F000000)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x552563EB), Color(0x002563EB)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      gridPaint,
    );

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / maxValue) * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = const Color(0xFF1D4ED8);
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / maxValue) * size.height);
      canvas.drawCircle(Offset(x, y), 2.8, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
