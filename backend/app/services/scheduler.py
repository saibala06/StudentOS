"""
StudentOS scheduling engine.

Fully deterministic — no LLM involved anywhere in this file. Given a set of
tasks, the student's learned/declared capacity, and any blocked-out time,
this builds a realistic session-by-session schedule and can recalculate it
when something changes ("I lost 2 hours today").

Weighted priority model
------------------------
Each not-yet-finished task gets a scheduling score combining:

  urgency   = how close the deadline is relative to remaining work
  priority  = the student's stated priority (Low..Critical)
  difficulty= harder tasks get a slight boost so they aren't left too late
  risk      = if remaining work can't fit before the deadline given
              known capacity, that's flagged as at-risk and boosted hard

score = 0.45*urgency + 0.25*priority + 0.10*difficulty + 0.20*risk

Higher score = scheduled sooner. The engine then greedily fills available
capacity, earliest-available slot first, splitting each task's remaining
work into sessions no longer than the student's preferred session length,
separated by their preferred break length.
"""
import datetime as dt
from dataclasses import dataclass, field
from typing import List, Optional
from sqlalchemy.orm import Session

from app import models
from app.services import learning

PRIORITY_WEIGHT = {
    models.Priority.LOW: 0.25,
    models.Priority.MEDIUM: 0.5,
    models.Priority.HIGH: 0.75,
    models.Priority.CRITICAL: 1.0,
}
DIFFICULTY_WEIGHT = {
    models.Difficulty.EASY: 0.3,
    models.Difficulty.MEDIUM: 0.6,
    models.Difficulty.HARD: 1.0,
}


@dataclass
class PlannedSlot:
    task_id: Optional[int]
    title: str
    start: dt.datetime
    end: dt.datetime
    is_break: bool = False


