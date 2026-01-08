class DashboardModel {
  final String dashboardId;
  final String name;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  DashboardModel({
    required this.dashboardId,
    required this.name,
    this.data,
    required this.createdAt,
  });

  factory DashboardModel.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      try {
        final toDate = (v as dynamic).toDate;
        if (toDate != null) return (v as dynamic).toDate();
      } catch (_) {}
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.now();
    }

    return DashboardModel(
      dashboardId: documentId,
      name: data['name'] as String? ?? 'Dashboard',
      data: data['data'] as Map<String, dynamic>?,
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'data': data,
      'createdAt': createdAt,
    };
  }

  DashboardModel copyWith({
    String? dashboardId,
    String? name,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return DashboardModel(
      dashboardId: dashboardId ?? this.dashboardId,
      name: name ?? this.name,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
