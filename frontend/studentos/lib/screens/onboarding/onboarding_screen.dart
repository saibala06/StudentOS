import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  final _departmentCtrl = TextEditingController();
  int _year = 3;
  final _subjectNameCtrl = TextEditingController();
  final List<String> _subjects = [];
  int _startHour = 18;
  int _endHour = 22;
  int _sessionMinutes = 50;
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final userService = ref.read(userServiceProvider);
      final subjectService = ref.read(subjectServiceProvider);

      await userService.updateProfile({
        'department': _departmentCtrl.text.trim(),
        'year': _year,
        'onboarded': true,
      });
      final currentPrefs = await userService.getPreferences();
      await userService.updatePreferences(Preferences(
        preferredStartHour: _startHour,
        preferredEndHour: _endHour,
        maxDailyStudyMinutes: currentPrefs.maxDailyStudyMinutes,
        preferredSessionMinutes: _sessionMinutes,
        breakMinutes: currentPrefs.breakMinutes,
      ));

      for (final s in _subjects) {
        await subjectService.create(name: s);
      }

      final authService = ref.read(authServiceProvider);
      final refreshed = await authService.me();
      if (refreshed != null) ref.read(authControllerProvider.notifier).setUser(refreshed);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_welcomePage(), _profilePage(), _subjectsPage(), _preferencesPage()];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(pages.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _page ? AppColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (_page < pages.length - 1) {
                          setState(() => _page++);
                          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                        } else {
                          _finish();
                        }
                      },
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_page < pages.length - 1 ? 'Continue' : "Let's go"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage() => _pageShell(
        icon: Icons.auto_awesome,
        title: 'Welcome to StudentOS',
        subtitle:
            "StudentOS learns from your completed tasks and gradually improves your schedule. The more you use it, the more personal your plan becomes.",
        child: const SizedBox(),
      );

  Widget _profilePage() => _pageShell(
        icon: Icons.school_outlined,
        title: 'Tell us about you',
        subtitle: 'Just the basics — you can change these later.',
        child: Column(
          children: [
            TextField(
              controller: _departmentCtrl,
              decoration: const InputDecoration(labelText: 'Department (e.g. CSE, IT)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Year:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _year.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_year',
                    onChanged: (v) => setState(() => _year = v.round()),
                  ),
                ),
                Text('$_year'),
              ],
            ),
          ],
        ),
      );

  Widget _subjectsPage() => _pageShell(
        icon: Icons.menu_book_outlined,
        title: 'Add your subjects',
        subtitle: 'You can add more anytime from the Subjects screen.',
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectNameCtrl,
                    decoration: const InputDecoration(labelText: 'Subject name'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    if (_subjectNameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      _subjects.add(_subjectNameCtrl.text.trim());
                      _subjectNameCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjects
                  .map((s) => Chip(
                        label: Text(s),
                        onDeleted: () => setState(() => _subjects.remove(s)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _preferencesPage() => _pageShell(
        icon: Icons.schedule_outlined,
        title: 'When do you like to study?',
        subtitle: 'This shapes when StudentOS schedules your sessions.',
        child: Column(
          children: [
            _hourPicker('Preferred start', _startHour, (v) => setState(() => _startHour = v)),
            const SizedBox(height: 12),
            _hourPicker('Preferred end', _endHour, (v) => setState(() => _endHour = v)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Session length:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _sessionMinutes.toDouble(),
                    min: 20,
                    max: 90,
                    divisions: 7,
                    label: '$_sessionMinutes min',
                    onChanged: (v) => setState(() => _sessionMinutes = v.round()),
                  ),
                ),
                Text('$_sessionMinutes min'),
              ],
            ),
          ],
        ),
      );

  Widget _hourPicker(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: value,
          items: List.generate(24, (h) => h)
              .map((h) => DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ],
    );
  }

  Widget _pageShell({required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}


