#!/usr/bin/env python3
"""probe-booklen.py - send ONE function line to the server, on a fresh connection,
and report exactly what came back. Reads the line from a file so that quoting a
2 kB NBT literal through a shell is not part of the experiment.

Why this exists: the v31 lint could not check the profile/book give line. It lost
the RCON connection on that line twice, which is deterministic and therefore a
property of the LINE, not of the network. The two candidate explanations are very
different and must not be confused:

  A. the line is too long for the RCON transport  -> fix by splitting the book
  B. the line is long enough to parse but the NBT is malformed and the command
     throws in a way that kills the connection    -> fix by fixing the NBT

A and B need opposite changes, and "the lint failed" distinguishes neither. So this
prints the raw response, plus a length-vs-known-good comparison, and deliberately
does NOT decide on its own - a probe that concludes is a probe that can be wrong.

Usage: probe-booklen.py <file> <line-number> [<compare-file> <compare-line>]
"""
import os
import socket
import struct
import subprocess
import sys

SID = "241920ac-55ce-46c6-aa2f-c42ebf290457"


def password():
    path = os.path.expanduser("~/crafty/servers/%s/server.properties" % SID)
    with open(path) as fh:
        for line in fh:
            if line.startswith("rcon.password="):
                return line.split("=", 1)[1].rstrip("\n")
    raise SystemExit("no rcon.password in server.properties")


def host():
    return subprocess.check_output(
        ["docker", "inspect", "-f",
         "{{range $k, $v := .NetworkSettings.Networks}}{{if $v.IPAddress}}{{$v.IPAddress}}{{end}}{{end}}",
         "crafty"]).decode().strip()


def pk(i, t, p):
    body = struct.pack("<ii", i, t) + p.encode() + b"\x00\x00"
    return struct.pack("<i", len(body)) + body


def session():
    s = socket.create_connection((host(), 25575), timeout=5)
    s.settimeout(15)
    s.sendall(pk(19, 3, password()))
    hdr = s.recv(4)
    ln = struct.unpack("<i", hdr)[0]
    buf = b""
    while len(buf) < ln:
        buf += s.recv(ln - len(buf))
    if struct.unpack("<i", buf[:4])[0] != 19:
        raise SystemExit("AUTH FAILED")
    return s


def ask(cmd):
    """One command, one connection, full raw response. Never reconnects - the
    point is to see what a single attempt does, retries would hide it.

    Returns (state, body) where state is one of three things, and the three are
    kept apart because conflating them is how this probe first lied:
      ANSWERED  - the server replied with text
      SILENT     - the server replied with an empty body (accepted, said nothing)
      LOST       - the socket died before a response header arrived
    An earlier version returned the empty case wrapped in the same << >> markers as
    the lost case, and the verdict tested startswith("<<"), so a SUCCESSFUL command
    was reported as a dropped connection. The known-good 846-char book line was
    declared "TRANSPORT LOST" by a probe that had been handed a success.
    """
    s = session()
    try:
        s.sendall(pk(7, 2, cmd))
        hdr = s.recv(4)
        if len(hdr) < 4:
            return "LOST", "connection closed before any response header"
        ln = struct.unpack("<i", hdr)[0]
        buf = b""
        while len(buf) < ln:
            chunk = s.recv(ln - len(buf))
            if not chunk:
                break
            buf += chunk
        if len(buf) < 8:
            return "LOST", "short packet: %r" % buf
        body = buf[8:ln - 2].decode(errors="replace") if ln > 10 else ""
        body = body.strip()
        return ("ANSWERED" if body else "SILENT"), (body or "accepted, no output")
    except OSError as e:
        return "LOST", "transport error: %s: %s" % (type(e).__name__, e)
    finally:
        try:
            s.close()
        except OSError:
            pass


def line_at(path, num):
    with open(path, encoding="utf8") as fh:
        for i, line in enumerate(fh, 1):
            if i == num:
                return line.rstrip("\n")
    raise SystemExit("no line %d in %s" % (num, path))


def report(label, cmd):
    print("  %s" % label)
    print("    length      : %d chars" % len(cmd))
    state, resp = ask(cmd)
    print("    state       : %s" % state)
    print("    response    : %s" % resp.replace("\n", "\n                 "))
    return state, resp


if __name__ == "__main__":
    # THE CONTROL COMES FIRST. If this does not come back ANSWERED then the probe
    # itself is broken and every result below it is meaningless - an empty reply
    # and a dead socket look identical from the outside, which is the entire
    # reason the state is now reported separately.
    print("=== control: a command that MUST return text ===")
    ctl, _ = report("scoreboard players get #loaded fart.var",
                    "scoreboard players get #loaded fart.var")
    if ctl != "ANSWERED":
        raise SystemExit("CONTROL FAILED (%s) - the probe is broken, stopping here"
                         % ctl)
    print("    (control answered, so the transport is healthy and the rest is real)")

    print()
    print("=== the line under test ===")
    report("profile/book.mcfunction give", line_at(sys.argv[1], int(sys.argv[2])))

    if len(sys.argv) > 4:
        print()
        print("=== the known-good line it is being compared against ===")
        report("book/give.mcfunction give (shipped and verified in v30)",
               line_at(sys.argv[3], int(sys.argv[4])))

    print()
    print("LOST on the long line and SILENT/ANSWERED on the short one means the")
    print("LENGTH is the trigger. A parser error message on the long line means the")
    print("NBT is wrong and the length is innocent.")
