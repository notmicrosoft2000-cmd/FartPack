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
s.settimeout(25)


def pk(i, t, p):
    pl = struct.pack("<ii", i, t) + p.encode() + b"\x00\x00"
    return struct.pack("<i", len(pl)) + pl


def _pkt():
    """Read one packet -> (id, type, body)."""
    h = s.recv(4)
    if len(h) < 4:
        return None, None, None
    ln = struct.unpack("<i", h)[0]
    b = b""
    while len(b) < ln:
        c = s.recv(ln - len(b))
        if not c:
            break
        b += c
    if len(b) < 8:
        return None, None, None
    i, t = struct.unpack("<ii", b[:8])
    return i, t, (b[8:ln - 2].decode(errors="replace") if ln > 10 else "")


# Auth is a single reply packet. Read exactly one, or the next command's packets
# get consumed as if they belonged to it.
s.sendall(pk(19, 3, pw))
_id, _t, _b = _pkt()
if _id != 19:
    sys.exit("AUTH FAILED")

n = 1


def run(cmd):
    """Send a command and collect its whole reply.

    Long replies are split across several packets, so reading only one silently
    truncates output -- `scoreboard objectives list` then looks like entries are
    missing when they are not. The reply ends either at a type-2 packet with an
    empty body or when the socket goes quiet, so accept both conventions.
    """
    global n
    n += 1
    s.sendall(pk(n, 2, cmd))
    parts = []
    s.settimeout(1.5)
    try:
        while True:
            i, t, b = _pkt()
            if i is None:
                break
            if t == 2 and not b:
                break                      # explicit terminator
            parts.append(b)
            if t == 2:
                break                      # final value packet
    except socket.timeout:
        pass
    finally:
        s.settimeout(25)
    return "".join(parts).strip()


for c in sys.argv[1:]:
    print("> %s" % c)
    out = run(c)
    for line in out.splitlines():
        if line.strip() and not line.startswith("----"):
            print("   " + line)
    time.sleep(0.3)

try:
    s.sendall(pk(999, 0, ""))
    s.close()
except Exception:
    pass
