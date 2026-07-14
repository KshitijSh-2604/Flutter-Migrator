"""
Static analysis layer.
Parses pubspec.yaml, detects Flutter/Dart SDK versions,
fetches latest package versions from pub.dev — without AI.
"""

import re
import yaml
import zipfile
import httpx
from pathlib import Path
from typing import Optional
from packaging.version import Version, InvalidVersion


PUBDEV_URL = "https://pub.dev/api/packages/{package}"


async def fetch_latest_version(package_name: str) -> Optional[str]:
    """Hit pub.dev API to get the latest stable version of a package."""
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(PUBDEV_URL.format(package=package_name))
            if resp.status_code == 200:
                data = resp.json()
                return data.get("latest", {}).get("pubspec", {}).get("version")
    except Exception:
        pass
    return None


def parse_version_constraint(constraint: str) -> Optional[str]:
    """Extract a plain version number from a constraint like ^5.0.0 or >=5.0.0 <6.0.0"""
    match = re.search(r"[\d]+\.[\d]+\.[\d]+", constraint or "")
    return match.group(0) if match else None


def is_breaking_upgrade(installed: Optional[str], latest: Optional[str]) -> bool:
    """Return True if major version changed (1.x → 2.x means breaking changes)."""
    if not installed or not latest:
        return False
    try:
        old = Version(installed)
        new = Version(latest)
        return new.major > old.major
    except InvalidVersion:
        return False


def parse_pubspec(content: str) -> dict:
    """
    Parse pubspec.yaml content string.
    Returns:
      flutter_version: str | None
      dart_sdk: str | None
      dependencies: {name: version_str}
      dev_dependencies: {name: version_str}
    """
    try:
        data = yaml.safe_load(content)
    except yaml.YAMLError:
        return {}

    env = data.get("environment", {})

    def extract_deps(section) -> dict:
        result = {}
        if not isinstance(section, dict):
            return result
        for name, val in section.items():
            if name in ("flutter", "flutter_test"):
                continue
            if isinstance(val, str):
                result[name] = val
            elif isinstance(val, dict):
                result[name] = val.get("version", "any")
            else:
                result[name] = "any"
        return result

    return {
        "flutter_version": env.get("flutter"),
        "dart_sdk": env.get("sdk"),
        "app_name": data.get("name"),
        "dependencies": extract_deps(data.get("dependencies", {})),
        "dev_dependencies": extract_deps(data.get("dev_dependencies", {})),
    }


async def analyze_packages(dependencies: dict) -> list:
    """
    For each dependency, fetch latest version from pub.dev and compute status.
    Returns list of dicts:
      {name, installed_version, latest_version, status}
      status: "ok" | "upgrade" | "breaking" | "unknown"
    """
    results = []
    for name, constraint in dependencies.items():
        installed = parse_version_constraint(str(constraint))
        latest = await fetch_latest_version(name)
        if latest is None:
            status = "unknown"
        elif installed is None:
            status = "unknown"
        elif Version(installed) >= Version(latest):
            status = "ok"
        elif is_breaking_upgrade(installed, latest):
            status = "breaking"
        else:
            status = "upgrade"
        results.append({
            "name": name,
            "installed_version": installed or str(constraint),
            "latest_version": latest or "unknown",
            "status": status,
        })
    return results


def extract_dart_files_from_zip(zip_bytes: bytes) -> dict:
    """
    Given raw ZIP bytes of a Flutter project, extract:
      - pubspec.yaml content
      - All .dart file contents as {relative_path: content}
      - android/build.gradle
      - ios/Podfile
    Improved to find the project root (where pubspec.yaml lives).
    """
    dart_files = {}
    pubspec_content = None
    build_gradle = None
    podfile = None
    
    try:
        import io
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
            namelist = zf.namelist()
            print(f"DEBUG: ZIP namelist: {namelist[:10]}... ({len(namelist)} files)")
            
            # 1. Find the project root (where pubspec.yaml is)
            root_prefix = ""
            for name in namelist:
                if name.endswith("pubspec.yaml"):
                    root_prefix = name.replace("pubspec.yaml", "")
                    print(f"DEBUG: Found pubspec.yaml at {name}, root_prefix: '{root_prefix}'")
                    break
            
            # 2. Extract files relative to that root
            for name in namelist:
                if name.startswith(root_prefix) and not name.endswith("/"):
                    # Get the path relative to the pubspec.yaml
                    rel_path = name[len(root_prefix):]
                    
                    try:
                        content = zf.read(name).decode("utf-8", errors="ignore")
                    except Exception:
                        continue

                    if rel_path == "pubspec.yaml":
                        pubspec_content = content
                    # We now accept .dart files anywhere in the project, not just in lib/
                    elif rel_path.endswith(".dart"):
                        dart_files[rel_path] = content
                    elif rel_path in ("android/app/build.gradle", "android/build.gradle"):
                        build_gradle = content
                    elif rel_path == "ios/Podfile":
                        podfile = content
            
            print(f"DEBUG: Extracted {len(dart_files)} dart files")
    except zipfile.BadZipFile:
        pass

    return {
        "pubspec": pubspec_content,
        "dart_files": dart_files,
        "android_build_gradle": build_gradle,
        "ios_podfile": podfile,
    }


def infer_dependencies_from_code(code: str) -> dict:
    """
    Look for 'import package:name/...' and return {name: 'latest'}
    Useful as a fallback for pasted code when AI fails.
    """
    imports = re.findall(r"import\s+['\"]package:([^/]+)/", code)
    # Filter out core flutter/dart packages
    ignore = {"flutter", "dart", "flutter_test", "meta"}
    found = {}
    for name in imports:
        if name not in ignore:
            found[name] = "latest"
    return found
