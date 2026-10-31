import datetime
import json
import os
import queue
import shutil
import subprocess
import threading
import time


def get_limits():
    codex = shutil.which("codex")
    if not codex:
        return {}
    command = [codex, "app-server"]
    if os.name == "nt" and codex.lower().endswith((".cmd", ".bat")):
        command = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", codex, "app-server"]
    p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)
    lines = queue.Queue()
    def read_output():
        for line in p.stdout:
            lines.put(line)
    threading.Thread(target=read_output, daemon=True).start()
    try:
        for request in [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"clientInfo": {"name": "herdr-usage", "version": "1.0"}, "capabilities": {}}},
            {"jsonrpc": "2.0", "method": "initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"},
        ]:
            p.stdin.write(json.dumps(request) + "\n")
        p.stdin.flush()
        deadline = time.monotonic() + 8
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return {}
            try:
                line = lines.get(timeout=remaining)
            except queue.Empty:
                return {}
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if message.get("id") == 2:
                return message.get("result", {}).get("rateLimits", {})
    finally:
        p.terminate()
        try:
            p.wait(timeout=1)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait()


def main():
    limits = get_limits()
    parts = []
    now = time.time()
    for key in ("primary", "secondary"):
        window = limits.get(key) or {}
        used, reset = window.get("usedPercent"), window.get("resetsAt")
        if used is None or reset is None:
            return
        if key == "primary":
            when = datetime.datetime.fromtimestamp(reset).strftime("%H:%M")
        else:
            seconds = max(0, reset - now)
            days, hours = int(seconds // 86400), int(seconds % 86400 // 3600)
            when = (str(days) + "d " if days else "") + str(hours) + "h"
        parts.append(str(round(100 - used)) + "% " + when)
    print(" · ".join(parts))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
