import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

final subjectsListProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(subjectServiceProvider).list();
});

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubjects = ref.watch(subjectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: asyncSubjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(message: '$e', onRetry: () => ref.invalidate(subjectsListProvider)),
        data: (subjects) {
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No subjects yet',
              subtitle: 'Add your subjects so tasks and attendance can be organized by them.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = subjects[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: s.colorValue.withOpacity(0.15), child: Icon(Icons.book, color: s.colorValue)),
                  title: Text(s.name),
                  subtitle: Text('${s.code.isNotEmpty ? '${s.code} • ' : ''}${s.difficulty} difficulty'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () async {
                      await ref.read(subjectServiceProvider).delete(s.id);
                      ref.invalidate(subjectsListProvider);
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String difficulty = 'Medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code (optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const ['Easy', 'Medium', 'Hard'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => difficulty = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(subjectServiceProvider).create(
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim(),
                      difficulty: difficulty,
                    );
                ref.invalidate(subjectsListProvider);
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
