import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app import models, security

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


def _generate_fresh(db: Session, user: models.User):
    """Deterministically (re)compute the current set of notification-worthy events.
    Real push delivery is a platform concern (see README); this endpoint is the
    data source a local-notifications layer in the Flutter app would poll."""
    now = dt.datetime.utcnow()

    # deadline approaching (within 24h)
    soon = db.query(models.Task).filter(
        models.Task.user_id == user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
        models.Task.deadline.isnot(None),
        models.Task.deadline <= now + dt.timedelta(hours=24),
        models.Task.deadline >= now,
    ).all()
    for t in soon:
        exists = db.query(models.Notification).filter(
            models.Notification.user_id == user.id, models.Notification.kind == "deadline",
            models.Notification.title == t.title,
        ).first()
        if not exists:
            db.add(models.Notification(user_id=user.id, kind="deadline", title=f"{t.title} due soon",
                                        body=f"Deadline: {t.deadline.strftime('%a %d %b, %H:%M')}"))

    # low attendance
    low_attendance = db.query(models.Attendance).filter(models.Attendance.user_id == user.id).all()
    for a in low_attendance:
        if a.total and (a.present / a.total * 100) < a.minimum_required_percent:
            title = f"{a.subject.name if a.subject else 'A subject'} attendance below {a.minimum_required_percent:.0f}%"
            exists = db.query(models.Notification).filter(
                models.Notification.user_id == user.id, models.Notification.kind == "attendance",
                models.Notification.title == title,
            ).first()
            if not exists:
                db.add(models.Notification(user_id=user.id, kind="attendance", title=title,
                                            body="Prioritize attending upcoming classes to recover your percentage."))

    # next session starting soon
    next_session = db.query(models.StudySession).filter(
        models.StudySession.user_id == user.id, models.StudySession.status == "Planned",
        models.StudySession.is_break.is_(False),
        models.StudySession.start_time >= now, models.StudySession.start_time <= now + dt.timedelta(minutes=15),
    ).first()
    if next_session and next_session.task:
        title = f"{next_session.task.title} starts soon"
        exists = db.query(models.Notification).filter(
            models.Notification.user_id == user.id, models.Notification.kind == "info",
            models.Notification.title == title,
        ).first()
        if not exists:
            db.add(models.Notification(user_id=user.id, kind="info", title=title,
                                        body=f"Starts at {next_session.start_time.strftime('%H:%M')}"))
    db.commit()


@router.get("")
def list_notifications(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    _generate_fresh(db, current_user)
    rows = db.query(models.Notification).filter(models.Notification.user_id == current_user.id) \
             .order_by(models.Notification.created_at.desc()).limit(20).all()
    return [{"id": n.id, "title": n.title, "body": n.body, "kind": n.kind, "read": n.read,
             "created_at": n.created_at.isoformat()} for n in rows]


@router.post("/{notification_id}/read")
def mark_read(notification_id: int, db: Session = Depends(get_db),
               current_user: models.User = Depends(security.get_current_user)):
    n = db.query(models.Notification).filter(models.Notification.id == notification_id,
                                               models.Notification.user_id == current_user.id).first()
    if n:
        n.read = True
        db.commit()
    return {"ok": True}
