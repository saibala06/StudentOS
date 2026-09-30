# StudentOS — Adaptive Academic Planning System

StudentOS is not a to-do list. It's a scheduler that learns **how long tasks
actually take you** — per subject, per category, per difficulty — and builds
a realistic study plan around your real capacity, deadlines, and priorities.
When life gets in the way, "Something came up" recalculates your entire
remaining schedule in one tap.

## Table of contents

- [Problem statement](#problem-statement)
- [Architecture](#architecture)
- [Tech stack](#tech-stack)
- [Folder structure](#folder-structure)
- [Database design](#database-design)
- [API documentation](#api-documentation)
- [Setup instructions](#setup-instructions)
- [Demo credentials](#demo-credentials)
- [How personalization works](#how-personalization-works)
- [How scheduling works](#how-scheduling-works)
- [How rescheduling works](#how-rescheduling-works)
- [Future AI integration](#future-ai-integration)
- [Environment status / honesty note](#environment-status--honesty-note)
- [Tests](#tests)

---

## Problem statement

A generic planner treats every student the same: if you type "2 hours" for a
task, it blocks 2 hours. In reality, two students doing the identical DBMS
assignment might take 1 hour and 3 hours respectively — and the same student
might be faster at reading tasks than at programming tasks. Generic planners
also don't distinguish *available* time from *realistic productive capacity*,
so they overbook students who are technically free but not actually able to
sustain hours of focused work.

StudentOS solves this by learning, per student, per subject, per task
category, and per difficulty, how their estimates map to their actual
completion times — and by tracking realistic daily capacity separately from
raw availability. When something disrupts the plan, it recalculates instead
of just shifting everything by a day.

## Architecture

```
┌─────────────────────┐        REST/JSON        ┌──────────────────────────┐
│   Flutter (Dart)     │ <---------------------> │   FastAPI (Python)        │
│   Riverpod state      │                        │   SQLAlchemy + SQLite     │
│   mgmt, Material 3    │                        │                            │
└─────────────────────┘                          │  ┌──────────────────────┐ │
                                                   │  │ Deterministic         │ │
                                                   │  │ scheduling engine     │ │
                                                   │  │ (services/scheduler)  │ │
                                                   │  └──────────────────────┘ │
                                                   │  ┌──────────────────────┐ │
                                                   │  │ Personal duration     │ │
                                                   │  │ learning engine        │ │
                                                   │  │ (services/learning)    │ │
                                                   │  └──────────────────────┘ │
                                                   │  ┌──────────────────────┐ │
                                                   │  │ Local rule-based AI   │ │
                                                   │  │ assistant (LLM-       │ │
                                                   │  │ optional)             │ │
                                                   │  │ (services/assistant)  │ │
                                                   │  └──────────────────────┘ │
                                                   └──────────────────────────┘
```

**Key architectural principle (from spec):** the scheduling math is never
delegated to an LLM. `services/scheduler.py` and `services/learning.py` are
pure, deterministic, unit-tested Python — every number the app shows a
student traces back to a formula you can read and audit. An LLM, if
configured via `GEMINI_API_KEY`/`OPENAI_API_KEY`, would only ever be used to
make the AI Assistant's *phrasing* more natural or to parse free-text input
— never to compute a schedule. With no key configured (the default), the
assistant runs entirely on local rule-based intent matching against the same
deterministic data, which is sufficient to answer the demo's example
questions accurately.

See `ARCHITECTURE.md` for more detail on individual design decisions.

## Tech stack

| Layer | Choice |
|---|---|
| Mobile frontend | Flutter (Dart 3), Material 3, Riverpod |
| Backend | Python 3.11+, FastAPI, Pydantic v2 |
| Database | SQLite (dev default), SQLAlchemy ORM |
| Auth | JWT (python-jose) + bcrypt password hashing |
| Charts | fl_chart (Flutter) |
| AI (optional) | Abstracted behind `services/assistant.py`; local rule-based by default, Gemini/OpenAI pluggable later |

No Firebase, no external cloud service, no paid API key is required to run
the full application.

## Folder structure

```
StudentOS/
├── backend/
│   ├── app/
│   │   ├── main.py            FastAPI app + router registration
│   │   ├── database.py        SQLAlchemy engine/session, init_db()
│   │   ├── models.py          ORM models (12 tables)
│   │   ├── schemas.py         Pydantic request/response schemas
│   │   ├── security.py        JWT + bcrypt helpers, get_current_user
│   │   ├── seed.py            Demo account + realistic history seeder
│   │   ├── routers/           One router per resource (auth, tasks, ...)
│   │   └── services/
│   │       ├── scheduler.py   Deterministic scheduling/rescheduling engine
│   │       ├── learning.py    Personal duration + capacity learning
│   │       └── assistant.py   Local rule-based AI assistant
│   ├── tests/                 pytest unit tests for scheduler + learning
│   ├── requirements.txt
│   ├── .env.example
│   └── run.sh                 One-command setup + run
└── frontend/
    └── studentos/
        ├── lib/
        │   ├── main.dart
        │   ├── config/api_config.dart      Base URL resolution (emulator-aware)
        │   ├── models/                     Dart data classes
        │   ├── services/                   API client + one service per resource
        │   ├── providers/                  Riverpod providers + auth controller
        │   ├── theme/                      Material 3 theme
        │   ├── widgets/                    Shared UI + bottom-nav shell
        │   └── screens/                    One folder per module (see below)
        ├── test/widget_test.dart
        ├── pubspec.yaml
        └── .env.example                    Documents --dart-define usage
```

## Database design

12 tables, defined in `backend/app/models.py`:

- **users** — account + profile fields
- **student_preferences** — 1:1 with users; study window, session length, break length, max daily minutes
- **subjects** — name, code, color, difficulty; belongs to a user
- **tasks** — the core work item; estimated/predicted/actual/remaining minutes, status, priority, difficulty, deadline
- **task_history** — immutable log of every completed task's estimate vs. actual; this is what the learning engine reads
- **study_sessions** — individual scheduled blocks (including breaks) produced by the scheduler
- **availability** — per-weekday rolling average of planned vs. actual completed minutes, used for capacity learning
- **schedule_events** — declared unavailability windows (e.g. "family event", or the block created by "Something came up")
- **exams** — subject, date, topics, difficulty; auto-creates a linked exam-prep task on creation
- **attendance** — present/total/minimum-required per subject
- **rescheduling_events** — full old-vs-new schedule snapshot for every "Something came up" / manual reschedule, with accept/keep decision
- **notifications** — deterministically generated (deadline-soon, low-attendance, session-starting-soon)

Foreign keys cascade from `users` down through subjects/tasks/sessions so
deleting a user cleans up their data.

## API documentation

Once the backend is running, full interactive docs (generated by FastAPI
from the Pydantic schemas) are at **http://localhost:8000/docs**.

Summary of resource groups (`backend/app/routers/`):

| Router | Prefix | Purpose |
|---|---|---|
| auth | `/api/auth` | register, login, me |
| users | `/api/users` | preferences, profile |
| subjects | `/api/subjects` | CRUD |
| tasks | `/api/tasks` | CRUD, `/predict` (preview duration), `/start`, `/complete` |
| schedule | `/api/schedule` | `/generate`, list, `/warnings` |
| reschedule | `/api/reschedule` | `/something-came-up`, `/{id}/decision`, `/manual` |
| attendance | `/api/attendance` | list, upsert (returns computed can-miss / need-to-recover) |
| exams | `/api/exams` | CRUD (auto-creates prep task) |
| analytics | `/api/analytics` | aggregate stats incl. personal accuracy headline |
| assistant | `/api/assistant` | `/ask` |
| dashboard | `/api/dashboard` | single aggregated payload for the home screen |
| notifications | `/api/notifications` | list (auto-refreshes), mark read |

All routes except `/api/auth/register` and `/api/auth/login` require a
Bearer JWT (`Authorization: Bearer <token>`), obtained from the login/
register response.

## Setup instructions

### 1. Backend setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
```

### 2. Installing Python dependencies

```bash
pip install -r requirements.txt
```

### 3. Seed demo data (one-time)

```bash
python -m app.seed
```

This creates the demo account described below with realistic completed-task
history, so personalization is visible from the very first login.

### 4. Starting FastAPI

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Or simply run `./run.sh`, which does steps 1–4 for you and is idempotent
(safe to re-run).

Verify it's up: open http://localhost:8000/docs or run
`curl http://localhost:8000/api/health`.

### 5. Frontend setup

```bash
cd frontend/studentos
```

**This repo ships Dart source only — not the generated native platform
folders (`android/`, `ios/`, `web/`, etc.), which Flutter itself generates
and which are safe to regenerate. Run this once before anything else:**

```bash
flutter create . --platforms=android,ios
```

(add `,web` too if you want a web build target). This scaffolds the
platform folders around the existing `lib/` and `pubspec.yaml` without
touching your source code.

### 6. Installing Flutter dependencies

```bash
flutter pub get
```

### 7. Running the Flutter application

```bash
flutter run
```

Pick your target device/emulator when prompted, or pass `-d <device_id>`.

### 8. Connecting the mobile app to the backend

The app auto-detects a sane backend URL (see
`lib/config/api_config.dart`):

- **Android emulator** → `http://10.0.2.2:8000` (this is the emulator's
  alias for your host machine's `localhost` — Android emulators cannot
  reach `localhost` directly, hence the special address).
- **iOS simulator / desktop / web** → `http://localhost:8000` directly.

No configuration needed for emulator/simulator use — just make sure the
backend from step 4 is running.

### 9. Running with Android emulator

1. Start an emulator from Android Studio's Device Manager (or `emulator -avd <name>`).
2. With the backend running (step 4), run `flutter run` from
   `frontend/studentos` and select the emulator.
3. The app will reach the backend at `http://10.0.2.2:8000` automatically.

### 10. Running on a physical Android device

1. Enable Developer Options + USB debugging on the device, connect via USB
   (or use `adb connect <ip>` for wireless debugging), confirm it shows up
   in `flutter devices`.
2. Your phone can't resolve `localhost` or `10.0.2.2` to your computer — it
   needs your computer's **LAN IP address** (e.g. `192.168.1.23`). Find it
   with `ipconfig` (Windows) or `ifconfig`/`ip addr` (Mac/Linux).
3. Make sure the backend is bound to `0.0.0.0` (the default in `run.sh` and
   the command above already does this) and that your firewall allows
   inbound connections on port 8000.
4. Run:
   ```bash
   flutter run --dart-define=STUDENTOS_API_BASE_URL=http://192.168.1.23:8000
   ```
   (substitute your actual LAN IP).

## Demo credentials

```
Email:    demo@studentos.app
Password: demo1234
```

Pre-filled automatically on the login screen. This account (created by
`python -m app.seed`) has:
- 5 subjects with realistic attendance (one deliberately below 75%, so you
  can see the attendance-risk recommendation)
- ~15 completed historical tasks showing a clear personalization signal
  (programming/project tasks take ~1.5x the estimate; DBMS ~1.3x; AI theory
  ~1.6x; reading tasks ~0.9x)
- 5 currently open tasks with varying priority/deadlines
- 1 upcoming DBMS exam
- An already-generated 7-day schedule

## How personalization works

`backend/app/services/learning.py` implements a **fallback chain**:

1. If there are ≥3 completed tasks in the *same subject*, predict using that
   subject's average actual/estimated ratio (≥6 samples → "high" confidence,
   3–5 → "medium").
2. Otherwise, fall back to the same calculation scoped to the task's
   *category* (Assignment, Study, Project, ...).
3. Otherwise, fall back to the task's *difficulty* level.
4. With no relevant history at all, the app is honest about it: it shows
   "Learning from your task history..." and uses the student's own
   estimate rather than pretending to have a confident prediction.

This is surfaced live in the "New task" screen as you type — try creating a
new Assignment-category task under "Mobile Application Development" on the
demo account and watch the predicted duration update to roughly 1.5x your
estimate, with the exact basis explained underneath.

Daily capacity is learned the same way, per weekday, from the
`availability` table (rolling planned vs. actual completed minutes), falling
back to the student's manually configured max-daily-study-minutes when there
isn't enough history for a given weekday yet.

## How scheduling works

`backend/app/services/scheduler.py`'s `score_task()` computes, for every
open task:

```
score = 0.45 * urgency + 0.25 * priority + 0.10 * difficulty + 0.20 * risk
```

- **urgency** — remaining work relative to hours left until deadline
- **priority** — the student's stated Low/Medium/High/Critical
- **difficulty** — harder tasks get a small boost so they aren't left too late
- **risk** — 1.0 if projected capacity between now and the deadline can't
  cover the remaining work at all; otherwise scaled by how tight the margin is

Tasks are sorted by score (highest first) and the engine greedily fills each
day's realistic capacity window (learned or configured), splitting each
task's remaining work into sessions no longer than the student's preferred
session length, separated by their preferred break length — never packing
sessions back-to-back with no break, and never exceeding the day's capacity.

## How rescheduling works

"Something came up" (`POST /api/reschedule/something-came-up`):

1. Snapshots the *current* planned schedule from the affected date forward
   ("old").
2. Inserts a `schedule_events` block for the lost time.
3. Re-runs the full scheduling engine from the affected date forward — this
   is a genuine recalculation of every remaining task's placement, not a
   naive "shift everything by one day."
4. Checks every task with a deadline against what actually got scheduled
   before it, and generates plain-language warnings for anything now at
   deadline risk.
5. Returns old vs. new side by side; the student can **Accept new** (keeps
   the regenerated plan) or **Keep original** (deletes the inserted block and
   regenerates back to the prior state).

Manual rescheduling (`POST /api/reschedule/manual`, "move this task to
Saturday") clears that task's own sessions before the target date and lets
the engine re-place its remaining work starting from the next realistic slot
on/after that date, without disturbing other tasks' priority-based
placement.

## Future AI integration

`services/assistant.py` is written as a swappable layer. `AI_PROVIDER` in
`.env` currently only supports `local` (the default, fully offline). The
function signatures are structured so that a Gemini/OpenAI-backed
implementation could later:
- take the same deterministic data (schedule, learning stats, deadlines)
  computed by `scheduler.py`/`learning.py`,
- and use an LLM purely to phrase the answer more naturally or parse
  free-text "I have a family thing Tuesday and Wednesday" into structured
  `SomethingCameUpRequest` calls —
- **without ever asking the LLM to compute the schedule itself.** That
  boundary is intentional per the project spec and should be preserved by
  any future integration. If implemented, the API key must be read from an
  environment variable and never hard-coded or logged.

## Environment status / honesty note

- **Backend**: fully built, dependency-installed, and exercised end-to-end
  in the development sandbox this project was built in — the demo flow
  (login → dashboard → predict → create task → start → complete → something
  came up → accept new schedule → ask the assistant → analytics) was run
  live via HTTP requests against a running `uvicorn` instance, and all
  `pytest` unit tests pass.
- **Frontend**: the Dart source is complete for the full module list below,
  written carefully against the exact backend contracts above. However,
  this project was assembled in a sandbox **without network access to
  pub.dev**, so `flutter pub get`, `flutter analyze`, and `flutter build`
  could **not** be executed here. If you hit a compile error after `flutter
  pub get`, it's most likely a small naming/import mismatch — please open an
  issue-style note and it can be fixed quickly; nothing here claims a
  successful build that wasn't actually run.

## Tests

Backend (7 tests, all passing as of this build):

```bash
cd backend
source .venv/bin/activate
pytest tests/ -v
```

Covers: subject/category/difficulty duration prediction fallback chain,
estimation-error calculation, daily-capacity fallback, priority scoring
ordering, capacity-respecting schedule generation, and break insertion
between sessions.

Frontend:

```bash
cd frontend/studentos
flutter test
```

(One smoke test confirming the app boots to the splash screen; expand as
you build out more UI.)
