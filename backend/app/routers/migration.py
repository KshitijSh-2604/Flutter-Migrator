import io
import json
import zipfile
import httpx
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Header
from sqlalchemy.orm import Session
from typing import Optional

from ..database import get_db
from ..models.migration import Migration
from ..schemas.migration import (
    MigrationCreate, MigrationResponse, MigrationListResponse, GithubMigrationCreate
)
from ..services.ai_service import migrate_with_ai, validate_api_key
from ..services.rule_engine import apply_dart_rules, apply_android_rules, compute_confidence
from ..services.project_analyzer import (
    parse_pubspec, analyze_packages, extract_dart_files_from_zip, infer_dependencies_from_code
)
from ..config import settings

router = APIRouter(prefix="/api/migrations", tags=["migrations"])

@router.post("/validate-key")
async def check_key(payload: dict):
    """Check if provided API key is valid."""
    key = payload.get("key")
    provider = payload.get("provider") # 'openai' or 'gemini'
    if not key or not provider:
        raise HTTPException(400, "Key and provider required")
    
    is_valid = await validate_api_key(key, provider)
    if is_valid:
        return {"status": "ok"}
    else:
        raise HTTPException(401, "Invalid API key")


# ── Shared migration pipeline ─────────────────────────────────────────────────

async def _run_migration_pipeline(
        db: Session,
        migration: Migration,
        code: str,
        pubspec_content: Optional[str] = None,
        android_gradle: Optional[str] = None,
        ios_podfile: Optional[str] = None,
        extra_dart_files: Optional[dict] = None,
        user_gemini_key: str = None,
        user_openai_key: str = None,
) -> Migration:
    try:
        pubspec_data = {}
        package_analysis = []
        target_v_str = migration.flutter_version_to or settings.flutter_version_target
        
        if pubspec_content:
            pubspec_data = parse_pubspec(pubspec_content)
            flutter_version_from = pubspec_data.get("flutter_version") or migration.flutter_version_from
            dart_sdk = pubspec_data.get("dart_sdk")
            migration.flutter_version_from = flutter_version_from
            migration.detected_sdk = dart_sdk

            all_deps = {
                **pubspec_data.get("dependencies", {}),
                **pubspec_data.get("dev_dependencies", {}),
            }
            package_analysis = await analyze_packages(all_deps)
            migration.package_analysis = json.dumps(package_analysis)
        else:
            flutter_version_from = migration.flutter_version_from
            dart_sdk = None

        rule_migrated_code, rule_changes = apply_dart_rules(code, target_v_str)

        if android_gradle:
            migrated_gradle, android_changes_list = apply_android_rules(android_gradle)
            migration.android_changes = json.dumps({
                "migrated_gradle": migrated_gradle,
                "changes": android_changes_list,
            })

        ai_changes = []
        is_multi_file = True if extra_dart_files else False
        
        if not is_multi_file:
            try:
                ai_result = await migrate_with_ai(
                    code=rule_migrated_code,
                    flutter_version_from=flutter_version_from,
                    flutter_version_to=target_v_str,
                    package_analysis=package_analysis,
                    dart_sdk=dart_sdk,
                    user_gemini_key=user_gemini_key,
                    user_openai_key=user_openai_key
                )
                ai_changes = ai_result.get("changes_summary", [])
                migration.migrated_code = ai_result.get("migrated_code", rule_migrated_code)
                migration.pubspec_changes = json.dumps(ai_result.get("pubspec_changes", {}))
                migration.recommended_packages = json.dumps(ai_result.get("recommended_packages", []))
                migration.migration_steps = json.dumps(ai_result.get("migration_steps", []))
            except Exception as ai_err:
                migration.migrated_code = rule_migrated_code
                migration.error_message = f"AI Migration skipped. Details: {str(ai_err)}"
                migration.pubspec_changes = json.dumps({})
                migration.migration_steps = json.dumps(["Rule engine applied.", f"AI failed: {str(ai_err)[:100]}"])
        else:
            migration.migrated_code = rule_migrated_code
            migration.migration_steps = json.dumps([
                "Project scanned and rule-based migrations applied to all files.",
                "Click 'Migrate with AI' on individual files to perform deep refactoring."
            ])

        files_results = {}
        p_key = "lib/main.dart"
        files_results[p_key] = {
            "original": code,
            "migrated": migration.migrated_code,
            "changes": rule_changes + ai_changes,
            "ai_migrated": not is_multi_file
        }
        
        if extra_dart_files:
            for path, content in extra_dart_files.items():
                if path == p_key: continue
                m_code, m_changes = apply_dart_rules(content, target_v_str)
                files_results[path] = {
                    "original": content,
                    "migrated": m_code,
                    "changes": m_changes,
                    "ai_migrated": False
                }

        migration.files_data = json.dumps(files_results)
        migration.changes_summary = json.dumps(rule_changes + ai_changes)
        migration.confidence_score = compute_confidence(rule_changes, ai_changes)
        migration.files_analyzed = len(files_results)
        migration.files_migrated = 1 if not is_multi_file else 0
        migration.status = "completed"

    except Exception as e:
        migration.status = "failed"
        migration.error_message = str(e)

    db.commit()
    db.refresh(migration)
    return migration


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/", response_model=MigrationResponse, status_code=201)
async def create_migration(
    payload: MigrationCreate, 
    db: Session = Depends(get_db),
    x_user_id: str = Header(...),
    x_gemini_key: Optional[str] = Header(None),
    x_openai_key: Optional[str] = Header(None)
):
    migration = Migration(
        user_id=x_user_id,
        title=payload.title,
        original_code=payload.original_code,
        flutter_version_from=payload.flutter_version_from,
        flutter_version_to=payload.flutter_version_to or settings.flutter_version_target,
        source_type="paste",
        status="pending",
    )
    db.add(migration)
    db.commit()
    db.refresh(migration)
    return await _run_migration_pipeline(
        db, migration, payload.original_code,
        user_gemini_key=x_gemini_key,
        user_openai_key=x_openai_key
    )


