import os
import tempfile
import pytest

# Use an isolated temp SQLite DB for tests, set before importing app modules
_tmp_dir = tempfile.mkdtemp()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_dir}/test.db"

from app.database import SessionLocal, init_db, Base, engine  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _init_test_db():
    init_db()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db():
    session = SessionLocal()
    yield session
    session.close()
