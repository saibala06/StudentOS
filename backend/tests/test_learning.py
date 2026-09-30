import datetime as dt
from app import models, security
from app.services import learning


def _make_user(db, email="learner@test.com"):
    user = models.User(name="Test", email=email, hashed_password=security.hash_password("pw"))
    db.add(user)
    db.flush()
    db.add(models.StudentPreference(user_id=user.id))
    db.commit()
    db.refresh(user)
    return user


def test_predict_falls_back_to_estimate_with_no_history(db):
    user = _make_user(db)
    result = learning.predict_duration(db, user.id, None, models.TaskCategory.ASSIGNMENT,
                                        models.Difficulty.MEDIUM, 120)
    assert result["predicted_minutes"] == 120
    assert result["confidence"] == "low"


def test_predict_uses_subject_history_when_available(db):
    user = _make_user(db, "learner2@test.com")
    subject = models.Subject(user_id=user.id, name="DBMS")
    db.add(subject)
    db.flush()

    # seed 4 history rows where actual = 1.5x estimated
    for est in [60, 80, 100, 120]:
        db.add(models.TaskHistory(
            user_id=user.id, task_id=0, subject_id=subject.id,
            category=models.TaskCategory.ASSIGNMENT, difficulty=models.Difficulty.MEDIUM,
            estimated_minutes=est, actual_minutes=round(est * 1.5),
        ))
    db.commit()

    result = learning.predict_duration(db, user.id, subject.id, models.TaskCategory.ASSIGNMENT,
                                        models.Difficulty.MEDIUM, 100)
    assert result["predicted_minutes"] == 150
    assert result["confidence"] in ("medium", "high")


def test_estimation_error_percent(db):
    user = _make_user(db, "learner3@test.com")
    db.add(models.TaskHistory(user_id=user.id, task_id=0, category=models.TaskCategory.ASSIGNMENT,
                               difficulty=models.Difficulty.MEDIUM, estimated_minutes=100, actual_minutes=130))
    db.commit()
    err = learning.estimation_error_percent(db, user.id)
    assert err == 30.0


def test_daily_capacity_falls_back_without_history(db):
    user = _make_user(db, "learner4@test.com")
    result = learning.daily_capacity_minutes(db, user.id, weekday=2, fallback_minutes=180)
    assert result["capacity_minutes"] == 180
    assert result["confidence"] == "low"