@router.post("/upload", response_model=MigrationResponse, status_code=201)
async def migrate_dart_file(
        file: UploadFile = File(...),
        title: Optional[str] = Form(None),
        flutter_version_from: Optional[str] = Form(None),
        flutter_version_to: Optional[str] = Form(None),
        db: Session = Depends(get_db),
        x_user_id: str = Header(...),
        x_gemini_key: Optional[str] = Header(None),
        x_openai_key: Optional[str] = Header(None)
):
    if not file.filename.endswith(".dart"):
        raise HTTPException(400, "Only .dart files supported here.")
    content = (await file.read()).decode("utf-8")
    migration = Migration(
        user_id=x_user_id,
        title=title or file.filename,
        original_code=content,
        original_filename=file.filename,
        flutter_version_from=flutter_version_from,
        flutter_version_to=flutter_version_to or settings.flutter_version_target,
        source_type="file",
        status="pending",
    )
    db.add(migration)
    db.commit()
    db.refresh(migration)
    return await _run_migration_pipeline(
        db, migration, content,
        user_gemini_key=x_gemini_key,
        user_openai_key=x_openai_key
    )


@router.post("/upload-zip", response_model=MigrationResponse, status_code=201)
async def migrate_zip_project(
        file: UploadFile = File(...),
        title: Optional[str] = Form(None),
        flutter_version_from: Optional[str] = Form(None),
        flutter_version_to: Optional[str] = Form(None),
        db: Session = Depends(get_db),
        x_user_id: str = Header(...),
        x_gemini_key: Optional[str] = Header(None),
        x_openai_key: Optional[str] = Header(None)
):
    if not file.filename.endswith(".zip"):
        raise HTTPException(400, "Only .zip files accepted.")
    zip_bytes = await file.read()
    ext = extract_dart_files_from_zip(zip_bytes)
    dart_files = ext.get("dart_files", {})
    pubspec = ext.get("pubspec")
    if not dart_files and not pubspec:
        raise HTTPException(400, "No valid Flutter project files found in ZIP.")
    
    primary = dart_files.get("lib/main.dart") or next(iter(dart_files.values()), "")
    migration = Migration(
        user_id=x_user_id,
        title=title or file.filename.replace(".zip", ""),
        original_code=primary,
        original_filename=file.filename,
        flutter_version_from=flutter_version_from,
        flutter_version_to=flutter_version_to or settings.flutter_version_target,
        source_type="zip",
        status="pending",
    )
    db.add(migration)
    db.commit()
    db.refresh(migration)
    return await _run_migration_pipeline(
        db, migration, primary,
        pubspec_content=pubspec,
        android_gradle=ext.get("android_build_gradle"),
        ios_podfile=ext.get("ios_podfile"),
        extra_dart_files=dart_files,
        user_gemini_key=x_gemini_key,
        user_openai_key=x_openai_key
    )


