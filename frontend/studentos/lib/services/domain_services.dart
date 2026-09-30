import '../models/user.dart';
import '../models/subject.dart';
import '../models/task.dart';
import '../models/misc_models.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient api;
  AuthService(this.api);

  Future<AppUser> login(String email, String password) async {
    final res = await api.post('/api/auth/login', body: {'email': email, 'password': password});
    await api.saveToken(res['access_token']);
    return AppUser.fromJson(res['user']);
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String college = '',
    String department = '',
    int year = 1,
    int semester = 1,
  }) async {
    final res = await api.post('/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'college': college,
      'department': department,
      'year': year,
      'semester': semester,
    });
    await api.saveToken(res['access_token']);
    return AppUser.fromJson(res['user']);
  }

  Future<AppUser?> me() async {
    final t = await api.token;
    if (t == null) return null;
    try {
      final res = await api.get('/api/auth/me');
      return AppUser.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => api.clearToken();
}

class UserService {
  final ApiClient api;
  UserService(this.api);

  Future<Preferences> getPreferences() async => Preferences.fromJson(await api.get('/api/users/preferences'));

  Future<Preferences> updatePreferences(Preferences p) async =>
      Preferences.fromJson(await api.put('/api/users/preferences', body: p.toJson()));

  Future<AppUser> updateProfile(Map<String, dynamic> fields) async =>
      AppUser.fromJson(await api.put('/api/users/profile', body: fields));
}

class SubjectService {
  final ApiClient api;
  SubjectService(this.api);

  Future<List<Subject>> list() async =>
      (await api.get('/api/subjects') as List).map((e) => Subject.fromJson(e)).toList();

  Future<Subject> create({required String name, String code = '', String color = '#6C63FF', String difficulty = 'Medium'}) async =>
      Subject.fromJson(await api.post('/api/subjects', body: {
        'name': name,
        'code': code,
        'color': color,
        'icon': 'book',
        'difficulty': difficulty,
      }));

  Future<void> delete(int id) => api.delete('/api/subjects/$id');
}

class TaskService {
  final ApiClient api;
  TaskService(this.api);

  Future<List<Task>> list({String? status}) async {
    final res = await api.get('/api/tasks', query: status != null ? {'status': status} : null);
    return (res as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<Task> get(int id) async => Task.fromJson(await api.get('/api/tasks/$id'));

  Future<TaskPrediction> predict({
    required String title,
    int? subjectId,
    required String category,
    required String difficulty,
    required int estimatedMinutes,
  }) async =>
      TaskPrediction.fromJson(await api.post('/api/tasks/predict', body: {
        'title': title,
        'subject_id': subjectId,
        'category': category,
        'difficulty': difficulty,
        'estimated_minutes': estimatedMinutes,
        'priority': 'Medium',
      }));

  Future<Task> create({
    required String title,
    String description = '',
    int? subjectId,
    String category = 'Assignment',
    DateTime? deadline,
    String priority = 'Medium',
    String difficulty = 'Medium',
    required int estimatedMinutes,
    String notes = '',
  }) async =>
      Task.fromJson(await api.post('/api/tasks', body: {
        'title': title,
        'description': description,
        'subject_id': subjectId,
        'category': category,
        'deadline': deadline?.toIso8601String(),
        'priority': priority,
        'difficulty': difficulty,
        'estimated_minutes': estimatedMinutes,
        'notes': notes,
      }));

  Future<Task> start(int id) async => Task.fromJson(await api.post('/api/tasks/$id/start'));

  Future<Task> complete(int id, int actualMinutes) async =>
      Task.fromJson(await api.post('/api/tasks/$id/complete', body: {'actual_minutes': actualMinutes}));

  Future<void> delete(int id) => api.delete('/api/tasks/$id');
}

class ScheduleService {
  final ApiClient api;
  ScheduleService(this.api);

  Future<List<ScheduleSlot>> generate({int days = 7}) async {
    final res = await api.post('/api/schedule/generate?days=$days');
    return (res as List).map((e) => ScheduleSlot.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getSchedule({int days = 7}) async {
    final res = await api.get('/api/schedule', query: {'days': '$days'});
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<String>> warnings() async => (await api.get('/api/schedule/warnings') as List).cast<String>();
}

class RescheduleService {
  final ApiClient api;
  RescheduleService(this.api);

  Future<Map<String, dynamic>> somethingCameUp({
    required String reasonCategory,
    String reasonText = '',
    required int minutesLost,
    DateTime? affectedDate,
  }) async =>
      Map<String, dynamic>.from(await api.post('/api/reschedule/something-came-up', body: {
        'reason_category': reasonCategory,
        'reason_text': reasonText,
        'minutes_lost': minutesLost,
        if (affectedDate != null) 'affected_date': affectedDate.toIso8601String().substring(0, 10),
      }));

  Future<void> decide(int eventId, bool accept) =>
      api.post('/api/reschedule/$eventId/decision', body: {'accept': accept});

  Future<void> manualReschedule(int taskId, DateTime newDate) => api.post('/api/reschedule/manual', body: {
        'task_id': taskId,
        'new_date': newDate.toIso8601String().substring(0, 10),
      });
}

class AttendanceService {
  final ApiClient api;
  AttendanceService(this.api);

  Future<List<AttendanceRecord>> list() async =>
      (await api.get('/api/attendance') as List).map((e) => AttendanceRecord.fromJson(e)).toList();

  Future<AttendanceRecord> upsert({required int subjectId, required int present, required int total, double minRequired = 75.0}) async =>
      AttendanceRecord.fromJson(await api.put('/api/attendance', body: {
        'subject_id': subjectId,
        'present': present,
        'total': total,
        'minimum_required_percent': minRequired,
      }));
}

class ExamService {
  final ApiClient api;
  ExamService(this.api);

  Future<List<Exam>> list() async => (await api.get('/api/exams') as List).map((e) => Exam.fromJson(e)).toList();

  Future<Exam> create({
    required int subjectId,
    required DateTime examDate,
    String topics = '',
    String difficulty = 'Medium',
  }) async =>
      Exam.fromJson(await api.post('/api/exams', body: {
        'subject_id': subjectId,
        'exam_date': examDate.toIso8601String(),
        'topics': topics,
        'difficulty': difficulty,
      }));

  Future<void> delete(int id) => api.delete('/api/exams/$id');
}

class AnalyticsService {
  final ApiClient api;
  AnalyticsService(this.api);

  Future<Analytics> get() async => Analytics.fromJson(await api.get('/api/analytics'));
}

class AssistantService {
  final ApiClient api;
  AssistantService(this.api);

  Future<Map<String, dynamic>> ask(String message) async =>
      Map<String, dynamic>.from(await api.post('/api/assistant/ask', body: {'message': message}));
}

class DashboardService {
  final ApiClient api;
  DashboardService(this.api);

  Future<DashboardData> get() async => DashboardData.fromJson(await api.get('/api/dashboard'));
}

class NotificationService {
  final ApiClient api;
  NotificationService(this.api);

  Future<List<AppNotification>> list() async =>
      (await api.get('/api/notifications') as List).map((e) => AppNotification.fromJson(e)).toList();

  Future<void> markRead(int id) => api.post('/api/notifications/$id/read');
}
