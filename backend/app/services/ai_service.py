"""
AI migration layer supporting multiple engines (Gemini and OpenAI).
Supports User-provided API keys.
"""

import json
from google import genai
from google.genai import types
from openai import AsyncOpenAI
from ..config import settings

def _process_ai_result(result: dict) -> dict:
    """Ensure all changes in the result have the source set to 'ai'."""
    if not isinstance(result, dict):
        return result
    
    changes = result.get("changes_summary", [])
    if isinstance(changes, list):
        for change in changes:
            if isinstance(change, dict):
                change["source"] = "ai"
                if "confidence" not in change:
                    change["confidence"] = 80
    
    return result

async def migrate_with_ai(
        code: str,
        flutter_version_from: str | None,
        flutter_version_to: str,
        package_analysis: list | None = None,
        dart_sdk: str | None = None,
        user_gemini_key: str | None = None,
        user_openai_key: str | None = None,
) -> dict:
    """
    Tries OpenAI if a key is provided, otherwise falls back to Gemini.
    """
    
    system_prompt = f"""
You are an expert Dart/Flutter migration engineer. 
Migrate the provided code to TARGET DART VERSION: {flutter_version_to}.
Apply Sound Null Safety aggressively if target is 2.12+.
Return ONLY valid JSON.
"""

    user_message = f"""
Original Code:
{code}

Output JSON with keys: "migrated_code", "changes_summary" (list of objects with category, description, before, after), "pubspec_changes", "migration_steps", "warnings".
"""

    # 1. Try OpenAI if key is available
    if user_openai_key:
        try:
            client = AsyncOpenAI(api_key=user_openai_key)
            response = await client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ],
                response_format={"type": "json_object"}
            )
            raw_res = json.loads(response.choices[0].message.content)
            return _process_ai_result(raw_res)
        except Exception as e:
            import sys
            sys.stderr.write(f"OPENAI_ERROR: {str(e)}\n")

    # 2. Try Gemini (User key or System key)
    gemini_key = user_gemini_key or settings.gemini_api_key
    if gemini_key:
        client = genai.Client(api_key=gemini_key)
        # Expanded list of models to find one with available quota
        # gemini-3.1-flash-lite is preferred by the user for higher daily limits
        models_to_try = [
            "gemini-3.1-flash-lite",
            "gemini-3.5-flash",
            "gemini-flash-latest",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "gemini-1.5-flash-8b",
            "gemini-2.0-flash-lite",
            "gemini-1.5-pro",
        ]
        for model_id in models_to_try:
            try:
                response = client.models.generate_content(
                    model=model_id,
                    contents=system_prompt + "\n\n" + user_message,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        temperature=0.1
                    )
                )
                if response and response.text:
                    text = response.text.strip()
                    if text.startswith("```json"): text = text[7:-3]
                    elif text.startswith("```"): text = text[3:-3]
                    raw_res = json.loads(text.strip())
                    return _process_ai_result(raw_res)
            except Exception as e:
                import sys
                sys.stderr.write(f"GEMINI_ERROR ({model_id}): {str(e)}\n")
                continue

    raise Exception("No valid AI configuration found or quota exceeded.")

async def validate_api_key(key: str, provider: str):
    """
    Shallow validation to trust the user. 
    Actual validation happens during migration attempts.
    """
    if not key:
        return False
    
    clean_key = str(key).strip()
    
    if provider == "openai":
        return clean_key.startswith("sk-") and len(clean_key) > 10
    elif provider == "gemini":
        return len(clean_key) > 10
        
    return False

async def test_ai_connection():
    """Test if the system Gemini API key is working."""
    try:
        client = genai.Client(api_key=settings.gemini_api_key)
        # Using 3.1 flash lite as preferred
        response = client.models.generate_content(model="gemini-3.1-flash-lite", contents="hi")
        return True if response and response.text else False
    except:
        return False
