import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/subject.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _estimate = TextEditingController(text: '60');

  List<Subject> _subjects = [];
  int? _subjectId;
  String _category = 'Assignment';
  String _priority = 'Medium';
  String _difficulty = 'Medium';
  DateTime? _deadline;
  bool _loadingSubjects = true;
  bool _saving = false;
  TaskPrediction? _prediction;
  bool _predicting = false;

  final _categories = const ['Assignment', 'Study', 'Project', 'Exam Preparation', 'Lab', 'Personal Academic Task'];
  final _priorities = const ['Low', 'Medium', 'High', 'Critical'];
  final _difficulties = const ['Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _estimate.addListener(_debouncedPredict);
  }

  Future<void> _loadSubjects() async {
    final subjects = await ref.read(subjectServiceProvider).list();
    setState(() {
      _subjects = subjects;
      _loadingSubjects = false;
    });
    _predict();
  }

  void _debouncedPredict() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _predict();
    });
  }

  Future<void> _predict() async {
    final minutes = int.tryParse(_estimate.text);
    if (minutes == null || minutes <= 0) return;
    setState(() => _predicting = true);
    try {
      final result = await ref.read(taskServiceProvider).predict(
            title: _title.text.isEmpty ? 'Untitled task' : _title.text,
            subjectId: _subjectId,
            category: _category,
            difficulty: _difficulty,
            estimatedMinutes: minutes,
          );
      if (mounted) setState(() => _prediction = result);
    } catch (_) {
      // silently ignore — prediction is a nice-to-have preview
    } finally {
      if (mounted) setState(() => _predicting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(taskServiceProvider).create(
            title: _title.text.trim(),
            subjectId: _subjectId,
            category: _category,
            deadline: _deadline,
            priority: _priority,
            difficulty: _difficulty,
            estimatedMinutes: int.parse(_estimate.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create task: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: _loadingSubjects
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                        onChanged: (_) => _debouncedPredict(),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int?>(
                        value: _subjectId,
                        decoration: const InputDecoration(labelText: 'Subject (optional)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No subject')),
                          ..._subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) {
                          setState(() => _subjectId = v);
                          _predict();
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          setState(() => _category = v!);
                          _predict();
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _priority,
                              decoration: const InputDecoration(labelText: 'Priority'),
                              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) => setState(() => _priority = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _difficulty,
                              decoration: const InputDecoration(labelText: 'Difficulty'),
                              items: _difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                              onChanged: (v) {
                                setState(() => _difficulty = v!);
                                _predict();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _estimate,
                        decoration: const InputDecoration(labelText: 'Your estimate (minutes)'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid number of minutes';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_deadline == null ? 'No deadline' : 'Deadline: ${_deadline!.toLocal()}'.split('.').first),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => _deadline = date);
                        },
                      ),
                      const SizedBox(height: 8),
                      _predictionCard(),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create task'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _predictionCard() {
    if (_predicting && _prediction == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator());
    }
    if (_prediction == null) return const SizedBox();
    final p = _prediction!;
    final estimate = int.tryParse(_estimate.text) ?? 0;
    final differs = p.predictedMinutes != estimate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  differs
                      ? 'Based on your previous tasks, this usually takes you around ${formatMinutes(p.predictedMinutes)}.'
                      : 'Predicted duration: ${formatMinutes(p.predictedMinutes)}.',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(p.basis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
