import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/misc_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../reschedule/something_came_up_screen.dart';
import '../tasks/task_detail_screen.dart';

final dashboardProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(dashboardServiceProvider).get();
});

final notificationsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(notificationServiceProvider).list();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dashboardProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        ref.invalidate(notificationsProvider);
      },
      child: asyncData.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.only(top: 120), child: CircularProgressIndicator())),
        error: (e, st) => ListView(children: [ErrorState(message: '$e', onRetry: () => ref.invalidate(dashboardProvider))]),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final DashboardData data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Good ${_timeOfDay()}, ${data.greetingName} 👋',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            notifsAsync.maybeWhen(
              data: (notifs) {
                final unread = notifs.where((n) => !n.read).length;
                return Stack(
                  children: [
                    IconButton(
                      onPressed: () => _showNotifications(context, notifs),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                          child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9)),
                        ),
                      ),
                  ],
                );
              },
              orElse: () => const SizedBox(width: 48),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Today's capacity
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's capacity", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                CapacityBar(planned: data.todayPlannedMinutes, capacity: data.todayCapacityMinutes),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Something came up CTA
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SomethingCameUpScreen()));
              ref.invalidate(dashboardProvider);
            },
            icon: const Icon(Icons.bolt_outlined, color: AppColors.warning),
            label: const Text('Something came up'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.warning),
              foregroundColor: AppColors.warning,
            ),
          ),
        ),
        const SizedBox(height: 24),

        SectionTitle("Today's schedule"),
        if (data.todaySchedule.isEmpty)
          const EmptyState(icon: Icons.event_available, title: 'Nothing scheduled today', subtitle: 'Add a task to get started.')
        else
          ...data.todaySchedule.map((s) => _ScheduleTile(slot: s)),

        const SizedBox(height: 20),
        if (data.priorityTask != null) ...[
          SectionTitle('Priority'),
          Card(
            child: ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: data.priorityTask!['id'])),
              ),
              leading: const CircleAvatar(backgroundColor: Color(0x1AF6416C), child: Icon(Icons.priority_high, color: AppColors.danger)),
              title: Text(data.priorityTask!['title']),
              subtitle: data.priorityTask!['deadline'] != null
                  ? Text('Due ${_friendlyDate(data.priorityTask!['deadline'])}')
                  : null,
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 20),
        ],

        SectionTitle('Academic workload — this week'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _statColumn('Planned', formatMinutes(data.weekPlannedMinutes), AppColors.secondary),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: _statColumn('Completed', formatMinutes(data.weekCompletedMinutes), AppColors.success),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        SectionTitle('Upcoming deadlines'),
        if (data.upcomingDeadlines.isEmpty)
          const EmptyState(icon: Icons.event_note, title: 'No deadlines yet', subtitle: 'Create a task with a deadline to see it here.')
        else
          ...data.upcomingDeadlines.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: d['id']))),
                  leading: const Icon(Icons.flag_outlined, color: AppColors.primary),
                  title: Text(d['title']),
                  subtitle: d['deadline'] != null ? Text(_friendlyDate(d['deadline'])) : null,
                ),
              )),
      ],
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _friendlyDate(String iso) {
    final d = DateTime.parse(iso);
    return DateFormat('EEE, d MMM • h:mm a').format(d);
  }

  void _showNotifications(BuildContext context, List<AppNotification> notifs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: notifs.isEmpty
                    ? const EmptyState(icon: Icons.notifications_none, title: 'All caught up', subtitle: 'No notifications right now.')
                    : ListView.builder(
                        controller: controller,
                        itemCount: notifs.length,
                        itemBuilder: (context, i) {
                          final n = notifs[i];
                          return ListTile(
                            leading: Icon(_iconFor(n.kind), color: _colorFor(n.kind)),
                            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w700)),
                            subtitle: Text(n.body),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'deadline':
        return Icons.alarm;
      case 'attendance':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorFor(String kind) {
    switch (kind) {
      case 'deadline':
        return AppColors.danger;
      case 'attendance':
        return AppColors.warning;
      default:
        return AppColors.secondary;
    }
  }
}

class _ScheduleTile extends StatelessWidget {
  final dynamic slot;
  const _ScheduleTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    final isBreak = slot['is_break'] == true;
    final start = DateTime.parse(slot['start_time']);
    final end = DateTime.parse(slot['end_time']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isBreak ? Colors.grey.shade200 : const Color(0x1A6C63FF),
          child: Icon(isBreak ? Icons.coffee_outlined : Icons.menu_book_outlined,
              color: isBreak ? Colors.grey.shade600 : AppColors.primary),
        ),
        title: Text(slot['title'], style: TextStyle(fontWeight: isBreak ? FontWeight.normal : FontWeight.w600)),
        subtitle: Text('${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'),
        trailing: slot['task_id'] != null
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: slot['task_id'] != null
            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: slot['task_id'])))
            : null,
      ),
    );
  }
}
