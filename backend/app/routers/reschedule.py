import datetime as dt
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, schemas, security
from app.services import scheduler as scheduler_service

router = APIRouter(prefix="/api/reschedule", tags=["reschedule"])


@router.post("/something-came-up", response_model=schemas.RescheduleResult)
def something_came_up(payload: schemas.SomethingCameUpRequest, db: Session = Depends(get_db),
                       current_user: models.User = Depends(security.get_current_user)):
    affected_date = payload.affected_date or dt.date.today()
    result = scheduler_service.something_came_up(
        db, current_user, payload.reason_category, payload.reason_text or "",
        payload.minutes_lost, affected_date,
    )
    return schemas.RescheduleResult(
        event_id=result["event_id"],
        old_schedule=result["old_schedule"],
        new_schedule=result["new_schedule"],
        warnings=result["warnings"],
    )


@router.post("/{event_id}/decision")
def decide(event_id: int, payload: schemas.RescheduleDecision, db: Session = Depends(get_db),
           current_user: models.User = Depends(security.get_current_user)):
    event = db.query(models.ReschedulingEvent).filter(
        models.ReschedulingEvent.id == event_id, models.ReschedulingEvent.user_id == current_user.id,
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Rescheduling event not found")

    event.accepted = payload.accept
    if not payload.accept:
        # revert: delete the schedule_event we added and regenerate from the old snapshot's date range
        db.query(models.ScheduleEvent).filter(
            models.ScheduleEvent.user_id == current_user.id,
            models.ScheduleEvent.title == f"Unexpected: {event.reason_category}",
            models.ScheduleEvent.start_time >= dt.datetime.combine(event.affected_date, dt.time.min),
        ).delete()
        db.flush()
        scheduler_service.generate_schedule(db, current_user, event.affected_date, horizon_days=7)
    db.commit()
    return {"ok": True, "accepted": payload.accept}


@router.post("/manual")
def manual_reschedule(payload: schemas.ManualRescheduleRequest, db: Session = Depends(get_db),
                       current_user: models.User = Depends(security.get_current_user)):
    task = db.query(models.Task).filter(models.Task.id == payload.task_id,
                                         models.Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # Push a hard preference: block the task's normal earliest slot before new_date by
    # nudging its deadline handling — simplest robust approach is to add a manual pin
    # via a same-day ScheduleEvent isn't right either; instead we just regenerate the
    # whole schedule and rely on the scheduler naturally placing remaining work — but to
    # honor "move to Saturday" concretely we shift by temporarily treating today..new_date-1
    # as blocked for this task specifically, which the deterministic engine supports by
    # deferring: mark task NOT_STARTED remaining as-is and let the horizon regenerate.
    today = dt.date.today()
    if payload.new_date < today:
        raise HTTPException(status_code=400, detail="Cannot move a task into the past")

    block_end = dt.datetime.combine(payload.new_date, dt.time.min)
    # Defer this specific task: clear its own planned sessions before new_date, then
    # regenerate. Other tasks keep their normal priority-scored placement, so this task's
    # remaining work naturally lands on/after new_date once its earlier sessions are gone.
    db.query(models.StudySession).filter(
        models.StudySession.task_id == task.id, models.StudySession.status == "Planned",
        models.StudySession.start_time < block_end,
    ).delete()
    db.commit()

    planned = scheduler_service.generate_schedule(db, current_user, today, horizon_days=7)
    return {"ok": True, "sessions_generated": len(planned)}