@dataclass
class DayWindow:
    date: dt.date
    start_hour: int
    end_hour: int
    capacity_minutes: int
    blocked: List[tuple] = field(default_factory=list)  # list of (start, end) datetimes

    def free_minutes(self) -> int:
        window_minutes = (self.end_hour - self.start_hour) * 60
        blocked_minutes = sum(int((b_end - b_start).total_seconds() // 60) for b_start, b_end in self.blocked)
        return max(0, min(window_minutes, self.capacity_minutes) - blocked_minutes)


def _remaining_minutes(task: models.Task) -> int:
    if task.remaining_minutes is not None:
        return task.remaining_minutes
    return task.predicted_minutes or task.estimated_minutes or 60


def score_task(task: models.Task, now: dt.datetime, capacity_lookup) -> float:
    remaining = _remaining_minutes(task)
    if task.deadline:
        hours_left = max(0.5, (task.deadline - now).total_seconds() / 3600)
        # urgency: more remaining work relative to time left => more urgent
        urgency = min(1.0, (remaining / 60) / hours_left)
    else:
        hours_left = 24 * 14
        urgency = 0.2

    priority_w = PRIORITY_WEIGHT.get(task.priority, 0.5)
    difficulty_w = DIFFICULTY_WEIGHT.get(task.difficulty, 0.5)

    # risk: can projected capacity between now and deadline cover remaining work?
    risk = 0.0
    if task.deadline:
        days_left = max(1, (task.deadline.date() - now.date()).days)
        projected_capacity = 0
        d = now.date()
        for _ in range(days_left):
            projected_capacity += capacity_lookup(d.weekday())
            d += dt.timedelta(days=1)
        if projected_capacity > 0 and remaining > projected_capacity:
            risk = 1.0
        elif projected_capacity > 0:
            risk = max(0.0, 1 - projected_capacity / max(remaining, 1))

    return 0.45 * urgency + 0.25 * priority_w + 0.10 * difficulty_w + 0.20 * risk


def _build_day_window(db: Session, user_id: int, date: dt.date, prefs: models.StudentPreference,
                       capacity_minutes: int) -> DayWindow:
    day = DayWindow(date=date, start_hour=prefs.preferred_start_hour,
                     end_hour=prefs.preferred_end_hour, capacity_minutes=capacity_minutes)

    day_start = dt.datetime.combine(date, dt.time(hour=prefs.preferred_start_hour))
    day_end = dt.datetime.combine(date, dt.time(hour=prefs.preferred_end_hour))

    # blocked windows: schedule_events (declared unavailability) that overlap this window
    events = db.query(models.ScheduleEvent).filter(
        models.ScheduleEvent.user_id == user_id,
        models.ScheduleEvent.start_time < day_end,
        models.ScheduleEvent.end_time > day_start,
    ).all()
    for e in events:
        day.blocked.append((max(e.start_time, day_start), min(e.end_time, day_end)))

    # existing planned sessions already occupy time too
    sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == user_id,
        models.StudySession.status == "Planned",
        models.StudySession.start_time < day_end,
        models.StudySession.end_time > day_start,
    ).all()
    for s in sessions:
        day.blocked.append((s.start_time, s.end_time))

    return day


def _next_free_slot(day: DayWindow, needed_minutes: int, cursor: dt.datetime) -> Optional[tuple]:
    """Find the next free window of at least `needed_minutes` on this day, at/after `cursor`."""
    day_start = dt.datetime.combine(day.date, dt.time(hour=day.start_hour))
    day_end = dt.datetime.combine(day.date, dt.time(hour=day.end_hour))
    cursor = max(cursor, day_start)

    blocked_sorted = sorted(day.blocked, key=lambda b: b[0])
    for b_start, b_end in blocked_sorted:
        if cursor + dt.timedelta(minutes=needed_minutes) <= b_start:
            return (cursor, cursor + dt.timedelta(minutes=needed_minutes))
        if b_end > cursor:
            cursor = max(cursor, b_end)
    if cursor + dt.timedelta(minutes=needed_minutes) <= day_end:
        return (cursor, cursor + dt.timedelta(minutes=needed_minutes))
    return None


def generate_schedule(db: Session, user: models.User, start_date: dt.date,
                       horizon_days: int = 7, persist: bool = True) -> List[PlannedSlot]:
    """
    Builds (and optionally persists as StudySession rows) a schedule for
    `horizon_days` starting at `start_date`, covering all not-completed tasks.
    """
    prefs = user.preferences
    now = dt.datetime.utcnow()

    tasks = db.query(models.Task).filter(
        models.Task.user_id == user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
    ).all()

    def capacity_lookup(weekday: int) -> int:
        return learning.daily_capacity_minutes(db, user.id, weekday, prefs.max_daily_study_minutes)["capacity_minutes"]

    tasks.sort(key=lambda t: score_task(t, now, capacity_lookup), reverse=True)

    remaining_work = {t.id: _remaining_minutes(t) for t in tasks}

    days = []
    for i in range(horizon_days):
        date = start_date + dt.timedelta(days=i)
        cap = capacity_lookup(date.weekday())
        days.append(_build_day_window(db, user.id, date, prefs, cap))

    if persist:
        # clear existing future planned sessions so we can regenerate cleanly
        db.query(models.StudySession).filter(
            models.StudySession.user_id == user.id,
            models.StudySession.status == "Planned",
            models.StudySession.start_time >= dt.datetime.combine(start_date, dt.time.min),
        ).delete()
        db.flush()
        for day in days:
            day.blocked = [b for b in day.blocked]  # keep manual blocks (schedule_events) only after clearing sessions
        # rebuild blocked windows without the just-deleted planned sessions (schedule_events only)
        for idx, date in enumerate([start_date + dt.timedelta(days=i) for i in range(horizon_days)]):
            cap = capacity_lookup(date.weekday())
            days[idx] = _build_day_window(db, user.id, date, prefs, cap)

    planned: List[PlannedSlot] = []
    cursors = {day.date: dt.datetime.combine(day.date, dt.time(hour=day.start_hour)) for day in days}
    day_used_minutes = {day.date: 0 for day in days}

    for task in tasks:
        remaining = remaining_work[task.id]
        session_len = prefs.preferred_session_minutes
        break_len = prefs.break_minutes

        for day in days:
            if remaining <= 0:
                break
            if task.deadline and day.date > task.deadline.date():
                continue
            while remaining > 0:
                if day_used_minutes[day.date] >= day.capacity_minutes:
                    break  # this day's realistic capacity is used up
                chunk = min(session_len, remaining, day.capacity_minutes - day_used_minutes[day.date])
                slot = _next_free_slot(day, chunk, cursors[day.date])
                if not slot:
                    break
                s_start, s_end = slot
                planned.append(PlannedSlot(task_id=task.id, title=task.title, start=s_start, end=s_end))
                day.blocked.append((s_start, s_end))
                remaining -= chunk
                day_used_minutes[day.date] += chunk

                if remaining > 0:
                    break_slot_start = s_end
                    break_slot_end = s_end + dt.timedelta(minutes=break_len)
                    planned.append(PlannedSlot(task_id=None, title="Break", start=break_slot_start,
                                                end=break_slot_end, is_break=True))
                    day.blocked.append((break_slot_start, break_slot_end))
                    cursors[day.date] = break_slot_end
                else:
                    cursors[day.date] = s_end
        remaining_work[task.id] = remaining

    if persist:
        for slot in planned:
            db.add(models.StudySession(
                user_id=user.id, task_id=slot.task_id,
                start_time=slot.start, end_time=slot.end, is_break=slot.is_break, status="Planned",
            ))
        db.commit()

    return planned


def unresolved_risk_warnings(db: Session, user: models.User) -> List[str]:
    """After generation, check which tasks still won't fit before their deadline."""
    warnings = []
    tasks = db.query(models.Task).filter(
        models.Task.user_id == user.id,
        models.Task.status.in_([models.TaskStatus.NOT_STARTED, models.TaskStatus.IN_PROGRESS]),
        models.Task.deadline.isnot(None),
    ).all()
    for task in tasks:
        needed = _remaining_minutes(task)
        scheduled = db.query(models.StudySession).filter(
            models.StudySession.task_id == task.id,
            models.StudySession.status == "Planned",
            models.StudySession.start_time <= task.deadline,
        ).all()
        scheduled_minutes = sum(int((s.end_time - s.start_time).total_seconds() // 60) for s in scheduled)
        if scheduled_minutes < needed:
            warnings.append(
                f"'{task.title}' may not be finished before its deadline "
                f"({task.deadline.strftime('%a %d %b, %H:%M')}) — only {scheduled_minutes} of "
                f"{needed} needed minutes are currently scheduled."
            )
    return warnings


def something_came_up(db: Session, user: models.User, reason_category: str, reason_text: str,
                       minutes_lost: int, affected_date: dt.date) -> dict:
    """
    Blocks `minutes_lost` of time on affected_date (placed at the start of the
    student's preferred study window, a common real-world pattern — evenings
    lost to unexpected events), snapshots the current plan as "old", then
    regenerates the schedule from affected_date forward as "new".
    """
    prefs = user.preferences

    # snapshot OLD schedule (today .. +7d)
    old_sessions = db.query(models.StudySession).filter(
        models.StudySession.user_id == user.id,
        models.StudySession.status == "Planned",
        models.StudySession.start_time >= dt.datetime.combine(affected_date, dt.time.min),
    ).order_by(models.StudySession.start_time).all()
    old_schedule = [
        {"task_id": s.task_id, "title": (s.task.title if s.task_id and s.task else "Break"),
         "start_time": s.start_time.isoformat(), "end_time": s.end_time.isoformat(), "is_break": s.is_break}
        for s in old_sessions
    ]

    block_start = dt.datetime.combine(affected_date, dt.time(hour=prefs.preferred_start_hour))
    block_end = block_start + dt.timedelta(minutes=minutes_lost)
    event = models.ScheduleEvent(
        user_id=user.id, title=f"Unexpected: {reason_category}",
        start_time=block_start, end_time=block_end, reason=reason_text or reason_category,
    )
    db.add(event)
    db.flush()

    new_planned = generate_schedule(db, user, affected_date, horizon_days=7, persist=True)
    new_schedule = [
        {"task_id": s.task_id, "title": s.title, "start_time": s.start.isoformat(),
         "end_time": s.end.isoformat(), "is_break": s.is_break}
        for s in new_planned
    ]
    warnings = unresolved_risk_warnings(db, user)

    reschedule_event = models.ReschedulingEvent(
        user_id=user.id, reason_category=reason_category, reason_text=reason_text,
        minutes_lost=minutes_lost, affected_date=affected_date,
        old_schedule_json=_to_json(old_schedule), new_schedule_json=_to_json(new_schedule),
        accepted=None,
    )
    db.add(reschedule_event)
    db.commit()
    db.refresh(reschedule_event)

    return {
        "event_id": reschedule_event.id,
        "old_schedule": old_schedule,
        "new_schedule": new_schedule,
        "warnings": warnings,
    }


def _to_json(obj) -> str:
    import json
    return json.dumps(obj, default=str)
