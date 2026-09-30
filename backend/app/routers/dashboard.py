import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, security
from app.services import learning

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("")
def dashboard(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    today = dt.date.today()
    prefs = current_user.preferences

    todays_sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == current_user.id, models.StudySession.status == "Planned",
        models.StudySession.start_time >= dt.datetime.combine(today, dt.time.min),
        models.StudySession.start_time < dt.datetime.combine(today, dt.time.max),
    ).order_by(models.StudySession.start_time).all()

    todays_planned_minutes = sum(
        int((s.end_time - s.start_time).total_seconds() // 60) for s in todays_sessions if not s.is_break
    )
    capacity_today = learning.daily_capacity_minutes(
        db, current_user.id, today.weekday(), prefs.max_daily_study_minutes)["capacity_minutes"]

    schedule = [{
        "task_id": s.task_id,
        "title": "Break" if s.is_break else (s.task.title if s.task else "Task"),
        "start_time": s.start_time.isoformat(), "end_time": s.end_time.isoformat(), "is_break": s.is_break,
    } for s in todays_sessions]

    top_task = db.query(models.Task).filter(
        models.Task.user_id == current_user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
        models.Task.priority.in_([models.Priority.CRITICAL, models.Priority.HIGH]),
    ).order_by(models.Task.deadline.is_(None), models.Task.deadline).first()

    week_start = dt.datetime.combine(today - dt.timedelta(days=today.weekday()), dt.time.min)
    week_end = week_start + dt.timedelta(days=7)
    week_sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == current_user.id, models.StudySession.is_break.is_(False),
        models.StudySession.start_time >= week_start, models.StudySession.start_time < week_end,
    ).all()
    week_planned = sum(int((s.end_time - s.start_time).total_seconds() // 60) for s in week_sessions)
    week_completed_tasks = db.query(models.Task).filter(
        models.Task.user_id == current_user.id, models.Task.status == models.TaskStatus.COMPLETED,
        models.Task.completed_at >= week_start, models.Task.completed_at < week_end,
    ).all()
    week_completed = sum(t.actual_minutes or 0 for t in week_completed_tasks)

    upcoming = db.query(models.Task).filter(
        models.Task.user_id == current_user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
        models.Task.deadline.isnot(None),
    ).order_by(models.Task.deadline).limit(5).all()

    return {
        "greeting_name": current_user.name,
        "today_capacity_minutes": capacity_today,
        "today_planned_minutes": todays_planned_minutes,
        "today_schedule": schedule,
        "priority_task": {"id": top_task.id, "title": top_task.title,
                           "deadline": top_task.deadline.isoformat() if top_task.deadline else None} if top_task else None,
        "week_planned_minutes": week_planned,
        "week_completed_minutes": week_completed,
        "upcoming_deadlines": [
            {"id": t.id, "title": t.title, "deadline": t.deadline.isoformat() if t.deadline else None}
            for t in upcoming
        ],
    }
