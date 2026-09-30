# ARCHITECTURE.md

Short version of the technical decisions behind StudentOS and why.

## 1. Scheduling math lives entirely in the backend, never in an LLM

This was an explicit constraint in the spec, and it's a good one regardless:
LLM output for a numeric scheduling problem is non-deterministic and
unauditable. `services/scheduler.py` and `services/learning.py` are plain
Python functions over SQLAlchemy queries — every prediction and every
schedule slot can be traced to a specific formula. This also makes the
engine unit-testable (`tests/test_scheduler.py`, `tests/test_learning.py`)
in a way an LLM-driven scheduler couldn't be.

The AI Assistant (`services/assistant.py`) is kept as a thin layer that
*reads* the same deterministic data and answers questions about it. It's
implemented with local intent-matching rather than an LLM by default so the
whole app works with zero external dependencies or API keys — the spec
explicitly required this ("must work without an API key").

## 2. Fallback-chain personalization instead of a single global model

Rather than training any kind of model, duration prediction uses a simple,
explainable fallback chain: subject-specific average → category-specific →
difficulty-specific → the student's own raw estimate. This was chosen over
a fancier approach (e.g. linear regression over multiple features) because:

- It's directly explainable to the student ("based on your last 6 tasks in
  this subject, you typically take 1.3x your estimate") — a black-box model
  wouldn't let the app show its work, which the spec calls for repeatedly.
- It degrades gracefully with sparse data — a new student's first task in a
  new subject correctly falls through to category, then difficulty, then
  finally an honest "not enough history yet."
- It matches how a human academic advisor would actually reason about it.

## 3. Capacity is tracked separately from availability, per weekday

`Availability` rows store a rolling planned/actual pair per weekday
(0=Monday..6=Sunday), updated every time a task is completed. This lets
"Saturday capacity" differ from "Tuesday capacity" without any manual
configuration — exactly the "6 hours free but only 3 hours realistic
productive capacity" distinction called out in the spec. Fallback is the
student's manually configured `max_daily_study_minutes` until at least 2
samples exist for that weekday.

## 4. Sessions, not task-blocks

The scheduler never blocks "6pm–9pm: DBMS Assignment" as one chunk. It always
splits into the student's preferred session length with breaks in between,
because forcing a fixed session length onto every student contradicts the
spec's "do not force everyone into the same study duration" requirement.
Session/break lengths are per-student preferences (`student_preferences`
table), editable from the Profile screen.

## 5. Rescheduling recalculates, it doesn't shift

A naive "something came up" implementation would just push every task back
by however much time was lost. Instead, `something_came_up()` inserts a
blocking `ScheduleEvent` and re-runs the *entire* scheduling engine from that
date forward — so a low-priority task might legitimately move later than a
newly-more-urgent one, exactly matching the spec's explicit "do not simply
move everything by one day" requirement. The old plan is snapshotted before
regeneration so the UI can show a true before/after and let the student
choose to keep the original.

## 6. Auth is JWT + bcrypt, deliberately minimal

The spec calls for either local auth or a simple backend auth system, with
hashed passwords and a demo account — not a full production-grade auth
system (no refresh tokens, no email verification, no OAuth). JWT with a
generous expiry (`ACCESS_TOKEN_EXPIRE_MINUTES=1440`, i.e. 24h) plus bcrypt
hashing satisfies "passwords must not be stored as plaintext" without
over-engineering an MVP.

## 7. Single aggregated `/api/dashboard` endpoint

Rather than making the Flutter dashboard fire five separate requests (which
would be slower and more error-prone to keep in sync), one endpoint computes
everything the home screen needs — today's capacity/schedule, the top
priority task, this week's planned vs. completed minutes, and upcoming
deadlines — in a single round trip.

## 8. Exams auto-create a prep task

Rather than having exams live in their own silo, `POST /api/exams`
immediately creates a linked `Task` (category = Exam Preparation, priority
scaled by days-until-exam) so the scheduling engine picks it up automatically
with appropriate urgency — matching the spec's "the scheduler should
consider exams when creating study sessions" requirement without needing a
separate code path in the scheduler itself.

## 9. Frontend: Riverpod over Provider

The spec allowed either, with a preference for Riverpod "if it does not
unnecessarily complicate the project." Riverpod's `FutureProvider.autoDispose`
pattern maps cleanly onto this app's "fetch-on-screen-open, refresh-on-pull"
data flow (dashboard, tasks list, analytics, attendance, exams all follow the
same shape), without needing `ChangeNotifier` boilerplate per screen.

## 10. What was deliberately kept out of MVP scope

- Push notifications are backed by a real, queryable `/api/notifications`
  endpoint with deterministic generation logic, but actual OS-level push
  delivery (FCM/APNs registration) is a platform-configuration concern
  documented as a follow-up rather than implemented, per the spec's own
  allowance ("if notification setup becomes platform-specific, implement the
  architecture and document the setup clearly").
- Task dependencies (Module 9 mentions them as "where applicable") are not
  modeled as a separate graph — sequencing in practice is achieved through
  deadlines and priority, which covers the stated use cases without adding
  a dependency-resolution subsystem the demo flow doesn't exercise.
