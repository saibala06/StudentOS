#!/usr/bin/env bash
# Convenience script: creates a venv (if missing), installs deps, seeds the
# demo account (if not already seeded), and starts the API on :8000.
set -e
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo "Creating virtual environment..."
  python3 -m venv .venv
fi

source .venv/bin/activate
pip install -q -r requirements.txt

if [ ! -f "studentos.db" ]; then
  echo "Seeding demo data..."
  python -m app.seed
fi

echo "Starting StudentOS API on http://127.0.0.1:8000 (docs at /docs)"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
