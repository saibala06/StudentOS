from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_db
from app.routers import (
    auth, users, subjects, tasks, schedule, reschedule,
    attendance, exams, analytics, assistant, dashboard, notifications,
)

app = FastAPI(
    title="StudentOS API",
    description="Adaptive Academic Planning System — deterministic scheduling & personalization engine.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # dev only — tighten for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    init_db()


@app.get("/")
def root():
    return {"status": "ok", "service": "StudentOS API", "docs": "/docs"}


@app.get("/api/health")
def health():
    return {"status": "healthy"}


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(subjects.router)
app.include_router(tasks.router)
app.include_router(schedule.router)
app.include_router(reschedule.router)
app.include_router(attendance.router)
app.include_router(exams.router)
app.include_router(analytics.router)
app.include_router(assistant.router)
app.include_router(dashboard.router)
app.include_router(notifications.router)
