import enum
import datetime as dt
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, Date, Text,
    ForeignKey, Enum
)
from sqlalchemy.orm import relationship
from app.database import Base


def now():
    return dt.datetime.utcnow()


# ---------------------------------------------------------------- enums ----

class Priority(str, enum.Enum):
    LOW = "Low"
    MEDIUM = "Medium"
    HIGH = "High"
    CRITICAL = "Critical"


class Difficulty(str, enum.Enum):
    EASY = "Easy"
    MEDIUM = "Medium"
    HARD = "Hard"


class TaskStatus(str, enum.Enum):
    NOT_STARTED = "Not Started"
    IN_PROGRESS = "In Progress"
    COMPLETED = "Completed"
    DEFERRED = "Deferred"


class TaskCategory(str, enum.Enum):
    ASSIGNMENT = "Assignment"
    STUDY = "Study"
    PROJECT = "Project"
    EXAM_PREP = "Exam Preparation"
    LAB = "Lab"
    PERSONAL = "Personal Academic Task"


# --------------------------------------------------------------- models ----

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=False)
    college = Column(String, default="")
    department = Column(String, default="")
    year = Column(Integer, default=1)
    semester = Column(Integer, default=1)
    onboarded = Column(Boolean, default=False)
    created_at = Column(DateTime, default=now)

    preferences = relationship("StudentPreference", back_populates="user", uselist=False,
                                cascade="all, delete-orphan")
    subjects = relationship("Subject", back_populates="owner", cascade="all, delete-orphan")
    tasks = relationship("Task", back_populates="owner", cascade="all, delete-orphan")


class StudentPreference(Base):
    __tablename__ = "student_preferences"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True)

    preferred_start_hour = Column(Integer, default=18)   # 24h clock
    preferred_end_hour = Column(Integer, default=22)
    max_daily_study_minutes = Column(Integer, default=180)
    preferred_session_minutes = Column(Integer, default=50)
    break_minutes = Column(Integer, default=10)

    user = relationship("User", back_populates="preferences")


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String, nullable=False)
    code = Column(String, default="")
    color = Column(String, default="#6C63FF")
    icon = Column(String, default="book")
    difficulty = Column(Enum(Difficulty), default=Difficulty.MEDIUM)

    owner = relationship("User", back_populates="subjects")
    tasks = relationship("Task", back_populates="subject", cascade="all, delete-orphan")
    attendance = relationship("Attendance", back_populates="subject", uselist=False,
                               cascade="all, delete-orphan")
    exams = relationship("Exam", back_populates="subject", cascade="all, delete-orphan")


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True)

    title = Column(String, nullable=False)
    description = Column(Text, default="")
    category = Column(Enum(TaskCategory), default=TaskCategory.ASSIGNMENT)
    deadline = Column(DateTime, nullable=True)
    priority = Column(Enum(Priority), default=Priority.MEDIUM)
    difficulty = Column(Enum(Difficulty), default=Difficulty.MEDIUM)

    estimated_minutes = Column(Integer, default=60)     # what the student typed
    predicted_minutes = Column(Integer, nullable=True)   # what the learning engine predicts
    actual_minutes = Column(Integer, nullable=True)       # recorded once completed
    remaining_minutes = Column(Integer, nullable=True)    # tracked as sessions complete

    status = Column(Enum(TaskStatus), default=TaskStatus.NOT_STARTED)
    notes = Column(Text, default="")

    created_at = Column(DateTime, default=now)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)

    owner = relationship("User", back_populates="tasks")
    subject = relationship("Subject", back_populates="tasks")
    sessions = relationship("StudySession", back_populates="task", cascade="all, delete-orphan")


class TaskHistory(Base):
    """Immutable log of estimate-vs-actual, used by the learning engine."""
    __tablename__ = "task_history"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    task_id = Column(Integer, ForeignKey("tasks.id"))
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True)
    category = Column(Enum(TaskCategory))
    difficulty = Column(Enum(Difficulty))
    estimated_minutes = Column(Integer)
    actual_minutes = Column(Integer)
    completed_at = Column(DateTime, default=now)


class StudySession(Base):
    __tablename__ = "study_sessions"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    task_id = Column(Integer, ForeignKey("tasks.id"))

    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    is_break = Column(Boolean, default=False)
    status = Column(String, default="Planned")  # Planned, Completed, Missed, Moved
    origin_event_id = Column(Integer, ForeignKey("rescheduling_events.id"), nullable=True)

    task = relationship("Task", back_populates="sessions")


class Availability(Base):
    """Historically observed / manually declared productive capacity per weekday."""
    __tablename__ = "availability"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    weekday = Column(Integer)  # 0=Monday .. 6=Sunday
    planned_minutes = Column(Integer, default=0)
    actual_minutes = Column(Integer, default=0)
    sample_count = Column(Integer, default=0)


class ScheduleEvent(Base):
    """A blocked-out unavailability window, e.g. 'family event tomorrow'."""
    __tablename__ = "schedule_events"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    start_time = Column(DateTime)
    end_time = Column(DateTime)
    reason = Column(String, default="")


class Exam(Base):
    __tablename__ = "exams"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    subject_id = Column(Integer, ForeignKey("subjects.id"))
    exam_date = Column(DateTime)
    topics = Column(Text, default="")
    difficulty = Column(Enum(Difficulty), default=Difficulty.MEDIUM)
    preparation_status = Column(String, default="Not Started")

    subject = relationship("Subject", back_populates="exams")


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    subject_id = Column(Integer, ForeignKey("subjects.id"), unique=True)
    present = Column(Integer, default=0)
    total = Column(Integer, default=0)
    minimum_required_percent = Column(Float, default=75.0)

    subject = relationship("Subject", back_populates="attendance")


class ReschedulingEvent(Base):
    """Log of every 'something came up' / manual reschedule, old vs new plan."""
    __tablename__ = "rescheduling_events"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    reason_category = Column(String)
    reason_text = Column(String, default="")
    minutes_lost = Column(Integer, default=0)
    affected_date = Column(Date)
    old_schedule_json = Column(Text)
    new_schedule_json = Column(Text)
    accepted = Column(Boolean, nullable=True)  # None = pending decision
    created_at = Column(DateTime, default=now)


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    body = Column(String)
    kind = Column(String, default="info")  # info, warning, deadline, attendance
    read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=now)
