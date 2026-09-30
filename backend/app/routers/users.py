from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/preferences", response_model=schemas.PreferenceOut)
def get_preferences(current_user: models.User = Depends(security.get_current_user)):
    return current_user.preferences


@router.put("/preferences", response_model=schemas.PreferenceOut)
def update_preferences(payload: schemas.PreferenceUpdate, db: Session = Depends(get_db),
                        current_user: models.User = Depends(security.get_current_user)):
    prefs = current_user.preferences
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(prefs, field, value)
    db.commit()
    db.refresh(prefs)
    return prefs


@router.put("/profile", response_model=schemas.UserOut)
def update_profile(payload: dict, db: Session = Depends(get_db),
                    current_user: models.User = Depends(security.get_current_user)):
    allowed = {"name", "college", "department", "year", "semester", "onboarded"}
    for key, value in payload.items():
        if key in allowed:
            setattr(current_user, key, value)
    db.commit()
    db.refresh(current_user)
    return current_user
