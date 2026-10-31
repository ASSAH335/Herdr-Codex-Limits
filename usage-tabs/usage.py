import json, subprocess, time, datetime, os, selectors

def get_limits():
    p = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
    try:
        for req in [{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"herdr-usage","version":"1.0"},"capabilities":{}}},{"jsonrpc":"2.0","method":"initialized"},{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read"}]:
            p.stdin.write(json.dumps(req)+"\n")
        p.stdin.flush()
        sel=selectors.DefaultSelector(); sel.register(p.stdout, selectors.EVENT_READ)
        end=time.monotonic()+8
        while time.monotonic()<end and sel.select(max(0,end-time.monotonic())):
            line=p.stdout.readline()
            if not line: break
            msg=json.loads(line)
            if msg.get("id")==2: return msg.get("result",{}).get("rateLimits",{})
    finally:
        p.terminate()
        try: p.wait(timeout=1)
        except subprocess.TimeoutExpired: p.kill(); p.wait()
    return {}

def main():
    limits=get_limits(); parts=[]; now=time.time()
    for key in ("primary","secondary"):
        w=limits.get(key) or {}; used=w.get("usedPercent"); reset=w.get("resetsAt")
        if used is None or reset is None: return
        if key=="primary": when=datetime.datetime.fromtimestamp(reset).strftime("%H:%M")
        else:
            seconds=max(0,reset-now); days=int(seconds//86400); hours=int(seconds%86400//3600); when=(str(days)+"d " if days else "")+str(hours)+"h"
        parts.append(str(round(100-used))+"% "+when)
    print(" · ".join(parts))

try: main()
except Exception: pass
