from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/subjects", tags=["subjects"])


@router.get("", response_model=List[schemas.SubjectOut])
def list_subjects(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    return db.query(models.Subject).filter(models.Subject.user_id == current_user.id).all()


@router.post("", response_model=schemas.SubjectOut)
def create_subject(payload: schemas.SubjectCreate, db: Session = Depends(get_db),
                    current_user: models.User = Depends(security.get_current_user)):
    subject = models.Subject(user_id=current_user.id, **payload.model_dump())
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return subject


@router.delete("/{subject_id}")
def delete_subject(subject_id: int, db: Session = Depends(get_db),
                    current_user: models.User = Depends(security.get_current_user)):
    subject = db.query(models.Subject).filter(models.Subject.id == subject_id,
                                                models.Subject.user_id == current_user.id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    db.delete(subject)
    db.commit()
    return {"ok": True}
