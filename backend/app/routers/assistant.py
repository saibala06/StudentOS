from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, schemas, security
from app.services import assistant as assistant_service

router = APIRouter(prefix="/api/assistant", tags=["assistant"])


@router.post("/ask", response_model=schemas.AssistantReply)
def ask(payload: schemas.AssistantQuery, db: Session = Depends(get_db),
        current_user: models.User = Depends(security.get_current_user)):
    result = assistant_service.answer(db, current_user, payload.message)
    return result
