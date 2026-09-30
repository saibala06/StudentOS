from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/exams", tags=["exams"])


@router.get("", response_model=List[schemas.ExamOut])
def list_exams(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    return db.query(models.Exam).filter(models.Exam.user_id == current_user.id).order_by(models.Exam.exam_date).all()


@router.post("", response_model=schemas.ExamOut)
def create_exam(payload: schemas.ExamCreate, db: Session = Depends(get_db),
                 current_user: models.User = Depends(security.get_current_user)):
    exam = models.Exam(user_id=current_user.id, **payload.model_dump())
    db.add(exam)
    db.commit()
    db.refresh(exam)

    # Auto-create/boost an exam-prep task so the scheduler picks it up with urgency.
    days_left = max(1, (exam.exam_date.date() - __import__("datetime").date.today()).days)
    priority = models.Priority.CRITICAL if days_left <= 3 else (
        models.Priority.HIGH if days_left <= 7 else models.Priority.MEDIUM)
    prep_task = models.Task(
        user_id=current_user.id, subject_id=exam.subject_id,
        title=f"Exam prep: {exam.subject.name if exam.subject else 'Exam'}",
        description=f"Auto-generated from exam on {exam.exam_date.date()}. Topics: {exam.topics}",
        category=models.TaskCategory.EXAM_PREP, deadline=exam.exam_date,
        priority=priority, difficulty=exam.difficulty,
        estimated_minutes=180, predicted_minutes=180, remaining_minutes=180,
    )
    db.add(prep_task)
    db.commit()
    return exam


@router.delete("/{exam_id}")
def delete_exam(exam_id: int, db: Session = Depends(get_db),
                 current_user: models.User = Depends(security.get_current_user)):
    exam = db.query(models.Exam).filter(models.Exam.id == exam_id, models.Exam.user_id == current_user.id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
    db.delete(exam)
    db.commit()
    return {"ok": True}
