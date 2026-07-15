"""
Rule engine — deterministic Flutter migration rules with version awareness.
Each rule now has a 'min_version' to ensure we only apply relevant changes.
"""

import re
from packaging.version import Version

# Format: (description, old_pattern, replacement, category, min_version)
WIDGET_RULES = [
    # --- Buttons (Dart 2.12 / Flutter 2.0+) ---
    ("RaisedButton → ElevatedButton",
     r"\bRaisedButton\b", "ElevatedButton", "Widget API", "2.0.0"),
    ("FlatButton → TextButton",
     r"\bFlatButton\b", "TextButton", "Widget API", "2.0.0"),
    ("OutlineButton → OutlinedButton",
     r"\bOutlineButton\b", "OutlinedButton", "Widget API", "2.0.0"),
    
    # --- Theming (Flutter 2.5+) ---
    ("accentColor → colorScheme.secondary",
     r"\baccentColor\b", "colorScheme.secondary", "Theming", "2.5.0"),
    
    # --- Typography (Flutter 3.0+) ---
    ("headline6 → titleLarge",
     r"\.headline6\b", ".titleLarge", "Typography", "3.0.0"),
    ("bodyText1 → bodyLarge",
     r"\.bodyText1\b", ".bodyLarge", "Typography", "3.0.0"),
    ("bodyText2 → bodyMedium",
     r"\.bodyText2\b", ".bodyMedium", "Typography", "3.0.0"),
    ("subtitle1 → titleMedium",
     r"\.subtitle1\b", ".titleMedium", "Typography", "3.0.0"),
    ("caption → bodySmall",
     r"\.caption\b", ".bodySmall", "Typography", "3.0.0"),
    
    # --- Navigator (Flutter 3.12+) ---
    ("WillPopScope → PopScope",
     r"\bWillPopScope\b", "PopScope", "Navigation", "3.12.0"),
    ("onWillPop → onPopInvoked",
     r"\bonWillPop\b", "onPopInvokedWithResult", "Navigation", "3.12.0"),

    # --- Modernization (Always applied to 2.12+) ---
    ("Remove legacy 'new' keyword",
     r"\bnew\s+([A-Z])", r"\1", "Modernization", "2.12.0"),
]

def apply_dart_rules(code: str, target_version: str = "3.24.0") -> tuple[str, list[dict]]:
    """
    Apply deterministic rules if target_version >= rule's min_version.
    """
    changes = []
    migrated = code
    
    try:
        target_v = Version(target_version)
    except:
        target_v = Version("3.0.0")

    for description, pattern, replacement, category, min_v_str in WIDGET_RULES:
        if target_v >= Version(min_v_str):
            new_code = re.sub(pattern, replacement, migrated)
            if new_code != migrated:
                match = re.search(pattern, migrated)
                before_sample = match.group(0) if match else pattern
                after_sample = re.sub(pattern, replacement, before_sample)
                
                changes.append({
                    "category": category,
                    "description": description,
                    "before": before_sample,
                    "after": after_sample,
                    "source": "rule_engine",
                    "confidence": 100,
                })
                migrated = new_code

    return migrated, changes

def apply_android_rules(gradle_content: str) -> tuple[str, list[dict]]:
    """Legacy rules for Gradle migration."""
    ANDROID_RULES = [
        ("compileSdkVersion → compileSdk", r"compileSdkVersion\s+(\d+)", r"compileSdk \1"),
        ("targetSdkVersion → targetSdk", r"targetSdkVersion\s+(\d+)", r"targetSdk \1"),
    ]
    changes = []
    migrated = gradle_content
    for desc, pat, rep in ANDROID_RULES:
        new_code = re.sub(pat, rep, migrated)
        if new_code != migrated:
            changes.append({"category": "Android", "description": desc, "source": "rule_engine", "confidence": 100})
            migrated = new_code
    return migrated, changes

def compute_confidence(rule_changes: list, ai_changes: list) -> int:
    total = len(rule_changes) + len(ai_changes)
    if total == 0: return 95
    rule_weight = len(rule_changes) / total
    return int(70 + rule_weight * 30)
