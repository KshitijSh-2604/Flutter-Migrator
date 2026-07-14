from pydantic import BaseModel, HttpUrl
from typing import Optional, List
from datetime import datetime


class MigrationCreate(BaseModel):
    title: str
    original_code: str
    flutter_version_from: Optional[str] = None
    flutter_version_to: Optional[str] = None
    source_type: Optional[str] = "paste"


# NEW schema for GitHub URL input
class GithubMigrationCreate(BaseModel):
    github_url: str          # e.g. https://github.com/user/repo
    title: Optional[str] = None
    flutter_version_from: Optional[str] = None
    flutter_version_to: Optional[str] = None


# NEW schema for package info
class PackageInfo(BaseModel):
    name: str
    installed_version: Optional[str] = None
    latest_version: Optional[str] = None
    status: str              # ok | upgrade | breaking | unknown


class MigrationResponse(BaseModel):
    id: int
    title: str
    original_code: str
    migrated_code: Optional[str] = None
    changes_summary: Optional[str] = None
    pubspec_changes: Optional[str] = None
    recommended_packages: Optional[str] = None
    migration_steps: Optional[str] = None
    flutter_version_from: Optional[str] = None
    flutter_version_to: Optional[str] = None
    status: str
    error_message: Optional[str] = None
    # NEW fields:
    source_type: Optional[str] = "paste"
    github_url: Optional[str] = None
    original_filename: Optional[str] = None
    detected_sdk: Optional[str] = None
    package_analysis: Optional[str] = None
    android_changes: Optional[str] = None
    ios_changes: Optional[str] = None
    confidence_score: Optional[int] = None
    files_analyzed: Optional[int] = 0
    files_migrated: Optional[int] = 0
    files_data: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MigrationListResponse(BaseModel):
    migrations: List[MigrationResponse]
    total: int


class HealthResponse(BaseModel):
    status: str
    message: str
    version: str