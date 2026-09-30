import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

final analyticsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(analyticsServiceProvider).get();
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnalytics = ref.watch(analyticsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(analyticsProvider),
      child: asyncAnalytics.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.only(top: 120), child: CircularProgressIndicator())),
        error: (e, st) => ListView(children: [ErrorState(message: '$e', onRetry: () => ref.invalidate(analyticsProvider))]),
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            const Text('Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // Personal accuracy headline
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Accuracy', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(a.headline, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _statCard('Tasks completed', '${a.tasksCompleted}', Icons.check_circle_outline, AppColors.success),
                _statCard('Completion rate', '${a.completionRatePercent.toStringAsFixed(0)}%', Icons.trending_up, AppColors.secondary),
                _statCard('Avg. daily study', formatMinutes(a.averageDailyStudyMinutes.round()), Icons.timer_outlined, AppColors.primary),
                _statCard('Schedule adherence', '${a.scheduleAdherencePercent.toStringAsFixed(0)}%', Icons.rule, AppColors.warning),
              ],
            ),
            const SizedBox(height: 24),

            SectionTitle('This week'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatMinutes(a.weeklyCompletedMinutes)} completed of ${formatMinutes(a.weeklyPlannedMinutes)} planned',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    CapacityBar(planned: a.weeklyCompletedMinutes, capacity: a.weeklyPlannedMinutes == 0 ? 1 : a.weeklyPlannedMinutes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (a.subjectWiseAvgMinutes.isNotEmpty) ...[
              SectionTitle('Subject-wise average duration'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
                  child: SizedBox(
                    height: 220,
                    child: BarChart(_buildBarChartData(a.subjectWiseAvgMinutes)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  BarChartData _buildBarChartData(Map<String, dynamic> data) {
    final entries = data.entries.toList();
    final maxY = entries.map((e) => (e.value as num).toDouble()).fold(10.0, (a, b) => a > b ? a : b) * 1.2;
    return BarChartData(
      maxY: maxY,
      barGroups: List.generate(entries.length, (i) {
        final value = (entries[i].value as num).toDouble();
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: value, color: AppColors.primary, width: 18, borderRadius: BorderRadius.circular(6)),
        ]);
      }),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= entries.length) return const SizedBox();
              final name = entries[i].key;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(name.length > 8 ? '${name.substring(0, 8)}…' : name, style: const TextStyle(fontSize: 9)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
    );
  }
}
