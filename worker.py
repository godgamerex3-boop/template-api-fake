#!/usr/bin/env python3
"""
Antigravity Universal Swarm Worker Agent v3.0 (Anti-Idle Culler Protected)
Zero dependencies (Pure Python 3 standard library).
Runs on any Linux (Debian, Ubuntu, Alpine), FreeBSD, macOS, or container.
Connects outbound via HTTP/HTTPS to the Swarm Hub.
Includes automated anti-idle culler pulse to prevent Jupyter/Kubernetes container timeouts.
"""
import os
import sys
import time
import json
import uuid
import platform
import subprocess
import argparse
import threading
import random
import urllib.request
import urllib.error

def get_system_specs():
    specs = {
        "os": f"{platform.system()} {platform.release()}",
        "cpus": os.cpu_count() or 1,
        "ram_gb": 1.0
    }
    cgroup_found = False
    try:
        if os.path.exists("/sys/fs/cgroup/memory.max"):
            with open("/sys/fs/cgroup/memory.max", "r") as f:
                val = f.read().strip()
                if val != "max" and val.isdigit():
                    specs["ram_gb"] = round(int(val) / (1024 * 1024 * 1024), 2)
                    cgroup_found = True
        elif os.path.exists("/sys/fs/cgroup/memory/memory.limit_in_bytes"):
            with open("/sys/fs/cgroup/memory/memory.limit_in_bytes", "r") as f:
                val_str = f.read().strip()
                if val_str.isdigit():
                    val = int(val_str)
                    if val < (1024**4):
                        specs["ram_gb"] = round(val / (1024 * 1024 * 1024), 2)
                        cgroup_found = True
    except Exception:
        pass

    if not cgroup_found:
        try:
            if os.path.exists("/proc/meminfo"):
                with open("/proc/meminfo", "r") as f:
                    for line in f:
                        if line.startswith("MemTotal:"):
                            kb = int(line.split()[1])
                            specs["ram_gb"] = round(kb / (1024 * 1024), 2)
                            break
        except Exception:
            pass
    return specs

def post_json(url, data, timeout=10):
    payload = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json", "User-Agent": "AntigravitySwarmWorker/3.0"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))

def get_json(url, timeout=10):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "AntigravitySwarmWorker/3.0"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))

def check_buddies(hub_url, node_id, ring, pending, now=None):
    """Claim only hub-reported stale peers; never infer failure from HTTP errors.

    Claims are coordination records for the supervisor, not provisioning commands.
    Cache lease expiry to avoid repeat claims/logs during each heartbeat.
    """
    now = time.time() if now is None else now
    stale_ids = {peer["node_id"] for peer in ring.get("peers", []) if peer.get("suspect")}
    for target in list(pending):
        if target not in stale_ids or pending[target] <= now:
            del pending[target]
    for target in sorted(stale_ids):
        if target in pending:
            continue
        reply = post_json(f"{hub_url}/api/ring/claim",
                          {"node_id": node_id, "target_node_id": target}, timeout=5)
        lease = reply.get("lease", {})
        if reply.get("status") in ("claimed", "leased"):
            pending[target] = lease.get("expires_at", now + 15)
            if reply["status"] == "claimed":
                print(f"[{node_id}] recovery claimed: {target} lease={lease.get('lease_id')} "
                      f"epoch={lease.get('epoch')} (awaiting supervisor)", flush=True)


def start_anti_culling_keepalive():
    def pulse():
        while True:
            try:
                # Reset Jupyter server idle culler by touching file and pinging local server
                for p in ["/home/jovyan/.keepalive", "/tmp/.swarm_keepalive"]:
                    try:
                        with open(p, "w") as f:
                            f.write(str(time.time()))
                    except Exception:
                        pass
                try:
                    urllib.request.urlopen("http://127.0.0.1:8888/api/status", timeout=2)
                except Exception:
                    pass
            except Exception:
                pass
            time.sleep(30)
    t = threading.Thread(target=pulse, daemon=True)
    t.start()


def buddy_tick(hub_url, reg_data):
    """Report liveness and claim stale assignments; provisioning belongs to supervisor."""
    reply = post_json(f"{hub_url}/api/nodes/heartbeat", reg_data, timeout=5)
    assignment = reply.get("assignment", {})
    peers = ([assignment["primary"]] if assignment.get("primary") else []) + assignment.get("backups", [])
    outcomes = []
    for peer in peers:
        if not peer.get("stale"):
            continue
        result = post_json(f"{hub_url}/api/ring/claim",
                           {"node_id": reg_data["node_id"], "target_node_id": peer["node_id"],
                            "epoch": assignment.get("epoch")}, timeout=5)
        outcomes.append(result)
        if result.get("status") == "claimed":
            lease = result["lease"]
            print(f"[{reg_data['name']}] recovery requested: {peer['node_id']} "
                  f"lease={lease['lease_id']} epoch={lease['epoch']}", flush=True)
    return outcomes


