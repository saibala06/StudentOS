import datetime as dt
from app import models, security
from app.services import scheduler


def _make_user(db, email="sched@test.com"):
    user = models.User(name="Test", email=email, hashed_password=security.hash_password("pw"))
    db.add(user)
    db.flush()
    prefs = models.StudentPreference(user_id=user.id, preferred_start_hour=18, preferred_end_hour=22,
                                      max_daily_study_minutes=180, preferred_session_minutes=50,
                                      break_minutes=10)
    db.add(prefs)
    db.commit()
    db.refresh(user)
    return user


def test_critical_task_scores_higher_than_low_priority(db):
    user = _make_user(db)
    now = dt.datetime.utcnow()
    deadline = now + dt.timedelta(days=1)

    critical = models.Task(user_id=user.id, title="Critical", priority=models.Priority.CRITICAL,
                            difficulty=models.Difficulty.HARD, deadline=deadline,
                            estimated_minutes=60, remaining_minutes=60)
    low = models.Task(user_id=user.id, title="Low", priority=models.Priority.LOW,
                       difficulty=models.Difficulty.EASY, deadline=now + dt.timedelta(days=10),
                       estimated_minutes=60, remaining_minutes=60)

    def cap(_weekday):
        return 180

    assert scheduler.score_task(critical, now, cap) > scheduler.score_task(low, now, cap)


def test_generate_schedule_respects_daily_capacity(db):
    user = _make_user(db, "sched2@test.com")
    task = models.Task(user_id=user.id, title="Big Task", priority=models.Priority.HIGH,
                        difficulty=models.Difficulty.MEDIUM, estimated_minutes=400,
                        remaining_minutes=400, status=models.TaskStatus.NOT_STARTED)
    db.add(task)
    db.commit()

    today = dt.date.today()
    planned = scheduler.generate_schedule(db, user, today, horizon_days=7, persist=False)

    # sum work (non-break) minutes scheduled on day 1
    day1_minutes = sum(
        int((p.end - p.start).total_seconds() // 60)
        for p in planned if not p.is_break and p.start.date() == today
    )
    assert day1_minutes <= 180  # never exceeds max_daily_study_minutes


def test_generate_schedule_creates_breaks_between_sessions(db):
    user = _make_user(db, "sched3@test.com")
    task = models.Task(user_id=user.id, title="Task", priority=models.Priority.MEDIUM,
                        difficulty=models.Difficulty.MEDIUM, estimated_minutes=120,
                        remaining_minutes=120, status=models.TaskStatus.NOT_STARTED)
    db.add(task)
    db.commit()

    planned = scheduler.generate_schedule(db, user, dt.date.today(), horizon_days=3, persist=False)
    breaks = [p for p in planned if p.is_break]
    assert len(breaks) >= 1
    for b in breaks:
        assert (b.end - b.start).total_seconds() / 60 == 10
