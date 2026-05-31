import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/remote_client.dart';

class AdminUserActivityScreen extends StatefulWidget {
  const AdminUserActivityScreen({super.key});

  @override
  State<AdminUserActivityScreen> createState() =>
      _AdminUserActivityScreenState();
}

class _AdminUserActivityScreenState extends State<AdminUserActivityScreen> {
  final RemoteClient _remote = RemoteClient();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _stats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _remote.getList('/user-activities/daily-stats');
      if (!mounted) return;
      setState(() {
        _stats = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load user activity: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _statsByDate {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final stat in _stats) {
      final date = (stat['date'] ?? '').toString();
      if (date.isEmpty) continue;
      grouped.putIfAbsent(date, () => []).add(stat);
    }
    return grouped;
  }

  String _formatDuration(num secondsValue) {
    final seconds = secondsValue.toInt();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  Future<void> _openDetails(String date) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ActivityDetailsSheet(
        date: date,
        formatDate: _formatDate,
        formatDateTime: _formatDateTime,
        formatDuration: _formatDuration,
        loadActivities: () async {
          final data = await _remote.getList('/user-activities/date/$date');
          return data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _statsByDate;
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStats,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: _loading && _stats.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_error!),
                        ),
                      ),
                    ],
                  )
                : dates.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 80),
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              'No activity data yet',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: dates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final date = dates[index];
                          final dateStats = grouped[date]!;
                          final sessions = dateStats.fold<num>(
                              0,
                              (sum, stat) =>
                                  sum + (stat['sessionCount'] as num? ?? 0));
                          final seconds = dateStats.fold<num>(
                              0,
                              (sum, stat) =>
                                  sum +
                                  (stat['totalDurationSeconds'] as num? ?? 0));

                          return Card(
                            elevation: 1,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openDetails(date),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          child: Icon(Icons.calendar_month),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatDate(date),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                              Text(
                                                '$sessions sessions • ${_formatDuration(seconds)} total',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...dateStats.take(4).map((stat) {
                                      final userName =
                                          (stat['userName'] ?? 'Unknown user')
                                              .toString();
                                      final count =
                                          stat['sessionCount'] as num? ?? 0;
                                      final duration =
                                          stat['totalDurationSeconds']
                                                  as num? ??
                                              0;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.person,
                                                size: 18, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(userName)),
                                            Text(
                                              '${count.toInt()} • ${_formatDuration(duration)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    if (dateStats.length > 4)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          '+${dateStats.length - 4} more users',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ActivityDetailsSheet extends StatelessWidget {
  const _ActivityDetailsSheet({
    required this.date,
    required this.formatDate,
    required this.formatDateTime,
    required this.formatDuration,
    required this.loadActivities,
  });

  final String date;
  final String Function(String) formatDate;
  final String Function(dynamic) formatDateTime;
  final String Function(num) formatDuration;
  final Future<List<Map<String, dynamic>>> Function() loadActivities;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: loadActivities(),
          builder: (context, snapshot) {
            final activities = snapshot.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Activity Details - ${formatDate(date)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                  'Failed to load activities: ${snapshot.error}'),
                            )
                          : activities.isEmpty
                              ? const Center(
                                  child: Text('No sessions for this date'),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  itemCount: activities.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final activity = activities[index];
                                    final user = activity['user'];
                                    final userName = user is Map
                                        ? (user['name'] ?? 'Unknown user')
                                            .toString()
                                        : 'Unknown user';
                                    final duration =
                                        activity['durationSeconds'] as num?;
                                    return Card(
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                        title: Text(userName),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Start: ${formatDateTime(activity['sessionStart'])}'),
                                            if (activity['sessionEnd'] != null)
                                              Text(
                                                  'End: ${formatDateTime(activity['sessionEnd'])}'),
                                            if (activity['deviceInfo'] != null)
                                              Text(
                                                  'Device: ${activity['deviceInfo']}'),
                                            if (activity['appVersion'] != null)
                                              Text(
                                                  'App: ${activity['appVersion']}'),
                                          ],
                                        ),
                                        trailing: duration == null
                                            ? const Text('Active')
                                            : Text(formatDuration(duration)),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
