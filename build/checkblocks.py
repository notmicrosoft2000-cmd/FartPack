#!/usr/bin/env python3
"""checkblocks.py <file-with-block-ids>

Asks the LIVE server whether each block id actually exists, by running
`execute if block ~ ~ ~ <id>` and looking for an error in the RCON reply.

This matters because a single unknown value in a tags/block/*.json makes the
whole tag file fail to parse -- #fartpack:utility would silently vanish and
every utility block in the world would stop farting, with nothing in the log
to tell you why.

Usage:
  ssh nept@server 'python3 /tmp/checkblocks.py /tmp/ids.txt'
  (one id per line, `minecraft:` prefix optional)
"""
import sys, socket, struct, os, subprocess, time

SID = "241920ac-55ce-46c6-aa2f-c42ebf290457"
pw = [l.split("=", 1)[1].rstrip("\n")
      for l in open(os.path.expanduser("~/crafty/servers/%s/server.properties" % SID))
      if l.startswith("rcon.password=")][0]
host = subprocess.check_output(
    ["docker", "inspect", "-f",
     "{{range $k,$v := .NetworkSettings.Networks}}{{if $v.IPAddress}}{{$v.IPAddress}}{{end}}{{end}}",
     "crafty"]).decode().strip()

s = socket.create_connection((host, 25575), timeout=5)
s.settimeout(30)


def pk(i, t, p):
    pl = struct.pack("<ii", i, t) + p.encode() + b"\x00\x00"
    return struct.pack("<i", len(pl)) + pl


def rd():
    h = s.recv(4)
    if len(h) < 4:
        return None, None
    ln = struct.unpack("<i", h)[0]
    b = b""
    while len(b) < ln:
        c = s.recv(ln - len(b))
        if not c:
            break
        b += c
    if len(b) < 8:
        return None, None
    i, t = struct.unpack("<ii", b[:8])
    return i, (b[8:ln - 2].decode(errors="replace") if ln > 10 else "")


s.sendall(pk(19, 3, pw))
if rd()[0] != 19:
    sys.exit("AUTH FAILED")
_n = [1]


def run(cmd):
    _n[0] += 1
    s.sendall(pk(_n[0], 2, cmd))
    time.sleep(0.12)
    return (rd()[1] or "").strip()


ids = []
for line in open(sys.argv[1]):
    line = line.split("#", 1)[0].strip()
    if not line:
        continue
    ids.append(line if ":" in line else "minecraft:" + line)

bad = []
for bid in ids:
    out = run("execute if block ~ ~ ~ %s" % bid)
    low = out.lower()
    if "unknown" in low or "incorrect" in low or "not a valid" in low or "error" in low:
        bad.append((bid, out.replace("\n", " ")[:120]))
        print("BAD   %s" % bid)
    else:
        print("ok    %s" % bid)

print()
print("checked %d, bad %d" % (len(ids), len(bad)))
for bid, msg in bad:
    print("  %s -> %s" % (bid, msg))
s.sendall(pk(999, 0, ""))
s.close()
