import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../subjects/subjects_screen.dart';

final examsListProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(examServiceProvider).list();
});

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExams = ref.watch(examsListProvider);
    final asyncSubjects = ref.watch(subjectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref, asyncSubjects.valueOrNull ?? []),
        child: const Icon(Icons.add),
      ),
      body: asyncExams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(message: '$e', onRetry: () => ref.invalidate(examsListProvider)),
        data: (exams) {
          final subjects = asyncSubjects.valueOrNull ?? [];
          if (exams.isEmpty) {
            return const EmptyState(
              icon: Icons.edit_calendar_outlined,
              title: 'No exams scheduled',
              subtitle: 'Add an exam and StudentOS will boost prep-task urgency automatically.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: exams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final exam = exams[i];
              final subject = subjects.where((s) => s.id == exam.subjectId).cast<Subject?>().firstWhere((s) => s != null, orElse: () => null);
              final daysLeft = exam.examDate.difference(DateTime.now()).inDays;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: daysLeft <= 3 ? AppColors.danger.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                    child: Icon(Icons.edit_calendar, color: daysLeft <= 3 ? AppColors.danger : AppColors.primary),
                  ),
                  title: Text(subject?.name ?? 'Exam'),
                  subtitle: Text('${DateFormat('EEE, d MMM yyyy').format(exam.examDate)} • $daysLeft day${daysLeft == 1 ? '' : 's'} left'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () async {
                      await ref.read(examServiceProvider).delete(exam.id);
                      ref.invalidate(examsListProvider);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, List<Subject> subjects) {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a subject first.')));
      return;
    }
    int subjectId = subjects.first.id;
    final topicsCtrl = TextEditingController();
    DateTime examDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add exam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setState(() => subjectId = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: topicsCtrl, decoration: const InputDecoration(labelText: 'Topics')),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Exam date: ${DateFormat('d MMM yyyy').format(examDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: examDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => examDate = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await ref.read(examServiceProvider).create(subjectId: subjectId, examDate: examDate, topics: topicsCtrl.text.trim());
                ref.invalidate(examsListProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
