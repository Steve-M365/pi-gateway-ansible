#!/usr/bin/env python3
from flask import Flask, jsonify
import subprocess

app = Flask(__name__)

def run(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return r.stdout.strip(), r.returncode
    except Exception as e:
        return str(e), 1

@app.route("/api/status")
def api_status():
    cpu, _ = run("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem, _ = run("free -m | awk 'NR==2{printf "%.1f", $3*100/$2}'")
    disk, _ = run("df -h / | awk 'NR==2{print $5}' | sed 's/%//'")
    uptime, _ = run("uptime -p")
    containers, _ = run("docker ps --format '{{.Names}}\t{{.Status}}'")
    ts, _ = run("tailscale status")
    routes, _ = run("ip route show")
    return jsonify({
        "cpu": cpu,
        "memory": mem,
        "disk": disk,
        "uptime": uptime.replace("up ", "") if uptime else "unknown",
        "containers": containers,
        "tailscale": ts,
        "routes": routes
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
