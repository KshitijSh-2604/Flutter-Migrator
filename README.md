# 🚀 Flutter Migrator

**Automated Flutter & Dart modernization powered by Version-Aware Rules and AI.**

[![Live Demo](https://img.shields.io/badge/Live-Demo-brightgreen?style=for-the-badge)](https://kshitijsh-2604.github.io/Flutter-Migrator/)
[![Backend API](https://img.shields.io/badge/Backend-Render-blue?style=for-the-badge)](https://flutter-migrator-backend.onrender.com/health)

Flutter Migrator is a professional-grade hybrid tool designed to transition legacy Flutter applications to modern standards (Dart 3.x+). It combines the speed and 100% accuracy of deterministic regex-based rules with the deep logical reasoning of Google Gemini and OpenAI.

---

## 🌟 Key Features

### 1. 🛠️ Hybrid Migration Engine
- **Deterministic Rules**: Instantly replaces deprecated widgets (e.g., `RaisedButton` → `ElevatedButton`) and typography (e.g., `headline6` → `titleLarge`) with 100% confidence.
- **AI Refactoring**: Uses **Gemini 3.1 Flash Lite** (default) or **GPT-4o** to handle complex logic, Sound Null Safety, and structural API changes.

### 2. 📂 Multi-Source Processing
- **Code Snippet**: Paste a single Dart file for an instant fix.
- **ZIP Upload**: Upload your entire project root. We parse `pubspec.yaml`, `.dart` files, and `build.gradle` automatically.
- **GitHub URL**: Provide a link to any public repository, and the migrator will clone and analyze the whole project.

### 3. 🔐 Secure & Private (BYOK)
- **Bring Your Own Key (BYOK)**: The app uses *your* Gemini or OpenAI API key. This keeps the service free for everyone and ensures your data is processed using your own quota.
- **Cloud-Synced Profile**: API keys and migration history are stored securely in your private **Supabase** profile. Access your history from any device.

### 4. 📊 Interactive Result Viewer
- **Side-by-Side Diff**: Compare your original code with the migrated version.
- **Change Categorization**: See exactly what was changed, categorized by "Widget API", "Typography", "Null Safety", etc.
- **Package Analysis**: Real-time checks against `pub.dev` to identify outdated or breaking dependencies.

---

## 🏗️ Tech Stack

- **Frontend**: Flutter Web (State management via `Provider`)
- **Backend**: FastAPI (Python 3.12)
- **Database**: PostgreSQL (via Supabase Connection Pooling)
- **Authentication**: Supabase Auth
- **AI Integration**: Google GenAI SDK & OpenAI API

---

## 🚀 Deployment

The project is architected for **Hybrid Cloud Deployment**:

1.  **Frontend**: Hosted on **GitHub Pages** for high availability and zero cost.
2.  **Backend**: Hosted on **Render** (Python Web Service).
3.  **Database**: Managed **Supabase** instance.
4.  **Keep-Alive**: Integrated with **cron-job.org** to prevent Render's free tier from sleeping.

---

## 🛠️ Local Development

### Prerequisites
- Flutter SDK (Stable)
- Python 3.10+
- A Supabase Project (Database + Auth)

### Backend Setup
1. `cd backend`
2. `python -m venv venv`
3. `source venv/bin/activate` (or `.\venv\Scripts\activate` on Windows)
4. `pip install -r requirements.txt`
5. Configure `.env` with your `DATABASE_URL`.
6. `uvicorn main:app --reload`

### Frontend Setup
1. `cd frontend`
2. `flutter pub get`
3. Update `lib/core/constants/api_constants.dart` to point to `localhost:8000`.
4. `flutter run -d chrome`

---

## 📄 License
MIT License - Copyright (c) 2024 Kshitij Sharma
