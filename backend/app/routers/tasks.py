import datetime as dt
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app import models, schemas, security
from app.services import learning

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


@router.get("", response_model=List[schemas.TaskOut])
def list_tasks(status: Optional[models.TaskStatus] = None, db: Session = Depends(get_db),
               current_user: models.User = Depends(security.get_current_user)):
    q = db.query(models.Task).filter(models.Task.user_id == current_user.id)
    if status:
        q = q.filter(models.Task.status == status)
    return q.order_by(models.Task.deadline.is_(None), models.Task.deadline).all()


@router.get("/{task_id}", response_model=schemas.TaskOut)
def get_task(task_id: int, db: Session = Depends(get_db),
             current_user: models.User = Depends(security.get_current_user)):
    task = db.query(models.Task).filter(models.Task.id == task_id, models.Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.post("/predict", response_model=schemas.PredictionOut)
def predict(payload: schemas.TaskCreate, db: Session = Depends(get_db),
            current_user: models.User = Depends(security.get_current_user)):
    """Preview the personalized duration prediction before creating the task."""
    result = learning.predict_duration(db, current_user.id, payload.subject_id, payload.category,
                                        payload.difficulty, payload.estimated_minutes)
    return result


@router.post("", response_model=schemas.TaskOut)
def create_task(payload: schemas.TaskCreate, db: Session = Depends(get_db),
                 current_user: models.User = Depends(security.get_current_user)):
    prediction = learning.predict_duration(db, current_user.id, payload.subject_id, payload.category,
                                            payload.difficulty, payload.estimated_minutes)
    task = models.Task(
        user_id=current_user.id,
        predicted_minutes=prediction["predicted_minutes"],
        remaining_minutes=prediction["predicted_minutes"],
        **payload.model_dump(),
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.put("/{task_id}", response_model=schemas.TaskOut)
def update_task(task_id: int, payload: schemas.TaskUpdate, db: Session = Depends(get_db),
                 current_user: models.User = Depends(security.get_current_user)):
    task = db.query(models.Task).filter(models.Task.id == task_id, models.Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    db.commit()
    db.refresh(task)
    return task


@router.post("/{task_id}/start", response_model=schemas.TaskOut)
def start_task(task_id: int, db: Session = Depends(get_db),
                current_user: models.User = Depends(security.get_current_user)):
    task = db.query(models.Task).filter(models.Task.id == task_id, models.Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    task.status = models.TaskStatus.IN_PROGRESS
    task.started_at = dt.datetime.utcnow()
    db.commit()
    db.refresh(task)
    return task


@router.post("/{task_id}/complete", response_model=schemas.TaskOut)
def complete_task(task_id: int, payload: schemas.TaskComplete, db: Session = Depends(get_db),
                   current_user: models.User = Depends(security.get_current_user)):
    task = db.query(models.Task).filter(models.Task.id == task_id, models.Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    task.status = models.TaskStatus.COMPLETED
    task.actual_minutes = payload.actual_minutes
    task.remaining_minutes = 0
    task.completed_at = dt.datetime.utcnow()
    db.commit()
    db.refresh(task)
    learning.record_completion(db, task)
    return task


@router.delete("/{task_id}")
def delete_task(task_id: int, db: Session = Depends(get_db),
                 current_user: models.User = Depends(security.get_current_user)):
    task = db.query(models.Task).filter(models.Task.id == task_id, models.Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    db.delete(task)
    db.commit()
    return {"ok": True}
