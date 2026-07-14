# Flutter Migrator 🚀

AI-powered tool to automate the migration of legacy Flutter and Dart codebases to modern versions (Dart 3.x+).

## 🌟 Features

- **Hybrid Migration Engine**: Combines a deterministic rule engine with Google Gemini 3.5 Flash AI.
- **Null Safety Enforcement**: Automatically identifies and applies Sound Null Safety (adds `?`, `required`, and `late`).
- **Multi-file Support**: Upload ZIP projects or GitHub URLs to migrate entire repositories.
- **Interactive Results**: Side-by-side diff viewer and detailed change summaries.
- **Smart Dependency Analysis**: Scans `pubspec.yaml` and suggests the latest compatible package versions from pub.dev.

## 🛠️ Architecture

- **Frontend**: Flutter Web (Provider for state management).
- **Backend**: FastAPI (Python), SQLite (SQLAlchemy), and Google GenAI SDK.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK
- Python 3.10+
- Google Gemini API Key

### Setup Backend
1. Navigate to `backend/`.
2. Create a virtual environment: `python -m venv venv`.
3. Activate it: `.\venv\Scripts\activate` (Windows).
4. Install dependencies: `pip install -r requirements.txt`.
5. Create a `.env` file with your `GEMINI_API_KEY`.
6. Run the server: `uvicorn main:app --reload`.

### Setup Frontend
1. Navigate to `frontend/`.
2. Get packages: `flutter pub get`.
3. Run for web: `flutter run -d chrome --web-port 3001`.

## 📄 License
This project is licensed under the MIT License.
