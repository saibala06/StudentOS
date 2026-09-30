import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

final taskDetailProvider = FutureProvider.family.autoDispose((ref, int taskId) async {
  return ref.watch(taskServiceProvider).get(taskId);
});

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref.read(taskServiceProvider).start(widget.taskId);
      ref.invalidate(taskDetailProvider(widget.taskId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Task task) async {
    final controller = TextEditingController(text: '${task.predictedMinutes ?? task.estimatedMinutes}');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How long did this task actually take?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual minutes'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result <= 0) return;

    setState(() => _busy = true);
    try {
      await ref.read(taskServiceProvider).complete(widget.taskId, result);
      ref.invalidate(taskDetailProvider(widget.taskId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nice work! Your personal learning stats just updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTask = ref.watch(taskDetailProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: asyncTask.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(message: '$e'),
        data: (task) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(task.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                  PriorityChip(task.priority),
                ],
              ),
              const SizedBox(height: 6),
              Text(task.category, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 20),

              _infoRow(Icons.timelapse, 'Your estimate', formatMinutes(task.estimatedMinutes)),
              if (task.predictedMinutes != null)
                _infoRow(Icons.auto_awesome, 'Predicted (personalized)', formatMinutes(task.predictedMinutes!)),
              if (task.actualMinutes != null)
                _infoRow(Icons.check_circle_outline, 'Actual time taken', formatMinutes(task.actualMinutes!)),
              if (task.deadline != null)
                _infoRow(Icons.event_outlined, 'Deadline', DateFormat('EEE, d MMM yyyy • h:mm a').format(task.deadline!)),
              _infoRow(Icons.speed_outlined, 'Difficulty', task.difficulty),
              _infoRow(Icons.flag_outlined, 'Status', task.status),

              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(task.description),
              ],

              const SizedBox(height: 28),
              if (task.status == 'Not Started')
                ElevatedButton.icon(
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start task'),
                ),
              if (task.status == 'In Progress')
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _complete(task),
                  icon: const Icon(Icons.check),
                  label: const Text('Mark complete'),
                ),
              if (task.status == 'Completed')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 10),
                      Expanded(child: Text('Completed — great job!')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
