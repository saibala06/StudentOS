class Task {
  final int id;
  final String title;
  final String description;
  final int? subjectId;
  final String category;
  final DateTime? deadline;
  final String priority;
  final String difficulty;
  final int estimatedMinutes;
  final int? predictedMinutes;
  final int? actualMinutes;
  final int? remainingMinutes;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectId,
    required this.category,
    required this.deadline,
    required this.priority,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.predictedMinutes,
    required this.actualMinutes,
    required this.remainingMinutes,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.startedAt,
    required this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        subjectId: j['subject_id'],
        category: j['category'] ?? 'Assignment',
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline']) : null,
        priority: j['priority'] ?? 'Medium',
        difficulty: j['difficulty'] ?? 'Medium',
        estimatedMinutes: j['estimated_minutes'] ?? 60,
        predictedMinutes: j['predicted_minutes'],
        actualMinutes: j['actual_minutes'],
        remainingMinutes: j['remaining_minutes'],
        status: j['status'] ?? 'Not Started',
        notes: j['notes'] ?? '',
        createdAt: DateTime.parse(j['created_at']),
        startedAt: j['started_at'] != null ? DateTime.parse(j['started_at']) : null,
        completedAt: j['completed_at'] != null ? DateTime.parse(j['completed_at']) : null,
      );
}

class TaskPrediction {
  final int predictedMinutes;
  final String basis;
  final String confidence;

  TaskPrediction({required this.predictedMinutes, required this.basis, required this.confidence});

  factory TaskPrediction.fromJson(Map<String, dynamic> j) => TaskPrediction(
        predictedMinutes: j['predicted_minutes'],
        basis: j['basis'],
        confidence: j['confidence'],
      );
}

class ScheduleSlot {
  final int? taskId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isBreak;

  ScheduleSlot({
    required this.taskId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isBreak,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) => ScheduleSlot(
        taskId: j['task_id'],
        title: j['title'],
        startTime: DateTime.parse(j['start_time']),
        endTime: DateTime.parse(j['end_time']),
        isBreak: j['is_break'] ?? false,
      );
}
