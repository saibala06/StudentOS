"""
Personal duration learning + daily capacity learning.

This is deterministic statistics over TaskHistory / Availability rows —
no LLM involved. Everything here is explainable: every number the app
shows the student can be traced back to a formula in this file.
"""
import datetime as dt
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import models

MIN_SAMPLES_FOR_CONFIDENCE = {"high": 6, "medium": 3}


def _factor_from_rows(rows) -> Optional[float]:
    """rows: list of (estimated_minutes, actual_minutes). Returns weighted avg actual/estimated."""
    total_est = sum(r[0] for r in rows if r[0])
    total_act = sum(r[1] for r in rows if r[0])
    if not total_est:
        return None
    return total_act / total_est


def predict_duration(db: Session, user_id: int, subject_id: Optional[int],
                      category: models.TaskCategory, difficulty: models.Difficulty,
                      estimated_minutes: int) -> dict:
    """
    Predict how long this student will actually take, based on history.
    Falls back progressively: subject-specific -> category-specific ->
    difficulty-specific -> student's own raw estimate.
    Returns dict with predicted_minutes, basis (explanation), confidence.
    """
    base_q = db.query(models.TaskHistory.estimated_minutes, models.TaskHistory.actual_minutes) \
                .filter(models.TaskHistory.user_id == user_id)

    # 1. Subject-specific
    if subject_id is not None:
        rows = base_q.filter(models.TaskHistory.subject_id == subject_id).all()
        if len(rows) >= MIN_SAMPLES_FOR_CONFIDENCE["medium"]:
            factor = _factor_from_rows(rows)
            if factor:
                confidence = "high" if len(rows) >= MIN_SAMPLES_FOR_CONFIDENCE["high"] else "medium"
                predicted = round(estimated_minutes * factor)
                return {
                    "predicted_minutes": predicted,
                    "basis": f"Based on your last {len(rows)} tasks in this subject, "
                              f"you typically take {factor:.2f}x your estimate.",
                    "confidence": confidence,
                }

    # 2. Category-specific (e.g. all "Assignment" or "Project" tasks)
    rows = base_q.filter(models.TaskHistory.category == category).all()
    if len(rows) >= MIN_SAMPLES_FOR_CONFIDENCE["medium"]:
        factor = _factor_from_rows(rows)
        if factor:
            confidence = "medium"
            predicted = round(estimated_minutes * factor)
            return {
                "predicted_minutes": predicted,
                "basis": f"Based on {len(rows)} of your past '{category.value}' tasks, "
                         f"you typically take {factor:.2f}x your estimate.",
                "confidence": confidence,
            }

    # 3. Difficulty-specific
    rows = base_q.filter(models.TaskHistory.difficulty == difficulty).all()
    if len(rows) >= MIN_SAMPLES_FOR_CONFIDENCE["medium"]:
        factor = _factor_from_rows(rows)
        if factor:
            predicted = round(estimated_minutes * factor)
            return {
                "predicted_minutes": predicted,
                "basis": f"Based on {len(rows)} past tasks of similar ('{difficulty.value}') "
                         f"difficulty, you typically take {factor:.2f}x your estimate.",
                "confidence": "medium",
            }

    # 4. Not enough history yet — use the student's own estimate, be honest about it
    total_history = base_q.count()
    if total_history == 0:
        basis = "Learning from your task history... no completed tasks yet, so using your own estimate."
    else:
        basis = (f"Learning from your task history... only {total_history} completed task(s) so far, "
                 "not enough for a confident prediction yet. Using your own estimate.")
    return {
        "predicted_minutes": estimated_minutes,
        "basis": basis,
        "confidence": "low",
    }


def record_completion(db: Session, task: models.Task):
    """Called when a task is marked completed with an actual_minutes value."""
    history = models.TaskHistory(
        user_id=task.user_id,
        task_id=task.id,
        subject_id=task.subject_id,
        category=task.category,
        difficulty=task.difficulty,
        estimated_minutes=task.estimated_minutes,
        actual_minutes=task.actual_minutes,
    )
    db.add(history)

    # roll the completed work into the weekday capacity model
    weekday = (task.completed_at or dt.datetime.utcnow()).weekday()
    avail = db.query(models.Availability).filter(
        models.Availability.user_id == task.user_id,
        models.Availability.weekday == weekday,
    ).first()
    if not avail:
        avail = models.Availability(user_id=task.user_id, weekday=weekday,
                                     planned_minutes=0, actual_minutes=0, sample_count=0)
        db.add(avail)
    avail.actual_minutes += task.actual_minutes or 0
    avail.planned_minutes += task.estimated_minutes or 0
    avail.sample_count += 1
    db.commit()


def subject_wise_average_minutes(db: Session, user_id: int) -> dict:
    rows = db.query(models.Subject.name, func.avg(models.TaskHistory.actual_minutes)) \
              .join(models.TaskHistory, models.TaskHistory.subject_id == models.Subject.id) \
              .filter(models.TaskHistory.user_id == user_id) \
              .group_by(models.Subject.name).all()
    return {name: round(avg or 0, 1) for name, avg in rows}


def estimation_error_percent(db: Session, user_id: int) -> float:
    rows = db.query(models.TaskHistory.estimated_minutes, models.TaskHistory.actual_minutes) \
              .filter(models.TaskHistory.user_id == user_id).all()
    if not rows:
        return 0.0
    errors = []
    for est, act in rows:
        if est:
            errors.append((act - est) / est * 100)
    return round(sum(errors) / len(errors), 1) if errors else 0.0


def daily_capacity_minutes(db: Session, user_id: int, weekday: int, fallback_minutes: int) -> dict:
    """
    Returns realistic productive capacity for a given weekday (0=Mon).
    Falls back to the student's manually configured max_daily_study_minutes
    if there isn't enough history yet.
    """
    avail = db.query(models.Availability).filter(
        models.Availability.user_id == user_id,
        models.Availability.weekday == weekday,
    ).first()
    if avail and avail.sample_count >= 2:
        avg = avail.actual_minutes / avail.sample_count
        return {
            "capacity_minutes": round(avg),
            "basis": f"Learned from {avail.sample_count} past days you've studied on this weekday.",
            "confidence": "high" if avail.sample_count >= 5 else "medium",
        }
    return {
        "capacity_minutes": fallback_minutes,
        "basis": "Not enough history for this weekday yet — using your configured daily capacity.",
        "confidence": "low",
    }
