from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=schemas.Token)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        name=payload.name, email=payload.email,
        hashed_password=security.hash_password(payload.password),
        college=payload.college or "", department=payload.department or "",
        year=payload.year or 1, semester=payload.semester or 1,
    )
    db.add(user)
    db.flush()
    db.add(models.StudentPreference(user_id=user.id))
    db.commit()
    db.refresh(user)

    token = security.create_access_token({"sub": str(user.id)})
    return {"access_token": token, "user": user}


@router.post("/login", response_model=schemas.Token)
def login(payload: schemas.UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user or not security.verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    token = security.create_access_token({"sub": str(user.id)})
    return {"access_token": token, "user": user}


@router.get("/me", response_model=schemas.UserOut)
def me(current_user: models.User = Depends(security.get_current_user)):
    return current_user
