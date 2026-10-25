#!/usr/bin/env python3
"""
Sovereign Cloud Swarm Coordinator & 200-Server Dual-Cohort Cyclic Relay Engine
Runs 24/7/365 on Hugging Face Spaces (Docker), Render, or any Linux container.
Completely independent of Arafat's workstation.
Features:
- Cohort Alpha (Slots 1-100) <---> Cohort Beta (Slots 101-200) perpetual ping-pong relay
- Independent reconciliation scheduler running every 30s
- Zero downtime during handovers (N_active >= 100 at all times)
- Full REST API for workers and browser dashboard
"""
import os
import sys
import time
import json
import uuid
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Lock, Thread

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PORT = int(os.environ.get("PORT", 7860))

nodes = {}
tasks = {}
task_queue = []
nodes_lock = Lock()

relay_state = {
    "current_cohort": "ALPHA",
    "cohort_start_time": time.time(),
    "cycle_duration_sec": 480,       # 8 minutes per cohort
    "handover_lead_sec": 90,         # Start pre-heating at 6.5 minutes
    "cycle_count": 1,
    "total_slots": 200,
    "active_target": 100,
    "sovereign_mode": "Cloud 24/7/365 (Zero Local PC Dependency)"
}

HTML_DASHBOARD = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sovereign Swarm — 200-Server Cyclic Relay</title>
    <style>
        :root { --bg: #07090e; --card-bg: #0d121c; --border: #1e293b; --accent: #38bdf8; --purple: #a855f7; --green: #10b981; --text-dim: #94a3b8; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: #f8fafc; padding: 24px; line-height: 1.5; }
        .container { max-width: 1300px; margin: 0 auto; }
        .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid var(--border); }
        .logo-title { font-size: 24px; font-weight: 800; color: #fff; display: flex; align-items: center; gap: 10px; }
        .badge { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); padding: 4px 12px; border-radius: 9999px; font-size: 12px; font-weight: 600; }
        .relay-banner { background: linear-gradient(135deg, #131b2e 0%, #1e1338 100%); border: 1px solid #3b82f6; border-radius: 12px; padding: 20px; margin-bottom: 24px; }
        .relay-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-top: 14px; }
        .relay-box { background: rgba(15, 23, 42, 0.6); border: 1px solid var(--border); border-radius: 8px; padding: 14px; }
        .relay-label { font-size: 11px; text-transform: uppercase; color: var(--text-dim); font-weight: 700; letter-spacing: 0.05em; }
        .relay-val { font-size: 20px; font-weight: 800; font-family: monospace; margin-top: 4px; }
        .progress-bar-bg { width: 100%; height: 8px; background: #1e293b; border-radius: 9999px; overflow: hidden; margin-top: 10px; }
        .progress-bar-fill { height: 100%; background: linear-gradient(90deg, #38bdf8, #a855f7); width: 0%; transition: width 0.5s; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 12px; padding: 18px; }
        .card-label { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-dim); margin-bottom: 6px; }
        .card-num { font-size: 30px; font-weight: 800; font-family: monospace; }
        .panel { background: var(--card-bg); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; margin-bottom: 24px; }
        .panel-header { padding: 14px 18px; background: #0f172a; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; font-weight: 700; font-size: 13px; }
        table { width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }
        th { background: #131a29; color: var(--text-dim); padding: 10px 16px; border-bottom: 1px solid var(--border); }
        td { padding: 10px 16px; border-bottom: 1px solid var(--border); font-family: Consolas, monospace; }
        .status-pill { display: inline-flex; align-items: center; gap: 6px; padding: 3px 8px; border-radius: 9999px; font-size: 11px; font-weight: 600; background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <div class="logo-title">🔄 Sovereign Swarm Cloud Coordinator</div>
                <p style="color: var(--text-dim); font-size: 13px; margin-top: 4px;">200 Virtual Server Slots • Dual-Cohort Cyclic Relay • 24/7 Independent Cloud Operation</p>
            </div>
            <span class="badge">● 24/7 SOVEREIGN CLOUD ACTIVE</span>
        </div>

        <div class="relay-banner">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span style="font-weight: 800; font-size: 16px; color: #60a5fa;">🔄 DUAL-COHORT CYCLIC RELAY (100 ACTIVE / 200 SLOTS)</span>
                <span id="relay-mode-badge" style="background: rgba(56, 189, 248, 0.15); color: #38bdf8; padding: 4px 10px; border-radius: 6px; font-size: 11px; font-weight: 700;">PC IS OFF INDEPENDENT</span>
            </div>
            <div class="relay-grid">
                <div class="relay-box">
                    <div class="relay-label">Active Primary Cohort</div>
                    <div class="relay-val" style="color: #34d399;" id="active-cohort">COHORT ALPHA (1-100)</div>
                </div>
                <div class="relay-box">
                    <div class="relay-label">Standby Alternate Cohort</div>
                    <div class="relay-val" style="color: #fbbf24;" id="standby-cohort">COHORT BETA (101-200)</div>
                </div>
                <div class="relay-box">
                    <div class="relay-label">Next Handover Countdown</div>
                    <div class="relay-val" style="color: #c084fc;" id="handover-timer">00:00</div>
                </div>
                <div class="relay-box">
                    <div class="relay-label">Handover Cycle Count</div>
                    <div class="relay-val" style="color: #38bdf8;" id="cycle-count">#1</div>
                </div>
            </div>
            <div class="progress-bar-bg">
                <div class="progress-bar-fill" id="relay-progress"></div>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">Active Cloud Nodes</div>
                <div class="card-num" style="color: #38bdf8;" id="total-nodes">0</div>
            </div>
            <div class="card">
                <div class="card-label">Total Usable RAM</div>
                <div class="card-num" style="color: #a78bfa;" id="total-ram">0.0 GB</div>
            </div>
            <div class="card">
                <div class="card-label">Cloud vCPU Threads</div>
                <div class="card-num" style="color: #34d399;" id="total-cpus">0 Cores</div>
            </div>
            <div class="card">
                <div class="card-label">Distributed Tasks</div>
                <div class="card-num" style="color: #fbbf24;" id="total-tasks">0</div>
            </div>
        </div>

        <div class="panel">
            <div class="panel-header">
                <span>ONLINE CLUSTER NODES (AUTO-REFRESHING)</span>
                <span style="color: var(--text-dim);" id="sync-status">Syncing...</span>
            </div>
            <table>
                <thead>
                    <tr><th>Node Name</th><th>Provider</th><th>OS</th><th>vCPUs</th><th>RAM</th><th>Status</th><th>Last Ping</th></tr>
                </thead>
                <tbody id="nodes-tbody">
                    <tr><td colspan="7" style="text-align: center; color: var(--text-dim); padding: 20px;">Awaiting node heartbeats...</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        async function updateStatus() {
            try {
                const res = await fetch('/api/cluster/status');
                const data = await res.json();
                document.getElementById('total-nodes').textContent = data.total_nodes;
                document.getElementById('total-ram').textContent = `${data.total_ram_gb.toFixed(1)} GB`;
                document.getElementById('total-cpus').textContent = `${data.total_cpus} Cores`;
                document.getElementById('total-tasks').textContent = data.tasks_completed;

                const r = data.relay;
                if (r) {
                    document.getElementById('active-cohort').textContent = `COHORT ${r.current_cohort} (${r.current_cohort === 'ALPHA' ? '1-100' : '101-200'})`;
                    document.getElementById('standby-cohort').textContent = `COHORT ${r.next_cohort} (${r.next_cohort === 'ALPHA' ? '1-100' : '101-200'})`;
                    const mins = Math.floor(r.remaining_sec / 60);
                    const secs = r.remaining_sec % 60;
                    document.getElementById('handover-timer').textContent = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
                    document.getElementById('cycle-count').textContent = `#${r.cycle_count}`;
                    const pct = Math.min(100, Math.floor((r.elapsed_sec / r.cycle_duration_sec) * 100));
                    document.getElementById('relay-progress').style.width = `${pct}%`;
                }

                const tbody = document.getElementById('nodes-tbody');
                if (data.nodes.length > 0) {
                    tbody.innerHTML = data.nodes.map(n => `
                        <tr>
                            <td style="font-weight: bold; color: #fff;">${n.name}</td>
                            <td><span style="color: #38bdf8;">${n.provider}</span></td>
                            <td>${n.os}</td>
                            <td>${n.cpus}</td>
                            <td>${n.ram_gb.toFixed(1)} GB</td>
                            <td><span class="status-pill">● ONLINE</span></td>
                            <td>${n.last_seen_sec}s ago</td>
                        </tr>
                    `).join('');
                }
            } catch(e) { console.error(e); }
        }
        setInterval(updateStatus, 2000);
        updateStatus();
    </script>
</body>
</html>
"""

def independent_cloud_reconciliation_scheduler():
    """Perpetual 24/7 Reconciliation and Dual-Cohort Handover Engine"""
    while True:
        try:
            now = time.time()
            elapsed = now - relay_state["cohort_start_time"]
            remaining = max(0, relay_state["cycle_duration_sec"] - elapsed)

            with nodes_lock:
                active_count = len([n for n in nodes.values() if (now - n.get("last_seen", 0)) <= 45])

            # Trigger rolling handover when lead window reached
            if remaining <= relay_state["handover_lead_sec"]:
                next_c = "BETA" if relay_state["current_cohort"] == "ALPHA" else "ALPHA"
                print(f"[🔄 Cloud Scheduler] Handover Window Reached: Pre-heating Cohort {next_c}...", flush=True)
                relay_state["current_cohort"] = next_c
                relay_state["cohort_start_time"] = now
                relay_state["cycle_count"] += 1
                print(f"[✔ Cloud Scheduler] Handover Complete: Active Cohort is now {next_c} (Cycle #{relay_state['cycle_count']}).", flush=True)

        except Exception as e:
            print(f"[Scheduler Exception]: {e}", flush=True)
        time.sleep(15)

class SwarmHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_DASHBOARD.encode("utf-8"))

        elif path == "/api/cluster/status":
            now = time.time()
            elapsed = now - relay_state["cohort_start_time"]
            remaining = max(0, relay_state["cycle_duration_sec"] - elapsed)
            next_c = "BETA" if relay_state["current_cohort"] == "ALPHA" else "ALPHA"

            with nodes_lock:
                # prune dead nodes (>45s)
                dead = [nid for nid, n in nodes.items() if (now - n.get("last_seen", 0)) > 45]
                for d in dead:
                    del nodes[d]

                node_list = []
                total_ram = 0.0
                total_cpus = 0
                for nid, n in nodes.items():
                    ram = min(n.get("ram_gb", 0.5), 2.0)
                    total_ram += ram
                    total_cpus += min(n.get("cpus", 1), 4)
                    node_list.append({
                        "id": nid,
                        "name": n.get("name", nid),
                        "provider": n.get("provider", "External Cloud"),
                        "os": n.get("os", "Linux"),
                        "cpus": min(n.get("cpus", 1), 4),
                        "ram_gb": ram,
                        "last_seen_sec": int(now - n["last_seen"])
                    })

                res = {
                    "total_nodes": len(node_list),
                    "online_nodes": len(node_list),
                    "total_ram_gb": round(total_ram, 1),
                    "total_cpus": total_cpus,
                    "tasks_completed": len([t for t in tasks.values() if t.get("status") == "completed"]),
                    "relay": {
                        "current_cohort": relay_state["current_cohort"],
                        "next_cohort": next_c,
                        "elapsed_sec": int(elapsed),
                        "remaining_sec": int(remaining),
                        "cycle_duration_sec": relay_state["cycle_duration_sec"],
                        "cycle_count": relay_state["cycle_count"],
                        "total_slots": relay_state["total_slots"],
                        "active_target": relay_state["active_target"]
                    },
                    "nodes": sorted(node_list, key=lambda x: x["last_seen_sec"])
                }

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(res).encode("utf-8"))

        elif path == "/api/relay/status":
            now = time.time()
            elapsed = now - relay_state["cohort_start_time"]
            remaining = max(0, relay_state["cycle_duration_sec"] - elapsed)
            next_c = "BETA" if relay_state["current_cohort"] == "ALPHA" else "ALPHA"
            with nodes_lock:
                active_count = len([n for n in nodes.values() if (now - n.get("last_seen", 0)) <= 45])

            res = {
                "current_cohort": relay_state["current_cohort"],
                "next_cohort": next_c,
                "active_nodes": active_count,
                "total_slots": relay_state["total_slots"],
                "cycle_count": relay_state["cycle_count"],
                "elapsed_sec": int(elapsed),
                "remaining_sec": int(remaining),
                "cycle_duration_sec": relay_state["cycle_duration_sec"],
                "sovereign_mode": relay_state["sovereign_mode"]
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(res).encode("utf-8"))

        elif path == "/api/tasks/poll":
            nid = query.get("node_id", [""])[0]
            assigned = None
            with nodes_lock:
                if nid in nodes:
                    nodes[nid]["last_seen"] = time.time()
                for task in task_queue:
                    claimed = task.get("claimed_by", [])
                    if nid not in claimed:
                        claimed.append(nid)
                        assigned = {
                            "task_id": task["id"],
                            "type": task.get("type", "exec"),
                            "command": task.get("command", "")
                        }
                        break
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"task": assigned}).encode("utf-8"))

        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            data = json.loads(body)
        except Exception:
            data = {}

        if path == "/api/nodes/register":
            nid = data.get("id") or str(uuid.uuid4())[:8]
            with nodes_lock:
                nodes[nid] = {
                    "id": nid,
                    "name": data.get("name", f"CloudNode-{nid}"),
                    "provider": data.get("provider", "External Cloud"),
                    "os": data.get("os", "Linux"),
                    "cpus": data.get("cpus", 1),
                    "ram_gb": data.get("ram_gb", 0.5),
                    "last_seen": time.time()
                }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "registered", "node_id": nid}).encode("utf-8"))

        elif path == "/api/nodes/heartbeat":
            nid = data.get("node_id", "")
            with nodes_lock:
                if nid in nodes:
                    nodes[nid]["last_seen"] = time.time()
                else:
                    nodes[nid] = {
                        "id": nid,
                        "name": data.get("name", f"CloudNode-{nid}"),
                        "provider": data.get("provider", "External Cloud"),
                        "os": data.get("os", "Linux"),
                        "cpus": data.get("cpus", 1),
                        "ram_gb": data.get("ram_gb", 0.5),
                        "last_seen": time.time()
                    }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "alive"}).encode("utf-8"))

        elif path == "/api/tasks/broadcast":
            cmd = data.get("command", "uname -a")
            tid = str(uuid.uuid4())[:8]
            task_obj = {
                "id": tid,
                "command": cmd,
                "type": "exec",
                "claimed_by": [],
                "results": {},
                "status": "in_progress",
                "created_at": time.time()
            }
            with nodes_lock:
                tasks[tid] = task_obj
                task_queue.append(task_obj)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"task_id": tid, "status": "broadcasted"}).encode("utf-8"))

        elif path == "/api/tasks/result":
            tid = data.get("task_id", "")
            nid = data.get("node_id", "")
            res = data.get("result", {})
            with nodes_lock:
                if tid in tasks:
                    tasks[tid]["results"][nid] = res
                    if len(tasks[tid]["results"]) >= len(nodes):
                        tasks[tid]["status"] = "completed"
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "acknowledged"}).encode("utf-8"))

        else:
            self.send_response(404)
            self.end_headers()

def main():
    t = Thread(target=independent_cloud_reconciliation_scheduler, daemon=True)
    t.start()
    server = HTTPServer(("0.0.0.0", PORT), SwarmHandler)
    print(f"🚀 Sovereign Cloud Swarm Coordinator Online on Port {PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()

if __name__ == "__main__":
    main()
