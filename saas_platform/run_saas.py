#!/usr/bin/env python3
"""
One-Click Launcher for AR ContentForge AI SaaS Platform
Starts the FastAPI cloud backend and automatically opens the zero-install web interface.
"""
import os
import sys
import time
import webbrowser
import threading
import uvicorn

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(CURRENT_DIR, "backend"))

def open_browser():
    time.sleep(1.2)
    url = "http://localhost:7860"
    print(f"[*] Opening zero-install web app in browser: {url}")
    webbrowser.open(url)

def main():
    print("=" * 65)
    print("⚡ AR ContentForge AI — Zero-Install Cloud SaaS Platform")
    print("=" * 65)
    print("[*] Local URL:    http://localhost:7860")
    print("[*] Network URL:  http://0.0.0.0:7860")
    print("[*] API Docs:     http://localhost:7860/docs")
    print("[*] Multi-Tenant: Enabled (SQLite WAL)")
    print("[*] Architecture: FastAPI + Uvicorn + Async Scraping + AI Engine")
    print("=" * 65)

    threading.Thread(target=open_browser, daemon=True).start()

    from app import app
    uvicorn.run(app, host="0.0.0.0", port=7860, log_level="info")

if __name__ == "__main__":
    main()
