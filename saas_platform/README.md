# ⚡ AR ContentForge AI — Zero-Install Cloud SaaS Platform

A multi-tenant Software as a Service (SaaS) web application. Zero software or package installation is required on the user's local machine—the app runs entirely in the cloud and is accessible via any web browser or programmatic REST API.

---

## 🌟 Key Features
- **🌐 Zero-Install Web Experience**: Users access the platform through a modern, responsive web application (Tailwind CSS, Glassmorphic dark UI, Markdown viewer).
- **🕷️ Async Live Web Extractor**: Real-time HTTP scraping and content sanitization for any public webpage or article.
- **⚡ 4 Specialized AI Tool Suites**:
  1. **Web Article & URL Analyzer**: Strategic summaries, 5 non-obvious insights, and action items.
  2. **Viral Social Copywriter**: 5-tweet high-conversion X thread and LinkedIn thought leadership post.
  3. **Video Script Architect**: 60-second YouTube Shorts/TikTok hook, retention loop, and CTA with visual cue directions.
  4. **Code & Architecture Explainer**: System diagrams (Mermaid), complexity analysis, and refactoring diffs.
- **💰 Metered Monetization & Credit Ledger**:
  - Each new user automatically receives **50 free trial credits**.
  - Every generation deducts **5 credits**.
  - Credit exhaustion returns `HTTP 402 Payment Required`.
  - Built-in Top-up simulation (Starter $5/100 credits, Pro $15/500 credits, or Web3 Base L2 USDC).
- **🔑 Developer B2B API**:
  - Programmatic access with bearer keys (`X-API-Key`).
  - Supports automated server-to-server integration.

---

## 🚀 Quickstart (Local Launch)
1. Run the one-click launcher:
```bash
python run_saas.py
```
2. The web application will automatically open in your default browser at `http://localhost:7860`.
3. View interactive OpenAPI documentation at `http://localhost:7860/docs`.

---

## 🐳 Docker & Cloud Deployment (Render / Railway / Fly.io)
Deploy in one command using Docker:
```bash
docker build -t ar-contentforge-saas .
docker run -p 7860:7860 ar-contentforge-saas
```

---

## 📂 Project Structure
```
ar-contentforge-saas/
├── backend/
│   └── app.py            # FastAPI cloud backend, SQLite database, scraping & AI engine
├── frontend/
│   └── index.html        # Glassmorphic zero-install web client (Tailwind + Marked.js)
├── Dockerfile            # Container definition for cloud hosting
├── requirements.txt      # Production Python dependencies
├── run_saas.py           # One-click startup script
├── saas.db               # Multi-tenant SQLite database (WAL mode)
└── README.md             # Architecture & deployment documentation
```
