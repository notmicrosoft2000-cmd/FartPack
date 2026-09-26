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


def token():
    # The creds file is JSON: {"username": ..., "password": ..., "info": ...}
    with open(CREDS) as f:
        creds = json.load(f)
    st, body = call("/api/v2/auth/login",
                    {"username": creds["username"], "password": creds["password"]},
                    method="POST")
    if st != 200:
        sys.exit("crafty login failed: HTTP %s" % st)
    # token lives under "data", not at the top level
    return json.loads(body)["data"]["token"]


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
    # /api/v2/servers/status -> {"status":..,"data":[{running, online, max, ..}]}
    st, body = call("/api/v2/servers/status", tok=token())
    try:
        rows = json.loads(body)["data"]
        for r in rows:
            if r.get("id") == SID:
                log("running=%s online=%s/%s" % (r.get("running"), r.get("online"), r.get("max")))
                return r
        log("server %s not in status list (%d servers)" % (SID, len(rows)))
    except Exception as e:
        log("status parse failed: %s" % e)
    return None


def is_running(tok):
    st, body = call("/api/v2/servers/status", tok=tok)
    try:
        rows = json.loads(body)["data"]
        r = next((x for x in rows if x.get("id") == SID), None)
        return r.get("running") if r else None
    except Exception:
        return None


def restart(wait_s=240):
    """Crafty's real endpoints are /api/v2/servers/<id>/action/<verb>_server.

    Getting this wrong is silent and nasty: an unknown path returns
    404 API_HANDLER_NOT_FOUND, the server never bounces, but a naive
    "did it come back?" poll still answers yes because it was never down.
    So every step below asserts on the actual observed state.
    """
    tok = token()
    before = is_running(tok)
    log("before: running=%s" % before)
    if before is None:
        sys.exit("cannot read server status; refusing to restart blind")

    st, body = call("/api/v2/servers/%s/action/restart_server" % SID, {}, tok=tok, method="POST")
    log("restart_server -> HTTP %s %s" % (st, body[:160]))
    if st != 200:
        sys.exit("Crafty refused the restart (HTTP %s). Server left alone." % st)

    # Phase 1: it must actually go down at some point, or nothing happened.
    went_down = False
    for _ in range(60):
        time.sleep(2)
        if is_running(tok) is False:
            went_down = True
            log("observed stopped")
            break
    if not went_down:
        log("FAILED: never observed the server stop. The 200 above was not a restart.")
        return False

    # Phase 2: wait for it to come back.
    for i in range(wait_s // 2):
        time.sleep(2)
        if is_running(tok) is True:
            log("running again after ~%ds" % ((i + 1) * 2))
            return True
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