@router.post("/github", response_model=MigrationResponse, status_code=201)
async def migrate_github_repo(
        payload: GithubMigrationCreate,
        db: Session = Depends(get_db),
        x_user_id: str = Header(...),
        x_gemini_key: Optional[str] = Header(None),
        x_openai_key: Optional[str] = Header(None)
):
    url = payload.github_url.rstrip("/")
    if "github.com/" not in url: raise HTTPException(400, "Invalid URL")
    parts = url.split("github.com/")[-1].split("/")
    owner, repo = parts[0], parts[1]
    zip_url = f"https://api.github.com/repos/{owner}/{repo}/zipball"

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            resp = await client.get(zip_url)
            if resp.status_code != 200: raise HTTPException(400, "Repo not found")
            zip_bytes = resp.content
    except Exception as e: raise HTTPException(408, str(e))

    ext = extract_dart_files_from_zip(zip_bytes)
    dart_files = ext.get("dart_files", {})
    pubspec = ext.get("pubspec")
    primary = dart_files.get("lib/main.dart") or next(iter(dart_files.values()), "")

    migration = Migration(
        user_id=x_user_id,
        title=payload.title or f"{owner}/{repo}",
        original_code=primary,
        original_filename=f"{owner}/{repo}",
        flutter_version_from=payload.flutter_version_from,
        flutter_version_to=payload.flutter_version_to or settings.flutter_version_target,
        source_type="github",
        github_url=payload.github_url,
        status="pending",
    )
    db.add(migration)
    db.commit()
    db.refresh(migration)
    return await _run_migration_pipeline(
        db, migration, primary,
        pubspec_content=pubspec,
        android_gradle=ext.get("android_build_gradle"),
        ios_podfile=ext.get("ios_podfile"),
        extra_dart_files=dart_files,
        user_gemini_key=x_gemini_key,
        user_openai_key=x_openai_key
    )


@router.post("/{migration_id}/migrate-file", response_model=MigrationResponse)
async def migrate_file_on_demand(
    migration_id: int,
    payload: dict, # {"file_path": "lib/main.dart"}
    db: Session = Depends(get_db),
    x_user_id: str = Header(...),
    x_gemini_key: Optional[str] = Header(None),
    x_openai_key: Optional[str] = Header(None)
):
    m = db.query(Migration).filter(Migration.id == migration_id, Migration.user_id == x_user_id).first()
    if not m: raise HTTPException(404, "Migration not found")
    
    path = payload.get("file_path")
    files_data = json.loads(m.files_data or "{}")
    if path not in files_data: raise HTTPException(404, "File not in project")
    
    file_info = files_data[path]
    original = file_info["original"]
    
    r_code, r_changes = apply_dart_rules(original, m.flutter_version_to)
    
    try:
        pkgs = json.loads(m.package_analysis or "[]")
        ai_res = await migrate_with_ai(
            code=r_code,
            flutter_version_from=m.flutter_version_from,
            flutter_version_to=m.flutter_version_to,
            package_analysis=pkgs,
            dart_sdk=m.detected_sdk,
            user_gemini_key=x_gemini_key,
            user_openai_key=x_openai_key
        )
        
        files_data[path] = {
            "original": original,
            "migrated": ai_res.get("migrated_code", r_code),
            "changes": r_changes + ai_res.get("changes_summary", []),
            "ai_migrated": True
        }
        m.files_data = json.dumps(files_data)
        db.commit()
        db.refresh(m)
        return m
    except Exception as e:
        raise HTTPException(500, str(e))


@router.get("/", response_model=MigrationListResponse)
def list_migrations(
    skip: int = 0, 
    limit: int = 50, 
    db: Session = Depends(get_db),
    x_user_id: str = Header(...)
):
    total = db.query(Migration).filter(Migration.user_id == x_user_id).count()
    items = db.query(Migration).filter(Migration.user_id == x_user_id).order_by(Migration.created_at.desc()).offset(skip).limit(limit).all()
    return {"migrations": items, "total": total}


@router.get("/{migration_id}", response_model=MigrationResponse)
def get_migration(
    migration_id: int, 
    db: Session = Depends(get_db),
    x_user_id: str = Header(...)
):
    m = db.query(Migration).filter(Migration.id == migration_id, Migration.user_id == x_user_id).first()
    if not m: raise HTTPException(404, "NotFound")
    return m


@router.delete("/{migration_id}", status_code=204)
def delete_migration(
    migration_id: int, 
    db: Session = Depends(get_db),
    x_user_id: str = Header(...)
):
    m = db.query(Migration).filter(Migration.id == migration_id, Migration.user_id == x_user_id).first()
    if not m: raise HTTPException(404, "NotFound")
    db.delete(m)
    db.commit()
