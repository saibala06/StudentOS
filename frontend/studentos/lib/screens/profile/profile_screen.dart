import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../subjects/subjects_screen.dart';
import '../attendance/attendance_screen.dart';
import '../exams/exams_screen.dart';
import '../auth/login_screen.dart';

final preferencesProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(userServiceProvider).getPreferences();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(
                (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '', style: TextStyle(color: Colors.grey.shade600)),
                  if (user != null && (user.department.isNotEmpty))
                    Text('${user.department} • Year ${user.year}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _NavCard(icon: Icons.menu_book_outlined, title: 'Subjects', subtitle: 'Manage your subjects',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubjectsScreen()))),
        const SizedBox(height: 10),
        _NavCard(icon: Icons.fact_check_outlined, title: 'Attendance', subtitle: 'Track attendance per subject',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceScreen()))),
        const SizedBox(height: 10),
        _NavCard(icon: Icons.edit_calendar_outlined, title: 'Exams', subtitle: 'Upcoming exams & prep',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamsScreen()))),

        const SizedBox(height: 24),
        const Text('Study preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        const _PreferencesCard(),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
            }
          },
          icon: const Icon(Icons.logout, color: AppColors.danger),
          label: const Text('Log out', style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.12), child: Icon(icon, color: AppColors.primary)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PreferencesCard extends ConsumerStatefulWidget {
  const _PreferencesCard();

  @override
  ConsumerState<_PreferencesCard> createState() => _PreferencesCardState();
}

class _PreferencesCardState extends ConsumerState<_PreferencesCard> {
  @override
  Widget build(BuildContext context) {
    final asyncPrefs = ref.watch(preferencesProvider);
    return asyncPrefs.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
      error: (e, st) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('$e'))),
      data: (prefs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row('Study window', '${prefs.preferredStartHour}:00 – ${prefs.preferredEndHour}:00'),
              const Divider(height: 20),
              _row('Max daily study time', '${(prefs.maxDailyStudyMinutes / 60).toStringAsFixed(1)}h'),
              const Divider(height: 20),
              _row('Session length', '${prefs.preferredSessionMinutes} min'),
              const Divider(height: 20),
              _row('Break length', '${prefs.breakMinutes} min'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _editDialog(context, prefs),
                  child: const Text('Edit preferences'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _editDialog(BuildContext context, Preferences prefs) {
    int start = prefs.preferredStartHour;
    int end = prefs.preferredEndHour;
    int maxDaily = prefs.maxDailyStudyMinutes;
    int session = prefs.preferredSessionMinutes;
    int breakMin = prefs.breakMinutes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Study preferences'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slider('Start hour', start.toDouble(), 0, 23, (v) => setState(() => start = v.round()), suffix: ':00'),
                _slider('End hour', end.toDouble(), 0, 23, (v) => setState(() => end = v.round()), suffix: ':00'),
                _slider('Max daily minutes', maxDaily.toDouble(), 60, 480, (v) => setState(() => maxDaily = v.round())),
                _slider('Session minutes', session.toDouble(), 20, 90, (v) => setState(() => session = v.round())),
                _slider('Break minutes', breakMin.toDouble(), 5, 30, (v) => setState(() => breakMin = v.round())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await ref.read(userServiceProvider).updatePreferences(Preferences(
                      preferredStartHour: start,
                      preferredEndHour: end,
                      maxDailyStudyMinutes: maxDaily,
                      preferredSessionMinutes: session,
                      breakMinutes: breakMin,
                    ));
                ref.invalidate(preferencesProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged, {String suffix = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}$suffix', style: const TextStyle(fontSize: 13)),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
