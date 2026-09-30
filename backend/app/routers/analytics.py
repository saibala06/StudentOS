import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, schemas, security
from app.services import learning

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


@router.get("", response_model=schemas.AnalyticsOut)
def analytics(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    completed = db.query(models.Task).filter(
        models.Task.user_id == current_user.id, models.Task.status == models.TaskStatus.COMPLETED,
    ).all()

    error_pct = learning.estimation_error_percent(db, current_user.id)
    subject_avgs = learning.subject_wise_average_minutes(db, current_user.id)

    week_start = dt.datetime.combine(dt.date.today() - dt.timedelta(days=dt.date.today().weekday()), dt.time.min)
    week_end = week_start + dt.timedelta(days=7)
    planned_sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == current_user.id, models.StudySession.is_break.is_(False),
        models.StudySession.start_time >= week_start, models.StudySession.start_time < week_end,
    ).all()
    weekly_planned = sum(int((s.end_time - s.start_time).total_seconds() // 60) for s in planned_sessions)

    weekly_completed_tasks = [t for t in completed if t.completed_at and week_start <= t.completed_at < week_end]
    weekly_completed = sum(t.actual_minutes or 0 for t in weekly_completed_tasks)

    total_tasks = db.query(models.Task).filter(models.Task.user_id == current_user.id).count()
    completion_rate = round((len(completed) / total_tasks * 100), 1) if total_tasks else 0.0

    completed_sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == current_user.id, models.StudySession.status == "Completed",
    ).count()
    total_sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == current_user.id, models.StudySession.is_break.is_(False),
    ).count()
    adherence = round((completed_sessions / total_sessions * 100), 1) if total_sessions else 0.0

    avg_daily = 0.0
    if completed:
        days = {t.completed_at.date() for t in completed if t.completed_at}
        if days:
            avg_daily = round(sum(t.actual_minutes or 0 for t in completed) / len(days), 1)

    if error_pct > 0:
        headline = f"You usually underestimate tasks by {abs(error_pct):.0f}%."
    elif error_pct < 0:
        headline = f"You usually overestimate tasks by {abs(error_pct):.0f}% — nice buffer!"
    else:
        headline = "Not enough completed tasks yet to spot an estimation pattern."

    return schemas.AnalyticsOut(
        tasks_completed=len(completed),
        average_estimation_error_percent=error_pct,
        average_daily_study_minutes=avg_daily,
        weekly_planned_minutes=weekly_planned,
        weekly_completed_minutes=weekly_completed,
        completion_rate_percent=completion_rate,
        subject_wise_avg_minutes=subject_avgs,
        schedule_adherence_percent=adherence,
        headline=headline,
    )
