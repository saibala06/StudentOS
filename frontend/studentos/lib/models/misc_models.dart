class Exam {
  final int id;
  final int subjectId;
  final DateTime examDate;
  final String topics;
  final String difficulty;
  final String preparationStatus;

  Exam({
    required this.id,
    required this.subjectId,
    required this.examDate,
    required this.topics,
    required this.difficulty,
    required this.preparationStatus,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: j['id'],
        subjectId: j['subject_id'],
        examDate: DateTime.parse(j['exam_date']),
        topics: j['topics'] ?? '',
        difficulty: j['difficulty'] ?? 'Medium',
        preparationStatus: j['preparation_status'] ?? 'Not Started',
      );
}

class AttendanceRecord {
  final int subjectId;
  final int present;
  final int total;
  final double minimumRequiredPercent;
  final double percentage;
  final int classesCanMiss;
  final int classesNeededToRecover;

  AttendanceRecord({
    required this.subjectId,
    required this.present,
    required this.total,
    required this.minimumRequiredPercent,
    required this.percentage,
    required this.classesCanMiss,
    required this.classesNeededToRecover,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        subjectId: j['subject_id'],
        present: j['present'],
        total: j['total'],
        minimumRequiredPercent: (j['minimum_required_percent'] as num).toDouble(),
        percentage: (j['percentage'] as num).toDouble(),
        classesCanMiss: j['classes_can_miss'],
        classesNeededToRecover: j['classes_needed_to_recover'],
      );
}

class Analytics {
  final int tasksCompleted;
  final double averageEstimationErrorPercent;
  final double averageDailyStudyMinutes;
  final int weeklyPlannedMinutes;
  final int weeklyCompletedMinutes;
  final double completionRatePercent;
  final Map<String, dynamic> subjectWiseAvgMinutes;
  final double scheduleAdherencePercent;
  final String headline;

  Analytics({
    required this.tasksCompleted,
    required this.averageEstimationErrorPercent,
    required this.averageDailyStudyMinutes,
    required this.weeklyPlannedMinutes,
    required this.weeklyCompletedMinutes,
    required this.completionRatePercent,
    required this.subjectWiseAvgMinutes,
    required this.scheduleAdherencePercent,
    required this.headline,
  });

  factory Analytics.fromJson(Map<String, dynamic> j) => Analytics(
        tasksCompleted: j['tasks_completed'],
        averageEstimationErrorPercent: (j['average_estimation_error_percent'] as num).toDouble(),
        averageDailyStudyMinutes: (j['average_daily_study_minutes'] as num).toDouble(),
        weeklyPlannedMinutes: j['weekly_planned_minutes'],
        weeklyCompletedMinutes: j['weekly_completed_minutes'],
        completionRatePercent: (j['completion_rate_percent'] as num).toDouble(),
        subjectWiseAvgMinutes: Map<String, dynamic>.from(j['subject_wise_avg_minutes'] ?? {}),
        scheduleAdherencePercent: (j['schedule_adherence_percent'] as num).toDouble(),
        headline: j['headline'],
      );
}

class DashboardData {
  final String greetingName;
  final int todayCapacityMinutes;
  final int todayPlannedMinutes;
  final List<dynamic> todaySchedule;
  final Map<String, dynamic>? priorityTask;
  final int weekPlannedMinutes;
  final int weekCompletedMinutes;
  final List<dynamic> upcomingDeadlines;

  DashboardData({
    required this.greetingName,
    required this.todayCapacityMinutes,
    required this.todayPlannedMinutes,
    required this.todaySchedule,
    required this.priorityTask,
    required this.weekPlannedMinutes,
    required this.weekCompletedMinutes,
    required this.upcomingDeadlines,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        greetingName: j['greeting_name'],
        todayCapacityMinutes: j['today_capacity_minutes'],
        todayPlannedMinutes: j['today_planned_minutes'],
        todaySchedule: j['today_schedule'] ?? [],
        priorityTask: j['priority_task'],
        weekPlannedMinutes: j['week_planned_minutes'],
        weekCompletedMinutes: j['week_completed_minutes'],
        upcomingDeadlines: j['upcoming_deadlines'] ?? [],
      );
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final String kind;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        kind: j['kind'],
        read: j['read'],
        createdAt: DateTime.parse(j['created_at']),
      );
}
