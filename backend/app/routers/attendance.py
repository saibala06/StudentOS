from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/attendance", tags=["attendance"])


def _to_out(a: models.Attendance) -> schemas.AttendanceOut:
    pct = (a.present / a.total * 100) if a.total else 0.0
    min_req = a.minimum_required_percent

    # classes that can still be missed while staying >= minimum required %
    can_miss = 0
    if a.total and pct >= min_req:
        present, total = a.present, a.total
        while total > 0 and (present / (total + 1)) * 100 >= min_req:
            total += 1
            can_miss += 1

    # classes needed to attend consecutively to recover to minimum required %
    need_recover = 0
    if a.total and pct < min_req:
        present, total = a.present, a.total
        while total > 0 and (present / total) * 100 < min_req:
            present += 1
            total += 1
            need_recover += 1

    return schemas.AttendanceOut(
        subject_id=a.subject_id, present=a.present, total=a.total,
        minimum_required_percent=min_req, percentage=round(pct, 1),
        classes_can_miss=can_miss, classes_needed_to_recover=need_recover,
    )


@router.get("", response_model=List[schemas.AttendanceOut])
def list_attendance(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    rows = db.query(models.Attendance).filter(models.Attendance.user_id == current_user.id).all()
    return [_to_out(a) for a in rows]


@router.put("", response_model=schemas.AttendanceOut)
def upsert_attendance(payload: schemas.AttendanceUpsert, db: Session = Depends(get_db),
                       current_user: models.User = Depends(security.get_current_user)):
    row = db.query(models.Attendance).filter(
        models.Attendance.user_id == current_user.id, models.Attendance.subject_id == payload.subject_id,
    ).first()
    if not row:
        row = models.Attendance(user_id=current_user.id, subject_id=payload.subject_id)
        db.add(row)
    row.present = payload.present
    row.total = payload.total
    row.minimum_required_percent = payload.minimum_required_percent or 75.0
    db.commit()
    db.refresh(row)
    return _to_out(row)
