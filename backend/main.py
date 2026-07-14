import os
import sys
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Add current directory to path so 'app' can be found
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import engine, Base, create_tables
from app.routers import migrations
from app.services.ai_service import test_ai_connection


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create all tables on startup
    create_tables()
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Flutter Migration Assistant API",
    description="AI-powered Flutter code migration tool",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(migrations.router)


@app.get("/health", tags=["health"])
def health():
    return {
        "status": "ok",
        "message": "Flutter Migration Assistant is running",
        "version": "1.0.0",
    }


@app.get("/test-ai", tags=["health"])
async def test_ai():
    working = await test_ai_connection()
    if working:
        return {"status": "ok", "message": "Gemini API is working correctly"}
    else:
        return {"status": "error", "message": "Gemini API is NOT working. Check logs."}
