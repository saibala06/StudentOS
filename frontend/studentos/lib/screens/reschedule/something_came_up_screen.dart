import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class SomethingCameUpScreen extends ConsumerStatefulWidget {
  const SomethingCameUpScreen({super.key});

  @override
  ConsumerState<SomethingCameUpScreen> createState() => _SomethingCameUpScreenState();
}

enum _Step { reason, duration, result }

class _SomethingCameUpScreenState extends ConsumerState<SomethingCameUpScreen> {
  _Step _step = _Step.reason;
  String? _reason;
  int? _minutesLost;
  final _customController = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  final _reasons = const [
    ('College work', Icons.school_outlined),
    ('Family event', Icons.family_restroom_outlined),
    ('Travel', Icons.directions_bus_outlined),
    ('Personal work', Icons.work_outline),
    ('Feeling tired', Icons.bedtime_outlined),
    ('Unexpected task', Icons.assignment_late_outlined),
    ('Other', Icons.more_horiz),
  ];

  final _durations = const [30, 60, 120, 180];

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(rescheduleServiceProvider).somethingCameUp(
            reasonCategory: _reason!,
            reasonText: _customController.text.trim(),
            minutesLost: _minutesLost!,
          );
      setState(() {
        _result = result;
        _step = _Step.result;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(bool accept) async {
    final eventId = _result!['event_id'] as int;
    setState(() => _loading = true);
    try {
      await ref.read(rescheduleServiceProvider).decide(eventId, accept);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'New schedule applied.' : 'Kept your original schedule.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Something came up')),
      body: SafeArea(
        child: switch (_step) {
          _Step.reason => _reasonStep(),
          _Step.duration => _durationStep(),
          _Step.result => _resultStep(),
        },
      ),
    );
  }

  Widget _reasonStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What happened?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _reasons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final (label, icon) = _reasons[i];
                return Card(
                  child: ListTile(
                    leading: Icon(icon, color: AppColors.primary),
                    title: Text(label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() {
                      _reason = label;
                      _step = _Step.duration;
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How much time will "$_reason" affect?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._durations.map((m) => ChoiceChip(
                    label: Text(m < 60 ? '$m minutes' : '${m ~/ 60} hour${m > 60 ? 's' : ''}'),
                    selected: _minutesLost == m,
                    onSelected: (_) => setState(() => _minutesLost = m),
                  )),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _minutesLost != null && !_durations.contains(_minutesLost),
                onSelected: (_) => setState(() => _minutesLost = -1),
              ),
            ],
          ),
          if (_minutesLost == -1) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Custom minutes lost'),
              onChanged: (v) {}, // value read at submit time via a separate field below
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const Spacer(),
          ElevatedButton(
            onPressed: (_minutesLost == null || _loading)
                ? null
                : () {
                    if (_minutesLost == -1) {
                      final custom = int.tryParse(_customController.text);
                      if (custom == null || custom <= 0) return;
                      _minutesLost = custom;
                    }
                    _submit();
                  },
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('See adjusted schedule'),
          ),
        ],
      ),
    );
  }

  Widget _resultStep() {
    final oldSchedule = (_result!['old_schedule'] as List).cast<Map<String, dynamic>>();
    final newSchedule = (_result!['new_schedule'] as List).cast<Map<String, dynamic>>();
    final warnings = (_result!['warnings'] as List).cast<String>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your schedule needs to be adjusted.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Here is the old plan compared to the new one.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          if (warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                    SizedBox(width: 8),
                    Text('Deadline risk', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                  ]),
                  const SizedBox(height: 8),
                  ...warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(w, style: const TextStyle(fontSize: 13)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Expanded(child: _scheduleColumn('OLD', oldSchedule, Colors.grey)),
              const SizedBox(width: 12),
              Expanded(child: _scheduleColumn('NEW', newSchedule, AppColors.primary)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _decide(false),
                  child: const Text('Keep original'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _decide(true),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Accept new'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleColumn(String label, List<Map<String, dynamic>> slots, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color, letterSpacing: 1)),
        const SizedBox(height: 10),
        if (slots.isEmpty)
          Text('Nothing scheduled', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
        else
          ...slots.take(10).map((s) {
            final start = DateTime.parse(s['start_time']);
            final isBreak = s['is_break'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isBreak ? Colors.grey.shade100 : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEE d, h:mm a').format(start), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  Text(s['title'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
