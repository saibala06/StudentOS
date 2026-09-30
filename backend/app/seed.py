"""
Seeds a realistic demo account so personalization is visible on first login.

Run with:  python -m app.seed
Idempotent: safe to run multiple times (skips if demo user already exists).
"""
import datetime as dt
import random

from app.database import SessionLocal, init_db
from app import models, security
from app.services import scheduler as scheduler_service

DEMO_EMAIL = "demo@studentos.app"
DEMO_PASSWORD = "demo1234"


def run():
    init_db()
    db = SessionLocal()
    try:
        existing = db.query(models.User).filter(models.User.email == DEMO_EMAIL).first()
        if existing:
            print(f"Demo user already exists ({DEMO_EMAIL}). Skipping seed.")
            return

        user = models.User(
            name="Sai", email=DEMO_EMAIL, hashed_password=security.hash_password(DEMO_PASSWORD),
            college="Chennai Institute of Technology", department="Information Technology",
            year=3, semester=5, onboarded=True,
        )
        db.add(user)
        db.flush()

        db.add(models.StudentPreference(
            user_id=user.id, preferred_start_hour=18, preferred_end_hour=22,
            max_daily_study_minutes=180, preferred_session_minutes=50, break_minutes=10,
        ))

        subjects_data = [
            ("DBMS", "CS301", models.Difficulty.HARD, "#6C63FF"),
            ("Computer Networks", "CS302", models.Difficulty.MEDIUM, "#00B8A9"),
            ("Mobile Application Development", "CS303", models.Difficulty.MEDIUM, "#F6416C"),
            ("Artificial Intelligence", "CS304", models.Difficulty.HARD, "#FFDE7D"),
            ("Software Engineering", "CS305", models.Difficulty.EASY, "#3F8EFC"),
        ]
        subjects = {}
        for name, code, diff, color in subjects_data:
            s = models.Subject(user_id=user.id, name=name, code=code, difficulty=diff, color=color)
            db.add(s)
            db.flush()
            subjects[name] = s

        # attendance
        attendance_data = {
            "DBMS": (18, 24), "Computer Networks": (20, 26),
            "Mobile Application Development": (22, 24),
            "Artificial Intelligence": (15, 22),  # below 75% on purpose -> triggers recommendation
            "Software Engineering": (23, 24),
        }
        for name, (present, total) in attendance_data.items():
            db.add(models.Attendance(user_id=user.id, subject_id=subjects[name].id,
                                      present=present, total=total, minimum_required_percent=75.0))

        # ---- historical completed tasks: build a clear personalization signal ----
        # Programming/project tasks: student consistently takes ~1.5x estimate.
        # Reading/study tasks: student is a little faster than estimate (~0.9x).
        # DBMS specifically: ~1.3x. Mathematics-like (AI theory): ~1.6x.
        today = dt.date.today()
        random.seed(42)

        def add_history(subject_name, category, difficulty, title, est, factor, days_ago):
            actual = round(est * factor)
            completed_at = dt.datetime.combine(today - dt.timedelta(days=days_ago), dt.time(20, 0))
            task = models.Task(
                user_id=user.id, subject_id=subjects[subject_name].id, title=title,
                category=category, difficulty=difficulty, estimated_minutes=est,
                predicted_minutes=est, actual_minutes=actual, remaining_minutes=0,
                status=models.TaskStatus.COMPLETED, created_at=completed_at - dt.timedelta(days=2),
                started_at=completed_at - dt.timedelta(hours=1), completed_at=completed_at,
            )
            db.add(task)
            db.flush()
            db.add(models.TaskHistory(
                user_id=user.id, task_id=task.id, subject_id=subjects[subject_name].id,
                category=category, difficulty=difficulty, estimated_minutes=est, actual_minutes=actual,
                completed_at=completed_at,
            ))
            weekday = completed_at.weekday()
            avail = db.query(models.Availability).filter(models.Availability.user_id == user.id,
                                                           models.Availability.weekday == weekday).first()
            if not avail:
                avail = models.Availability(user_id=user.id, weekday=weekday, planned_minutes=0,
                                             actual_minutes=0, sample_count=0)
                db.add(avail)
            avail.planned_minutes += est
            avail.actual_minutes += actual
            avail.sample_count += 1

        programming_titles = ["Sorting Visualizer Lab", "REST API Assignment", "Socket Programming Task",
                               "Flutter Widget Exercise", "Algorithm Assignment", "Mini Compiler Task"]
        for i, title in enumerate(programming_titles):
            add_history("Mobile Application Development", models.TaskCategory.ASSIGNMENT,
                        models.Difficulty.MEDIUM, title, est=90, factor=1.5, days_ago=40 - i * 5)

        dbms_titles = ["ER Diagram Assignment", "Normalization Exercise", "SQL Query Sheet",
                       "Transactions Assignment", "Indexing Lab"]
        for i, title in enumerate(dbms_titles):
            add_history("DBMS", models.TaskCategory.ASSIGNMENT, models.Difficulty.HARD, title,
                        est=90, factor=1.3, days_ago=35 - i * 6)

        ai_titles = ["Search Algorithms Problem Set", "Neural Nets Theory Sheet", "Probability Assignment"]
        for i, title in enumerate(ai_titles):
            add_history("Artificial Intelligence", models.TaskCategory.STUDY, models.Difficulty.HARD, title,
                        est=90, factor=1.6, days_ago=30 - i * 7)

        reading_titles = ["Software Engineering Reading", "SE Case Study Notes"]
        for i, title in enumerate(reading_titles):
            add_history("Software Engineering", models.TaskCategory.STUDY, models.Difficulty.EASY, title,
                        est=60, factor=0.9, days_ago=20 - i * 5)

        db.flush()

        # exams
        db.add(models.Exam(user_id=user.id, subject_id=subjects["DBMS"].id,
                            exam_date=dt.datetime.combine(today + dt.timedelta(days=6), dt.time(9, 0)),
                            topics="Normalization, Transactions, Indexing", difficulty=models.Difficulty.HARD))

        # ---- current open tasks (the live demo state) ----
        def add_open_task(subject_name, category, difficulty, title, est, priority, days_until_deadline):
            deadline = dt.datetime.combine(today + dt.timedelta(days=days_until_deadline), dt.time(23, 59))
            task = models.Task(
                user_id=user.id, subject_id=subjects[subject_name].id, title=title,
                description="", category=category, deadline=deadline, priority=priority,
                difficulty=difficulty, estimated_minutes=est, predicted_minutes=est,
                remaining_minutes=est, status=models.TaskStatus.NOT_STARTED,
            )
            db.add(task)
            return task

        add_open_task("DBMS", models.TaskCategory.ASSIGNMENT, models.Difficulty.HARD,
                       "DBMS Assignment 3 — Query Optimization", 120, models.Priority.CRITICAL, 1)
        add_open_task("Computer Networks", models.TaskCategory.STUDY, models.Difficulty.MEDIUM,
                       "CN Revision — Routing Protocols", 90, models.Priority.HIGH, 2)
        add_open_task("Mobile Application Development", models.TaskCategory.PROJECT, models.Difficulty.MEDIUM,
                       "Flutter Project — Add Persistence Layer", 120, models.Priority.HIGH, 4)
        add_open_task("Artificial Intelligence", models.TaskCategory.ASSIGNMENT, models.Difficulty.HARD,
                       "AI Assignment — Search Algorithms", 90, models.Priority.MEDIUM, 5)
        add_open_task("Software Engineering", models.TaskCategory.LAB, models.Difficulty.EASY,
                       "SE Lab — UML Diagrams", 60, models.Priority.LOW, 7)

        db.commit()
        db.refresh(user)

        # generate the initial schedule so the dashboard has content on first login
        scheduler_service.generate_schedule(db, user, today, horizon_days=7)

        print("Seed complete.")
        print(f"Demo login -> email: {DEMO_EMAIL}  password: {DEMO_PASSWORD}")
    finally:
        db.close()


if __name__ == "__main__":
    run()
