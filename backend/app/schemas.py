import datetime as dt
from typing import Optional, List
from pydantic import BaseModel, EmailStr, ConfigDict
from app.models import Priority, Difficulty, TaskStatus, TaskCategory


# ---------------------------------------------------------------- auth ----

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    college: Optional[str] = ""
    department: Optional[str] = ""
    year: Optional[int] = 1
    semester: Optional[int] = 1


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    email: EmailStr
    college: str
    department: str
    year: int
    semester: int
    onboarded: bool


# ---------------------------------------------------------- preferences ----

class PreferenceUpdate(BaseModel):
    preferred_start_hour: Optional[int] = None
    preferred_end_hour: Optional[int] = None
    max_daily_study_minutes: Optional[int] = None
    preferred_session_minutes: Optional[int] = None
    break_minutes: Optional[int] = None


class PreferenceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    preferred_start_hour: int
    preferred_end_hour: int
    max_daily_study_minutes: int
    preferred_session_minutes: int
    break_minutes: int


# --------------------------------------------------------------- subject --

class SubjectCreate(BaseModel):
    name: str
    code: Optional[str] = ""
    color: Optional[str] = "#6C63FF"
    icon: Optional[str] = "book"
    difficulty: Optional[Difficulty] = Difficulty.MEDIUM


class SubjectOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    code: str
    color: str
    icon: str
    difficulty: Difficulty


# ------------------------------------------------------------------ task --

class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    subject_id: Optional[int] = None
    category: TaskCategory = TaskCategory.ASSIGNMENT
    deadline: Optional[dt.datetime] = None
    priority: Priority = Priority.MEDIUM
    difficulty: Difficulty = Difficulty.MEDIUM
    estimated_minutes: int = 60
    notes: Optional[str] = ""


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    subject_id: Optional[int] = None
    category: Optional[TaskCategory] = None
    deadline: Optional[dt.datetime] = None
    priority: Optional[Priority] = None
    difficulty: Optional[Difficulty] = None
    estimated_minutes: Optional[int] = None
    status: Optional[TaskStatus] = None
    notes: Optional[str] = None


class TaskComplete(BaseModel):
    actual_minutes: int


class TaskOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    description: str
    subject_id: Optional[int]
    category: TaskCategory
    deadline: Optional[dt.datetime]
    priority: Priority
    difficulty: Difficulty
    estimated_minutes: int
    predicted_minutes: Optional[int]
    actual_minutes: Optional[int]
    remaining_minutes: Optional[int]
    status: TaskStatus
    notes: str
    created_at: dt.datetime
    started_at: Optional[dt.datetime]
    completed_at: Optional[dt.datetime]


class PredictionOut(BaseModel):
    predicted_minutes: int
    basis: str            # explanation of where the number came from
    confidence: str        # "low" | "medium" | "high"


# --------------------------------------------------------------- session --

class SessionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    task_id: Optional[int]
    start_time: dt.datetime
    end_time: dt.datetime
    is_break: bool
    status: str


# -------------------------------------------------------------- exams -----

class ExamCreate(BaseModel):
    subject_id: int
    exam_date: dt.datetime
    topics: Optional[str] = ""
    difficulty: Difficulty = Difficulty.MEDIUM
    preparation_status: Optional[str] = "Not Started"


class ExamOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    subject_id: int
    exam_date: dt.datetime
    topics: str
    difficulty: Difficulty
    preparation_status: str


# --------------------------------------------------------- attendance -----

class AttendanceUpsert(BaseModel):
    subject_id: int
    present: int
    total: int
    minimum_required_percent: Optional[float] = 75.0


class AttendanceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    subject_id: int
    present: int
    total: int
    minimum_required_percent: float
    percentage: float
    classes_can_miss: int
    classes_needed_to_recover: int


# ------------------------------------------------------- rescheduling -----

class SomethingCameUpRequest(BaseModel):
    reason_category: str          # College work, Family event, Travel, ...
    reason_text: Optional[str] = ""
    minutes_lost: int
    affected_date: Optional[dt.date] = None  # defaults to today


class RescheduleDecision(BaseModel):
    accept: bool


class ManualRescheduleRequest(BaseModel):
    task_id: int
    new_date: dt.date


class ScheduleSlot(BaseModel):
    task_id: Optional[int]
    title: str
    start_time: dt.datetime
    end_time: dt.datetime
    is_break: bool = False


class RescheduleResult(BaseModel):
    event_id: int
    old_schedule: List[ScheduleSlot]
    new_schedule: List[ScheduleSlot]
    warnings: List[str]


# ------------------------------------------------------------- assistant --

class AssistantQuery(BaseModel):
    message: str


class AssistantReply(BaseModel):
    reply: str
    data: Optional[dict] = None


# ------------------------------------------------------------- analytics --

class AnalyticsOut(BaseModel):
    tasks_completed: int
    average_estimation_error_percent: float
    average_daily_study_minutes: float
    weekly_planned_minutes: int
    weekly_completed_minutes: int
    completion_rate_percent: float
    subject_wise_avg_minutes: dict
    schedule_adherence_percent: float
    headline: str
