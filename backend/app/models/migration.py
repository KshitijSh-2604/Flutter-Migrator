from sqlalchemy import Column, Integer, String, Text, DateTime
from sqlalchemy.sql import func
from ..database import Base


class Migration(Base):
    __tablename__ = "migrations"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(String(255), nullable=False, index=True) # Supabase User ID
    title = Column(String(255), nullable=False)
    original_code = Column(Text, nullable=False)
    migrated_code = Column(Text, nullable=True)
    # Stored as JSON strings
    changes_summary = Column(Text, nullable=True)
    pubspec_changes = Column(Text, nullable=True)
    recommended_packages = Column(Text, nullable=True)
    migration_steps = Column(Text, nullable=True)
    flutter_version_from = Column(String(50), nullable=True)
    flutter_version_to = Column(String(50), default="3.24.0")
    status = Column(String(20), default="pending")   # pending | completed | failed
    error_message = Column(Text, nullable=True)
    source_type = Column(String(20), default="paste")   # paste | file | zip | github
    github_url = Column(String(500), nullable=True)
    original_filename = Column(String(255), nullable=True)
    detected_sdk = Column(String(100), nullable=True)    # e.g. ">=2.12.0 <3.0.0"
    package_analysis = Column(Text, nullable=True)       # JSON: [{name, installed, latest, status}]
    android_changes = Column(Text, nullable=True)        # JSON: changes to build.gradle etc.
    ios_changes = Column(Text, nullable=True)            # JSON: changes to Podfile etc.
    confidence_score = Column(Integer, nullable=True)    # 0-100 overall confidence
    files_analyzed = Column(Integer, default=0)
    files_migrated = Column(Integer, default=0)
    files_data = Column(Text, nullable=True)             # JSON: { "path": {"original": "...", "migrated": "...", "changes": [...] } }
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())