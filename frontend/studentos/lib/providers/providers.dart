import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/domain_services.dart';

final apiClientProvider = Provider((ref) => ApiClient());

final authServiceProvider = Provider((ref) => AuthService(ref.watch(apiClientProvider)));
final userServiceProvider = Provider((ref) => UserService(ref.watch(apiClientProvider)));
final subjectServiceProvider = Provider((ref) => SubjectService(ref.watch(apiClientProvider)));
final taskServiceProvider = Provider((ref) => TaskService(ref.watch(apiClientProvider)));
final scheduleServiceProvider = Provider((ref) => ScheduleService(ref.watch(apiClientProvider)));
final rescheduleServiceProvider = Provider((ref) => RescheduleService(ref.watch(apiClientProvider)));
final attendanceServiceProvider = Provider((ref) => AttendanceService(ref.watch(apiClientProvider)));
final examServiceProvider = Provider((ref) => ExamService(ref.watch(apiClientProvider)));
final analyticsServiceProvider = Provider((ref) => AnalyticsService(ref.watch(apiClientProvider)));
final assistantServiceProvider = Provider((ref) => AssistantService(ref.watch(apiClientProvider)));
final dashboardServiceProvider = Provider((ref) => DashboardService(ref.watch(apiClientProvider)));
final notificationServiceProvider = Provider((ref) => NotificationService(ref.watch(apiClientProvider)));

/// Holds the current authenticated user (null = logged out). The splash
/// screen resolves this once at startup by calling /api/auth/me with any
/// stored token; login/register/logout screens update it directly.
class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _authService;
  AuthController(this._authService) : super(const AsyncValue.loading()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final user = await _authService.me();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    final user = await _authService.login(email, password);
    state = AsyncValue.data(user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String college = '',
    String department = '',
    int year = 1,
    int semester = 1,
  }) async {
    final user = await _authService.register(
      name: name, email: email, password: password,
      college: college, department: department, year: year, semester: semester,
    );
    state = AsyncValue.data(user);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  void setUser(AppUser user) => state = AsyncValue.data(user);
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AppUser?>>(
  (ref) => AuthController(ref.watch(authServiceProvider)),
);