def run_worker_instance(hub_url, node_name, provider, specs, instance_num=1, total_instances=1):
    node_id = str(uuid.uuid4())[:8]
    ram_alloc = round(specs["ram_gb"] / total_instances, 2) if total_instances > 1 else specs["ram_gb"]
    
    print(f"[{node_name}] Initializing... (Assigned RAM: {ram_alloc} GB, vCPUs: {specs['cpus']})", flush=True)

    reg_data = {
        "node_id": node_id,
        "name": node_name,
        "provider": provider,
        "os": specs["os"],
        "cpus": specs["cpus"],
        "ram_gb": ram_alloc
    }

    registered = False
    for attempt in range(10):
        try:
            res = post_json(f"{hub_url}/api/nodes/register", reg_data)
            if res.get("status") == "registered":
                registered = True
                print(f"[{node_name}] Registered with Hub as {node_id}!", flush=True)
                break
        except Exception as e:
            time.sleep(2)

    if not registered:
        return

    # Separate liveness from task execution; phase offsets stagger steady-state traffic.
    def buddy_loop():
        pending = {}
        time.sleep(random.uniform(0, 15))
        while True:
            try:
                buddy_tick(hub_url, reg_data)
            except Exception:
                # Coordinator failure is not evidence of peer failure.
                pass
            time.sleep(random.uniform(13.5, 16.5))

    threading.Thread(target=buddy_loop, daemon=True).start()
    backoff = 3
    time.sleep(random.uniform(0, 5))
    while True:
        try:
            poll_res = get_json(f"{hub_url}/api/tasks/poll?node_id={node_id}", timeout=5)
            task = poll_res.get("task")
            if task:
                task_id = task["task_id"]
                command = task["command"]
                start_t = time.time()
                try:
                    proc = subprocess.Popen(
                        command,
                        shell=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        text=True
                    )
                    stdout, stderr = proc.communicate(timeout=task.get("timeout", 60))
                    exit_code = proc.returncode
                except subprocess.TimeoutExpired:
                    proc.kill()
                    stdout, stderr = "", "Task timed out."
                    exit_code = -1
                except Exception as e:
                    stdout, stderr = "", f"Task error: {str(e)}"
                    exit_code = -2

                exec_time = round(time.time() - start_t, 3)
                submit_data = {
                    "task_id": task_id,
                    "node_id": node_id,
                    "result": {
                        "node_name": node_name,
                        "provider": provider,
                        "exit_code": exit_code,
                        "stdout": stdout,
                        "stderr": stderr,
                        "duration_sec": exec_time
                    }
                }
                try:
                    post_json(f"{hub_url}/api/tasks/submit", submit_data, timeout=10)
                except Exception:
                    pass

            backoff = 3
            time.sleep(random.uniform(4, 6))
        except Exception:
            time.sleep(random.uniform(backoff, backoff * 1.5))
            backoff = min(60, backoff * 2)

def main():
    parser = argparse.ArgumentParser(description="Antigravity Swarm Universal Worker Agent v3.0")
    parser.add_argument("--hub", required=True, help="URL of the Swarm Hub coordinator")
    parser.add_argument("--name", default="CloudNode", help="Name prefix for this worker")
    parser.add_argument("--provider", default="External Cloud", help="Name of cloud provider")
    parser.add_argument("--instances", type=int, default=1, help="Number of worker instances to launch on this host")
    args = parser.parse_args()

    hub_url = args.hub.rstrip("/")
    specs = get_system_specs()
    num_instances = max(1, args.instances)

    # Launch anti-idle culler pulse immediately
    # Respect provider session limits; no synthetic anti-culling pulse.

    threads = []
    for i in range(num_instances):
        inst_name = f"{args.name}-Node{i+1}" if num_instances > 1 else args.name
        t = threading.Thread(
            target=run_worker_instance,
            args=(hub_url, inst_name, args.provider, specs, i+1, num_instances),
            daemon=True
        )
        t.start()
        threads.append(t)
        time.sleep(0.2)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
