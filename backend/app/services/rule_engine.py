"""
Rule engine — deterministic Flutter migration rules.
These transformations don't need AI. They are fast and free.
Apply this BEFORE calling the LLM so the AI only handles complex cases.
"""

import re

# Each rule: (description, old_pattern_regex, new_replacement, category)
WIDGET_RULES = [
    # Buttons
    ("RaisedButton removed → ElevatedButton",
     r"\bRaisedButton\b", "ElevatedButton", "Widget API"),
    ("FlatButton removed → TextButton",
     r"\bFlatButton\b", "TextButton", "Widget API"),
    ("OutlineButton removed → OutlinedButton",
     r"\bOutlineButton\b", "OutlinedButton", "Widget API"),
    ("RaisedButton.icon → ElevatedButton.icon",
     r"\bRaisedButton\.icon\b", "ElevatedButton.icon", "Widget API"),
    ("FlatButton.icon → TextButton.icon",
     r"\bFlatButton\.icon\b", "TextButton.icon", "Widget API"),

    # Colors
    ("accentColor deprecated → colorScheme.secondary",
     r"\baccentColor\b", "colorScheme.secondary", "Theming"),
    ("primaryColorBrightness removed",
     r"\bprimaryColorBrightness\b", "/* primaryColorBrightness removed */", "Theming"),
    ("backgroundColor in AppBar → use surfaceTintColor",
     r"AppBar\(([^)]*?)backgroundColor:", "AppBar(\\1backgroundColor:", "Theming"),

    # Scaffold
    ("Scaffold.of() deprecated → ScaffoldMessenger.of()",
     r"Scaffold\.of\(context\)\.showSnackBar",
     "ScaffoldMessenger.of(context).showSnackBar", "Navigation"),

    # Text
    ("headline1-6 deprecated → displayLarge etc.",
     r"Theme\.of\(context\)\.textTheme\.headline1",
     "Theme.of(context).textTheme.displayLarge", "Typography"),
    ("bodyText1 → bodyLarge",
     r"\.bodyText1\b", ".bodyLarge", "Typography"),
    ("bodyText2 → bodyMedium",
     r"\.bodyText2\b", ".bodyMedium", "Typography"),
    ("subtitle1 → titleMedium",
     r"\.subtitle1\b", ".titleMedium", "Typography"),
    ("subtitle2 → titleSmall",
     r"\.subtitle2\b", ".titleSmall", "Typography"),
    ("headline6 → titleLarge",
     r"\.headline6\b", ".titleLarge", "Typography"),
    ("caption → bodySmall",
     r"\.caption\b", ".bodySmall", "Typography"),
    ("overline → labelSmall",
     r"\.overline\b", ".labelSmall", "Typography"),

    # Navigator
    ("WillPopScope → PopScope",
     r"\bWillPopScope\b", "PopScope", "Navigation"),
    ("onWillPop → onPopInvoked",
     r"\bonWillPop\b", "onPopInvokedWithResult", "Navigation"),

    # Null Safety & Modernization
    ("Remove unnecessary 'new' keyword",
     r"\bnew\s+([A-Z])", r"\1", "Modernization"),
    ("Migrate legacy List constructor",
     r"new List<([^>]+)>\(\)", r"<\1>[]", "Modernization"),
    ("StatelessWidget build must return Widget",
     r"(\s+)Widget build\(BuildContext context\)", "\\1@override\n\\1Widget build(BuildContext context)", "Null Safety"),
    ("Add required keyword to constructor",
     r"\{this\.", "{required this.", "Null Safety"),
    ("Replace nullable checks in factories",
     r"json\[\"([^\"]+)\"\] == null \? null :", r"json['\1'] == null ? null :", "Modernization"),
    ("Fix double cast in factories",
     r"\.toDouble\(\)", r"?.toDouble()", "Null Safety"),
]


ANDROID_RULES = [
    ("compileSdkVersion → compileSdk (Gradle 7+)",
     r"compileSdkVersion\s+(\d+)", r"compileSdk \1"),
    ("targetSdkVersion → targetSdk",
     r"targetSdkVersion\s+(\d+)", r"targetSdk \1"),
    ("minSdkVersion → minSdk",
     r"minSdkVersion\s+(\d+)", r"minSdk \1"),
]


def apply_dart_rules(code: str) -> tuple[str, list[dict]]:
    """
    Apply all deterministic WIDGET_RULES to code.
    Returns (migrated_code, list_of_applied_changes).
    """
    changes = []
    migrated = code

    for description, pattern, replacement, category in WIDGET_RULES:
        new_code = re.sub(pattern, replacement, migrated)
        if new_code != migrated:
            # Find a sample of what changed
            match = re.search(pattern, migrated)
            before_sample = match.group(0) if match else pattern
            after_sample = re.sub(pattern, replacement, before_sample)
            changes.append({
                "category": category,
                "description": description,
                "before": before_sample,
                "after": after_sample,
                "source": "rule_engine",
                "confidence": 100,   # deterministic = 100% confident
            })
            migrated = new_code

    return migrated, changes


def apply_android_rules(gradle_content: str) -> tuple[str, list[dict]]:
    """Apply deterministic Gradle migration rules."""
    changes = []
    migrated = gradle_content

    for description, pattern, replacement in ANDROID_RULES:
        new_code = re.sub(pattern, replacement, migrated)
        if new_code != migrated:
            changes.append({
                "category": "Android",
                "description": description,
                "source": "rule_engine",
                "confidence": 100,
            })
            migrated = new_code

    return migrated, changes


def compute_confidence(rule_changes: list, ai_changes: list) -> int:
    """
    Overall confidence score 0–100.
    Higher when more changes come from deterministic rules.
    """
    total = len(rule_changes) + len(ai_changes)
    if total == 0:
        return 90  # No changes needed = likely already up to date
    rule_weight = len(rule_changes) / total
    return int(70 + rule_weight * 30)   # Range: 70–100