import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app import models, schemas, security
from app.services import scheduler as scheduler_service

router = APIRouter(prefix="/api/schedule", tags=["schedule"])


@router.post("/generate", response_model=List[schemas.ScheduleSlot])
def generate(days: int = 7, db: Session = Depends(get_db),
             current_user: models.User = Depends(security.get_current_user)):
    planned = scheduler_service.generate_schedule(db, current_user, dt.date.today(), horizon_days=days)
    return [
        schemas.ScheduleSlot(task_id=p.task_id, title=p.title, start_time=p.start, end_time=p.end, is_break=p.is_break)
        for p in planned
    ]


@router.get("", response_model=List[schemas.SessionOut])
def get_schedule(start_date: Optional[dt.date] = None, days: int = 7, db: Session = Depends(get_db),
                  current_user: models.User = Depends(security.get_current_user)):
    start = start_date or dt.date.today()
    end = start + dt.timedelta(days=days)
    sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == current_user.id,
        models.StudySession.status == "Planned",
        models.StudySession.start_time >= dt.datetime.combine(start, dt.time.min),
        models.StudySession.start_time < dt.datetime.combine(end, dt.time.min),
    ).order_by(models.StudySession.start_time).all()
    return sessions


@router.get("/warnings", response_model=List[str])
def get_warnings(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    return scheduler_service.unresolved_risk_warnings(db, current_user)
