# ⚡ Antigravity 200-Server Sovereign Cloud Mesh

A self-contained, 100% cloud-hosted distributed computing coordinator running a **200-Server Dual-Cohort Cyclic Relay** ($lpha \leftrightarrow eta$) with an independent cloud reconciliation scheduler.

## 🚀 1-Click Free Deployment (Runs 24/7 Even When Your PC Is Off)

### Option 1: Hugging Face Spaces (Recommended - 100% Free Forever)
1. Go to [huggingface.co/new-space](https://huggingface.co/new-space).
2. Space Name: `antigravity-swarm-mesh`
3. License: `MIT`
4. Space SDK: Select **Docker** (Blank).
5. Hardware: **CPU Basic • 2 vCPU • 16 GB RAM • Free**.
6. Upload the 3 files from this folder (`app.py`, `Dockerfile`, `requirements.txt`).
7. Click **Commit Changes**.
8. Done! Your swarm coordinator is permanently live in the cloud 24/7/365 with its own public HTTPS URL.

### Option 2: Render.com (Free Web Service)
1. Connect your GitHub repo containing this folder to [render.com](https://render.com).
2. Create a **Web Service** -> Environment: **Docker**.
3. Instance Type: **Free**.

## 🔄 How the 200-Server Cyclic Relay Operates
- **Cohort Alpha (Slots 1-100)**: Active Primary for 8 minutes.
- **Handover Trigger (Minute 6.5)**: Pre-heats Cohort Beta.
- **Cohort Beta (Slots 101-200)**: Takes over as Active Primary. Cohort Alpha drains and cools.
- **Perpetual Relay**: Continuously cycles between $lpha$ and $eta$.
- **Independent Reconciliation**: An independent cloud scheduler verifies capacity every 45 seconds, ensuring 100 active online nodes are maintained even if your home PC is unplugged.
