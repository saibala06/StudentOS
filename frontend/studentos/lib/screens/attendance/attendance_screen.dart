import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../subjects/subjects_screen.dart';

final attendanceListProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(attendanceServiceProvider).list();
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAttendance = ref.watch(attendanceListProvider);
    final asyncSubjects = ref.watch(subjectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, asyncSubjects.valueOrNull ?? []),
        child: const Icon(Icons.add),
      ),
      body: asyncAttendance.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(message: '$e', onRetry: () => ref.invalidate(attendanceListProvider)),
        data: (records) {
          final subjects = asyncSubjects.valueOrNull ?? [];
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No attendance recorded',
              subtitle: 'Tap + to add attendance for a subject.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = records[i];
              final subject = subjects.where((s) => s.id == r.subjectId).cast<Subject?>().firstWhere((s) => s != null, orElse: () => null);
              final ok = r.percentage >= r.minimumRequiredPercent;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(subject?.name ?? 'Subject', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          Text('${r.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.w800, color: ok ? AppColors.success : AppColors.danger)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (r.percentage / 100).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          color: ok ? AppColors.success : AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${r.present} / ${r.total} classes attended • min. required ${r.minimumRequiredPercent.toStringAsFixed(0)}%',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 6),
                      if (ok)
                        Text('You can miss ${r.classesCanMiss} more class${r.classesCanMiss == 1 ? '' : 'es'} and stay above the minimum.',
                            style: const TextStyle(fontSize: 12, color: AppColors.success))
                      else
                        Text(
                          'You should prioritize attending upcoming classes — need ${r.classesNeededToRecover} in a row to recover.',
                          style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, List<Subject> subjects) {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a subject first.')));
      return;
    }
    int? subjectId = subjects.first.id;
    final presentCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '75');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: subjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => subjectId = v),
              ),
              const SizedBox(height: 10),
              TextField(controller: presentCtrl, decoration: const InputDecoration(labelText: 'Classes present'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: totalCtrl, decoration: const InputDecoration(labelText: 'Total classes'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Minimum required %'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final present = int.tryParse(presentCtrl.text);
                final total = int.tryParse(totalCtrl.text);
                final minReq = double.tryParse(minCtrl.text) ?? 75.0;
                if (subjectId == null || present == null || total == null || total <= 0) return;
                await ref.read(attendanceServiceProvider).upsert(subjectId: subjectId!, present: present, total: total, minRequired: minReq);
                ref.invalidate(attendanceListProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
