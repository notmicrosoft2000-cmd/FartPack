#!/usr/bin/env python3
"""Restart the FartPack Minecraft server via the Crafty API.

Why the API and not RCON `stop`: Crafty owns the process, and the homelab
watchdog.py also drives Crafty. Going through the API keeps a single owner of
the lifecycle instead of racing the watchdog.

Also patches server.properties (resource-pack + resource-pack-sha1) in the same
run, because a resource-pack-sha1 change only takes effect on restart.

Credentials are read from the creds file and never printed.

Usage:
  python3 craftyrestart.py patch <rp_url> <sha1>   # edit properties, no restart
  python3 craftyrestart.py restart                  # restart only
  python3 craftyrestart.py status
"""
import glob
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request

SID = "241920ac-55ce-46c6-aa2f-c42ebf290457"
SRV = os.path.expanduser("~/crafty/servers/%s" % SID)
PROPS = os.path.join(SRV, "server.properties")
CREDS = os.path.expanduser("~/crafty/config/default-creds.txt")
BASE = "https://localhost:8443"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def log(m):
    print(time.strftime("%H:%M:%S ") + m, flush=True)


def call(path, data=None, tok=None, method="GET"):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(BASE + path, data=body, method=method)
    req.add_header("Content-Type", "application/json")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
            return r.status, r.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")
    except Exception as e:
        return 0, str(e)


def creds():
    user = pw = None
    for line in open(CREDS):
        line = line.strip()
        if line.lower().startswith("username:"):
            user = line.split(":", 1)[1].strip()
        elif line.lower().startswith("password:"):
            pw = line.split(":", 1)[1].strip()
    return user, pw


def token():
    u, p = creds()
    st, body = call("/api/v2/auth/login", {"username": u, "password": p}, method="POST")
    if st != 200:
        sys.exit("crafty login failed: HTTP %s" % st)
    return json.loads(body)["token"]


def escape(v):
    """java .properties escaping for a value: the existing file uses \\: and \\="""
    return v.replace(":", "\\:").replace("=", "\\=")


def patch(url, sha1):
    with open(PROPS) as f:
        lines = f.read().splitlines()
    out, seen_url, seen_sha = [], False, False
    for ln in lines:
        if ln.startswith("resource-pack="):
            out.append("resource-pack=" + escape(url))
            seen_url = True
        elif ln.startswith("resource-pack-sha1="):
            out.append("resource-pack-sha1=" + sha1)
            seen_sha = True
        else:
            out.append(ln)
    if not seen_url:
        out.append("resource-pack=" + escape(url))
    if not seen_sha:
        out.append("resource-pack-sha1=" + sha1)

    bak = PROPS + ".bak-before-rp19"
    if not os.path.exists(bak):
        with open(PROPS) as f:
            open(bak, "w").write(f.read())
        log("backed up server.properties -> %s" % os.path.basename(bak))
    tmp = PROPS + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(out) + "\n")
    os.replace(tmp, PROPS)
    log("patched resource-pack + resource-pack-sha1")

    with open(PROPS) as f:
        chk = f.read()
    m = re.search(r"^resource-pack=(.*)$", chk, re.M)
    got = m.group(1).replace("\\:", ":").replace("\\=", "=")
    m2 = re.search(r"^resource-pack-sha1=(.*)$", chk, re.M)
    log("verify url  ok=%s" % (got == url))
    log("verify sha1 ok=%s" % (m2 and m2.group(1).strip() == sha1))
    if got != url or not (m2 and m2.group(1).strip() == sha1):
        sys.exit("patch verification FAILED")


def status():
    st, body = call("/api/v2/servers/%s" % SID, tok=token())
    try:
        d = json.loads(body)
        run = d.get("data", {}).get("run_status", "?")
        state = d.get("data", {}).get("state", {})
        log("run_status=%s online_players=%s max_players=%s" %
            (run, state.get("online_players"), state.get("max_players")))
    except Exception:
        log("raw: %s" % body[:200])


def restart(wait_s=180):
    tok = token()
    st, body = call("/api/v2/commands/%s" % SID, {"command": "stop"}, tok=tok, method="POST")
    log("stop  -> HTTP %s %s" % (st, body[:120]))
    for _ in range(60):
        time.sleep(3)
        st, body = call("/api/v2/servers/%s" % SID, tok=tok)
        try:
            if json.loads(body)["data"]["run_status"] == "stopped":
                break
        except Exception:
            pass
    log("server stopped")
    time.sleep(4)
    st, body = call("/api/v2/servers/%s/start" % SID, tok=tok, method="POST")
    log("start -> HTTP %s %s" % (st, body[:120]))
    for i in range(wait_s // 3):
        time.sleep(3)
        st, body = call("/api/v2/servers/%s" % SID, tok=tok)
        try:
            d = json.loads(body)["data"]
            if d.get("run_status") == "running":
                log("running again after ~%ds" % (i * 3 + 3))
                return True
        except Exception:
            pass
    log("TIMED OUT waiting for the server to come back")
    return False


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "status"
    if what == "patch":
        patch(sys.argv[2], sys.argv[3])
    elif what == "restart":
        status()
        restart()
        time.sleep(5)
        status()
    else:
        status()
