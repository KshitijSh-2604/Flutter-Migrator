"""
AI migration layer.
Uses the NEW Google GenAI SDK (google-genai).
"""

import json
from google import genai
from google.genai import types
from ..config import settings

def _get_client():
    """Helper to ensure client is initialized with the current settings."""
    return genai.Client(api_key=settings.gemini_api_key)

SYSTEM_PROMPT = """
You are an expert Dart/Flutter migration engineer. 
Your task is to take the provided code and migrate it to the TARGET DART VERSION.

CRITICAL OUTPUT RULES:
1. ALWAYS return a valid JSON object.
2. The "migrated_code" must contain the complete, compilation-ready migrated file.
3. The "changes_summary" must NEVER be empty if any changes were made. For every modification (like adding '?', adding 'required', etc.), add an entry.
4. Apply Sound Null Safety (Dart 2.12+) aggressively:
   - All class fields must be nullable (type?) or non-nullable (required in constructor).
   - Factories must handle nulls.
   - Constructors must use 'required' for named parameters that cannot be null.

JSON Schema:
{
  "migrated_code": "full source code",
  "changes_summary": [
    {
      "category": "Null Safety",
      "description": "Added 'required' to constructor parameter 'latitude'",
      "before": "this.latitude",
      "after": "required this.latitude",
      "source": "ai",
      "confidence": 100
    }
  ],
  "pubspec_changes": {
    "add_dependencies": [],
    "remove_dependencies": [],
    "update_dependencies": [],
    "sdk_constraints": {"dart": "^3.0.0", "flutter": "^3.10.0"}
  },
  "migration_steps": ["Run 'dart pub get'"],
  "warnings": []
}
"""

# Comprehensive list of models to try in order of preference
# Gemini 3.5 Flash is set as primary as requested by user
FALLBACK_MODELS = [
    "gemini-3.5-flash",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
    "gemini-flash-latest"
]

async def test_ai_connection():
    """
    Test if the Gemini API key and model are working.
    Tries multiple models to find one that isn't overloaded.
    """
    client = _get_client()
    import sys
    for model_id in FALLBACK_MODELS:
        try:
            # Using a tiny prompt for testing
            response = client.models.generate_content(
                model=model_id,
                contents="test"
            )
            if response and response.text:
                sys.stderr.write(f"AI_TEST_SUCCESS: Model {model_id} is working.\n")
                return True
        except Exception as e:
            sys.stderr.write(f"AI_TEST_INFO: Model {model_id} failed: {str(e)[:100]}...\n")
            continue
    return False

async def migrate_with_ai(
        code: str,
        flutter_version_from: str | None,
        flutter_version_to: str,
        package_analysis: list | None = None,
        dart_sdk: str | None = None,
) -> dict:
    """
    Call Gemini using the new google-genai SDK with multi-model fallback.
    """
    client = _get_client()
    import sys
    
    # Build structured context block
    pkg_block = ""
    if package_analysis:
        outdated = [p for p in package_analysis if p["status"] in ("upgrade", "breaking")]
        if outdated:
            pkg_block = "Outdated packages (needs attention):\n"
            for p in outdated:
                status = "⚠ BREAKING" if p["status"] == "breaking" else "↑ upgrade"
                pkg_block += (
                    f"  - {p['name']}: "
                    f"{p['installed_version']} → {p['latest_version']} {status}\n"
                )

    user_message = f"""
Current Dart version: {flutter_version_from or 'unknown (detect from code)'}
Target Dart version:  {flutter_version_to or 'latest stable'}
Current Dart SDK:        {dart_sdk or 'unknown'}

{pkg_block}

The rule engine has already handled basic renames and removed 'new' keywords. 
Your job is to apply COMPLEX changes required for the TARGET DART VERSION: {flutter_version_to or 'latest stable'}.

CRITICAL: If the target version is 2.12.0 or higher, you MUST apply Sound Null Safety:
1. Identify nullable fields and add '?' to their types.
2. Add 'required' keyword to named parameters in constructors that don't have a default value and are not nullable.
3. Replace 'new List()' with '[]' or 'List.filled()'.
4. Ensure all factory methods handle null data from JSON safely.
5. Use late keyword where appropriate.
6. Fix any other breaking changes from the specified From version to the To version.

If the code is already compliant, just return it as is but ensure all modern patterns are used.

--- CODE TO MIGRATE ---
{code}
--- END CODE ---

Return only the JSON migration result.
"""

    # Try every possible model until one succeeds
    for model_id in FALLBACK_MODELS:
        try:
            response = client.models.generate_content(
                model=model_id,
                contents=SYSTEM_PROMPT + "\n\n" + user_message,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                    safety_settings=[
                        types.SafetySetting(category="HARM_CATEGORY_HATE_SPEECH", threshold="BLOCK_NONE"),
                        types.SafetySetting(category="HARM_CATEGORY_HARASSMENT", threshold="BLOCK_NONE"),
                        types.SafetySetting(category="HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold="BLOCK_NONE"),
                        types.SafetySetting(category="HARM_CATEGORY_DANGEROUS_CONTENT", threshold="BLOCK_NONE"),
                    ]
                )
            )

            if not response or not response.text:
                continue

            text = response.text.strip()
            # Clean up markdown wrappers
            if text.startswith("```"):
                if "json" in text[:10]:
                    text = text.split("json", 1)[1]
                else:
                    text = text.split("```", 1)[1]
                if "```" in text:
                    text = text.rsplit("```", 1)[0]
            text = text.strip()

            result = json.loads(text)
            sys.stderr.write(f"AI_MIGRATION_SUCCESS: Used model {model_id}\n")
            return result

        except Exception as e:
            sys.stderr.write(f"AI_MIGRATION_INFO: Model {model_id} failed: {str(e)[:100]}...\n")
            continue

    raise Exception("All Gemini models (including Flash, Flash-Lite, and 1.5) are currently overloaded or have exceeded your quota. Please try again later or provide a different API key.")
