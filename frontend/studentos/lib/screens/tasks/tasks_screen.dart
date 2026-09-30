import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'task_detail_screen.dart';
import 'create_task_screen.dart';

final tasksListProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(taskServiceProvider).list();
});

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _filter = 'All';
  final _filters = const ['All', 'Not Started', 'In Progress', 'Completed', 'Deferred'];

  @override
  Widget build(BuildContext context) {
    final asyncTasks = ref.watch(tasksListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
          );
          if (created == true) ref.invalidate(tasksListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tasksListProvider),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tasks', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final f = _filters[i];
                          final selected = f == _filter;
                          return ChoiceChip(
                            label: Text(f),
                            selected: selected,
                            onSelected: (_) => setState(() => _filter = f),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            asyncTasks.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
              ),
              error: (e, st) => SliverToBoxAdapter(
                child: ErrorState(message: '$e', onRetry: () => ref.invalidate(tasksListProvider)),
              ),
              data: (tasks) {
                final filtered = _filter == 'All' ? tasks : tasks.where((t) => t.status == _filter).toList();
                if (filtered.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.checklist_outlined,
                      title: 'No tasks here',
                      subtitle: 'Tap "New task" to add an assignment, project, or study session.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TaskCard(task: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final done = task.status == 'Completed';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)));
          // ignore: use_build_context_synchronously
          ProviderScope.containerOf(context).invalidate(tasksListProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? Colors.grey : null,
                      ),
                    ),
                  ),
                  PriorityChip(task.priority),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(task.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(width: 14),
                  if (task.deadline != null) ...[
                    Icon(Icons.event_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(DateFormat('d MMM').format(task.deadline!), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timelapse, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    task.predictedMinutes != null && task.predictedMinutes != task.estimatedMinutes
                        ? '${formatMinutes(task.estimatedMinutes)} estimated → ${formatMinutes(task.predictedMinutes!)} predicted'
                        : '${formatMinutes(task.estimatedMinutes)} estimated',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                    child: Text(task.status, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
