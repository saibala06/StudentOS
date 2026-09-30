"""
AI Academic Assistant.

Design principle (per spec): the LLM, if configured, is used ONLY for
natural-language phrasing / parsing — never for the actual scheduling math.
All numbers quoted here come from the deterministic scheduler/learning
services. With no AI_PROVIDER configured this runs entirely locally using
simple intent matching, which is enough to answer the assistant's demo
questions accurately and explainably.
"""
import os
import datetime as dt
from sqlalchemy.orm import Session

from app import models
from app.services import learning, scheduler

AI_PROVIDER = os.getenv("AI_PROVIDER", "local")


def _upcoming_deadline_summary(db: Session, user: models.User) -> str:
    tasks = db.query(models.Task).filter(
        models.Task.user_id == user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
        models.Task.deadline.isnot(None),
    ).order_by(models.Task.deadline).limit(3).all()
    if not tasks:
        return "You have no upcoming deadlines on record."
    parts = [f"{t.title} ({t.deadline.strftime('%a %d %b')})" for t in tasks]
    return "Your nearest deadlines: " + ", ".join(parts) + "."


def _remaining_and_capacity_until(db: Session, user: models.User, until: dt.date) -> tuple:
    tasks = db.query(models.Task).filter(
        models.Task.user_id == user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
    ).all()
    remaining = sum(scheduler._remaining_minutes(t) for t in tasks
                     if not t.deadline or t.deadline.date() <= until)
    prefs = user.preferences
    today = dt.date.today()
    days = max(1, (until - today).days + 1)
    capacity = 0
    d = today
    for _ in range(days):
        capacity += learning.daily_capacity_minutes(db, user.id, d.weekday(),
                                                      prefs.max_daily_study_minutes)["capacity_minutes"]
        d += dt.timedelta(days=1)
    return remaining, capacity


def answer(db: Session, user: models.User, message: str) -> dict:
    text = message.lower().strip()
    today = dt.date.today()

    # "what should I do today?"
    if "today" in text and ("what should" in text or "what do" in text or "what's on" in text or "whats on" in text):
        sessions = db.query(models.StudySession).filter(
            models.StudySession.user_id == user.id,
            models.StudySession.status == "Planned",
            models.StudySession.start_time >= dt.datetime.combine(today, dt.time.min),
            models.StudySession.start_time < dt.datetime.combine(today, dt.time.max),
        ).order_by(models.StudySession.start_time).all()
        if not sessions:
            return {"reply": "You have nothing scheduled today. Want me to generate a plan from your task list?",
                    "data": None}
        lines = []
        for s in sessions:
            label = "Break" if s.is_break else (s.task.title if s.task else "Task")
            lines.append(f"{s.start_time.strftime('%I:%M %p')} – {label}")
        return {"reply": "Here's today's plan:\n" + "\n".join(lines), "data": {"sessions": len(sessions)}}

    # "can I finish everything before <day>?" — simplistic: look for "before"
    if "finish everything" in text or ("before" in text and ("friday" in text or "deadline" in text or "finish" in text)):
        # naive weekday parse
        weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        target = None
        for i, wd in enumerate(weekdays):
            if wd in text:
                days_ahead = (i - today.weekday()) % 7
                days_ahead = days_ahead or 7
                target = today + dt.timedelta(days=days_ahead)
                break
        if not target:
            target = today + dt.timedelta(days=4)
        remaining, capacity = _remaining_and_capacity_until(db, user, target)
        remaining_h = remaining / 60
        capacity_h = capacity / 60
        if capacity >= remaining:
            verdict = "You should be able to finish in time."
        else:
            verdict = "That's going to be tight — you may not finish everything unless you start soon."
        return {
            "reply": (f"You currently have approximately {remaining_h:.1f} hours of remaining work, and your "
                      f"typical available capacity before {target.strftime('%A')} is about {capacity_h:.1f} hours. "
                      f"{verdict}"),
            "data": {"remaining_minutes": remaining, "capacity_minutes": capacity},
        }

    # "why did you schedule/move X"
    if "why" in text and ("schedule" in text or "move" in text or "moved" in text):
        last_event = db.query(models.ReschedulingEvent).filter(
            models.ReschedulingEvent.user_id == user.id
        ).order_by(models.ReschedulingEvent.created_at.desc()).first()
        if last_event:
            return {
                "reply": (f"Your last change was because of '{last_event.reason_category}' "
                          f"({last_event.minutes_lost} minutes lost on {last_event.affected_date}). "
                          "I recalculated your remaining tasks against your deadlines and daily capacity, "
                          "and moved sessions to the next realistic free slots that still respect your "
                          "preferred study hours and session length."),
                "data": {"event_id": last_event.id},
            }
        return {"reply": "Tasks are scheduled using deadline urgency, priority, difficulty, and your learned "
                          "daily capacity — the highest-scoring task gets the earliest available slot. "
                          "Nothing has been rescheduled yet in your account.", "data": None}

    # "which task should I start first"
    if "start first" in text or "which task" in text:
        def capacity_lookup(weekday):
            return learning.daily_capacity_minutes(db, user.id, weekday,
                                                     user.preferences.max_daily_study_minutes)["capacity_minutes"]
        tasks = db.query(models.Task).filter(
            models.Task.user_id == user.id,
            models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
        ).all()
        if not tasks:
            return {"reply": "You have no open tasks right now — nice work!", "data": None}
        now = dt.datetime.utcnow()
        best = max(tasks, key=lambda t: scheduler.score_task(t, now, capacity_lookup))
        return {"reply": f"I'd start with '{best.title}' — it has the highest combined urgency, priority, and "
                          f"deadline risk right now.", "data": {"task_id": best.id}}

    # "unexpected event tomorrow, what should I do"
    if "unexpected" in text or "can't study" in text or "cant study" in text or "lost" in text:
        return {"reply": "Tell me about it using 'Something came up' on the dashboard — pick what happened and "
                          "how much time it affects, and I'll recalculate your whole remaining schedule around "
                          "your deadlines automatically.", "data": None}

    # fallback: general status
    remaining, capacity = _remaining_and_capacity_until(db, user, today + dt.timedelta(days=7))
    deadline_summary = _upcoming_deadline_summary(db, user)
    return {
        "reply": (f"{deadline_summary} Over the next 7 days you have about {remaining/60:.1f} hours of work "
                  f"against roughly {capacity/60:.1f} hours of typical capacity. Ask me things like "
                  "\"what should I do today\" or \"can I finish everything before Friday\"."),
        "data": None,
    }
