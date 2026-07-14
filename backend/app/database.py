from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from .config import settings

# SQLite-specific: check_same_thread=False is needed for SQLite
# When using PostgreSQL, remove connect_args
connect_args = {}
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
    echo=False,   # Set True to log all SQL queries during debugging
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def create_tables():
    """
    Creates all tables in the database.
    """
    Base.metadata.create_all(bind=engine)


def get_db():
    """
    FastAPI dependency — yields a DB session per request,
    always closes it after the request finishes.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()