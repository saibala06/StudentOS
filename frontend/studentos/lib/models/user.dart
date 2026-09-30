class AppUser {
  final int id;
  final String name;
  final String email;
  final String college;
  final String department;
  final int year;
  final int semester;
  final bool onboarded;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.college,
    required this.department,
    required this.year,
    required this.semester,
    required this.onboarded,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        college: j['college'] ?? '',
        department: j['department'] ?? '',
        year: j['year'] ?? 1,
        semester: j['semester'] ?? 1,
        onboarded: j['onboarded'] ?? false,
      );
}

class Preferences {
  final int preferredStartHour;
  final int preferredEndHour;
  final int maxDailyStudyMinutes;
  final int preferredSessionMinutes;
  final int breakMinutes;

  Preferences({
    required this.preferredStartHour,
    required this.preferredEndHour,
    required this.maxDailyStudyMinutes,
    required this.preferredSessionMinutes,
    required this.breakMinutes,
  });

  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
        preferredStartHour: j['preferred_start_hour'],
        preferredEndHour: j['preferred_end_hour'],
        maxDailyStudyMinutes: j['max_daily_study_minutes'],
        preferredSessionMinutes: j['preferred_session_minutes'],
        breakMinutes: j['break_minutes'],
      );

  Map<String, dynamic> toJson() => {
        'preferred_start_hour': preferredStartHour,
        'preferred_end_hour': preferredEndHour,
        'max_daily_study_minutes': maxDailyStudyMinutes,
        'preferred_session_minutes': preferredSessionMinutes,
        'break_minutes': breakMinutes,
      };
}
