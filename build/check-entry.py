#!/usr/bin/env python3
"""
check-entry.py - refuse to journal text that contains a live credential.

Why this exists
---------------
AI-1's journal recorded the box's sudo/ssh password in plaintext, on one line:

    sudo/ssh pw = <the actual password>. Remote shell = FISH ...

It sat in an append-only file that gets copied, archived, grepped and pasted into
chat. When the journals moved into ~/homelab/wiki/ it ended up inside the wiki
tree, one directory from the page whose job is to say which files hold
credentials. It took four sites to scrub, because the redaction tool and its own
check disagreed about which files existed.

This is the cheap upstream gate: a journal entry is prose about work, and prose
about work has no business containing a password. Catch it at the moment of
appending, when it is one line to fix.

What it checks
--------------
1. Any credential-looking assignment: a label (pass/password/pw/pwd/sudo/ssh/
   secret/token/credential) followed by : or = and a value of 4+ chars.
   `[REDACTED]` and `<secret>` style placeholders are allowed.
2. Any value taken from a known secret file, matched in assignment context only
   - never as a bare substring, because a 4-character secret matches every date
   in the journal and a detector that cries wolf 23 times is one that gets
   ignored. See wiki page 05, trap 21.

Usage: check-entry.py <file> [<file> ...]
Exit 0 if clean, 1 if not. Never prints a secret value; locations and labels only.
"""

import os
import pathlib
import re
import sys

H = pathlib.Path.home()

# ------------------------------------------------------------------ import guard
# Importing this file as a module makes CPython write check-entry.cpython-*.pyc
# into wiki/bin/__pycache__/. A per-script `export PYTHONDONTWRITEBYTECODE=1`
# prevents that, but only in the scripts somebody remembered to patch - and the
# two suites I patched were not the only importers, so the directory came back
# from a repair script an hour later.
#
# Setting sys.dont_write_bytecode HERE would be too late: the import machinery
# compiles and writes the .pyc before this body runs. That fix looks right and
# does nothing, which is why it is worth writing down rather than rediscovering.
#
# So the guard is a refusal instead. An importer that forgets gets a clear error
# naming the variable, not a silent cache. Run as a script (python3
# check-entry.py FILE) this never triggers - the cache is only ever written for
# an IMPORTED module, never for __main__.
if __name__ != "__main__" and not os.environ.get("PYTHONDONTWRITEBYTECODE"):
    sys.stderr.write(
        "check-entry.py: refusing to be imported without PYTHONDONTWRITEBYTECODE=1.\n"
        "  Importing this module makes CPython write __pycache__/ into wiki/bin/,\n"
        "  and the cache is written before this code runs, so it cannot be stopped\n"
        "  from in here. Set it in the importing process:\n"
        "      export PYTHONDONTWRITEBYTECODE=1\n"
    )
    raise SystemExit(3)


# ------------------------------------------------------------------ import guard
# Importing this file as a module makes CPython write check-entry.cpython-*.pyc
# into wiki/bin/__pycache__/. A per-script `export PYTHONDONTWRITEBYTECODE=1`
# prevents that, but only in the scripts somebody remembered to patch - and the
# two suites I patched were not the only importers, so the directory came back
# from a repair script an hour later.
#
# Setting sys.dont_write_bytecode HERE would be too late: the import machinery
# compiles and writes the .pyc before this body runs. That fix looks right and
# does nothing, which is why it is worth writing down rather than rediscovering.
#
# So the guard is a refusal instead. An importer that forgets gets a clear error
# naming the variable, not a silent cache. Run as a script (python3
# check-entry.py FILE) this never triggers - the cache is only ever written for
# an IMPORTED module, never for __main__.
if __name__ != "__main__" and not os.environ.get("PYTHONDONTWRITEBYTECODE"):
    sys.stderr.write(
        "check-entry.py: refusing to be imported without PYTHONDONTWRITEBYTECODE=1.\n"
        "  Importing this module makes CPython write __pycache__/ into wiki/bin/,\n"
        "  and the cache is written before this code runs, so it cannot be stopped\n"
        "  from in here. Set it in the importing process:\n"
        "      export PYTHONDONTWRITEBYTECODE=1\n"
    )
    raise SystemExit(3)


# Sources of known-live values. Read from disk, never hardcoded.
SECRET_FILES = {
    "rcon.password": H / "crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/server.properties",
    "management-server-secret": H / "crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/server.properties",
}
WILDCARD_FILES = {
    "discord-webhook": [H / "homelab/.discord_webhook"],
    "sudo-password": [H / "homelab/SERVER-NOTES.txt"],
}

# A label that makes what follows a credential.
#
# The word boundaries are load-bearing, not decoration. Without them `pw` matches
# the tail of `pwr` - and in a Minecraft datapack project `pwr:` is on almost every
# line. That produced three false positives in my own journal on the first run of
# this gate: `pwr:do_power`, `pwr:load`, `pwrcheck=1..`. A detector that flags the
# project's own variable names is a detector that gets switched off.
# The alternation is kept as a plain string with a NON-capturing group, because it
# is embedded in two patterns and only one of them may contribute a group.
#
# An earlier version compiled this with a capturing group and then wrapped it as
# "(" + LABEL.pattern + ")" for ASSIGN, producing:
#   group 1 = the \b(...)\b wrapper
#   group 2 = the label's own inner group
#   group 3 = the actual value
# So `m.group(2)` - which the code treats as the value everywhere - was really the
# LABEL. Every report printed the label's length instead of the value's, and far
# worse, the placeholder exemption was tested against the label. That is why
# `sudo/ssh pw = [REDACTED]` was reported as a live credential: the code asked
# "is the word 'sudo' a placeholder?", got no, and rejected the line.
#
# A nested capture group silently renumbering your groups is the same class of bug
# as a delimiter turning up inside your data. Both stay invisible until the output
# is wrong in a way nobody traces back to the cause. test-entry-gate.sh test G
# asserts ASSIGN.groups == 2 so this cannot come back.
_LABEL_SRC = (r"(?:pass(?:word|wd)?|passwd|pwd|pw|sudo|ssh|secret|token"
              r"|credential|api[_-]?key|webhook)")

# A label that makes what follows a credential.
#
# The word boundaries are load-bearing, not decoration. Without them `pw` matches
# the tail of `pwr` - and in a Minecraft datapack project `pwr:` is on almost every
# line. That produced three false positives in my own journal on the first run of
# this gate. A detector that flags the project's own variable names is a detector
# that gets switched off.
LABEL = re.compile(r"\b" + _LABEL_SRC + r"\b", re.IGNORECASE)

# label, then a separator, then a value. Exactly two groups: 1 = label, 2 = value.
ASSIGN = re.compile(
    r"(\b" + _LABEL_SRC + r"\b)[^:=\n]{0,30}[:=]\s*[\"']?([^\s\"'`]{2,})",
    re.IGNORECASE,
)
PLACEHOLDER = re.compile(
    r"^(\[?redacted\]?|<[^>]+>|\*+|x{4,}|REDACTED|\[secret\]|"
    # Multi-word forms. Note the value pattern stops at the first space, so
    # "secret: not shown" yields the value "not" - the stop-words below have to
    # stand alone to be recognised.
    r"not|not[\w-]*|no|none|yes|true|false|hidden|hide|unset|unknown|absent|"
    r"empty|blank|withheld|omitted|"
    r"not\s+shown|not\s+printed|not\s+logged|not\s+recorded|"
    r"never\s+written|do\s+not\s+log)$",
    re.IGNORECASE,
)
# Trailing sentence punctuation gets swallowed by the value pattern, so
# "[REDACTED]." has to be recognised as the placeholder "[REDACTED]".
TRAILING = ".,;:!?)]}'\""
# ...= in prose, e.g. "pw=<the actual password>" inside a quoted example.
EXAMPLE_CONTEXT = re.compile(r"<the actual|<secret|the password|not the password", re.IGNORECASE)

# Every diagnostic this tool prints starts with MARKER, and the scanner skips any
# line containing it.
#
# Without this the tool flags its own output: the refusal text legitimately talks
# about credentials ("will this entry leak a credential?", "possible credential
# (label sudo, ...)"), and some of those sentences contain a `:` or `=` followed
# by a word, which is exactly the shape being searched for. Two rounds of
# rewording did not fix it, because the problem is structural rather than
# lexical - prose ABOUT credentials will keep tripping a checker FOR credentials.
#
# The marker is safe: if this tool ever echoed a real secret, that echoed line
# would not carry the marker, so it would still be caught.
MARKER = "check-entry:"


def is_placeholder(val, line):
    if PLACEHOLDER.match(val):
        return True
    if PLACEHOLDER.match(val.rstrip(TRAILING)):
        return True
    if EXAMPLE_CONTEXT.search(line):
        return True
    if set(val) <= set("<> []*") or set(val.rstrip(TRAILING)) <= set("<> []*"):
        return True
    # A value of one or two characters is prose, not a credential: "pw: no",
    # "sudo: n/a". The threat model is a real password, not a 2-character one.
    if len(val.rstrip(TRAILING)) < 3:
        return True
    return False


def known_values():
    """label -> value, for every live secret we can read. Never printed.

    A key we cannot find is a FAILURE TO VOUCH, not a pass. An earlier version
    derived the key as `label.split(".")[-1]`, so for "rcon.password" it looked
    for a line starting `password=` - which does not exist in server.properties -
    and silently dropped rcon.password from the list of known values. The tool
    kept reporting success the whole time.

    That is trap 20(a) again, in brand new code, written minutes after writing the
    page about it. Hence the explicit WARN paths here, and the assertion in
    test-entry-gate.sh that every expected label actually shows up.
    """
    out = {}
    for label, path in SECRET_FILES.items():
        if not path.is_file():
            print("  WARN: %s: source %s unreadable - CANNOT VOUCH" % (label, path))
            continue
        found = False
        for line in path.read_text(errors="replace").splitlines():
            # The label IS the key. Do not be clever about it.
            if line.startswith(label + "="):
                found = True
                v = line.split("=", 1)[1].strip()
                if v:
                    out[label] = v
                break
        if not found:
            print("  WARN: %s: key not found in %s - CANNOT VOUCH. A silently "
                  "skipped secret is a secret nobody is checking." % (label, path))
    for label, paths in WILDCARD_FILES.items():
        for path in paths:
            if not path.is_file():
                print("  WARN: %s: source %s unreadable - CANNOT VOUCH" % (label, path))
                continue
            if label == "sudo-password":
                hit = False
                for line in path.read_text(errors="replace").splitlines():
                    if re.match(r"^\s*sudo", line, re.IGNORECASE):
                        m = re.search(r"[:=]\s*(\S+)", line)
                        if m and len(m.group(1)) >= 3:
                            out[label] = m.group(1).strip("\"'")
                            hit = True
                        break
                if not hit:
                    print("  WARN: %s: no sudo line found in %s - CANNOT VOUCH" % (label, path))
            else:
                v = path.read_text(errors="replace").strip()
                if v:
                    out[label] = v
                else:
                    print("  WARN: %s: %s is empty - nothing to check" % (label, path))
    return out


def token_re(secret):
    return re.compile(
        r"(?<![0-9A-Za-z])" + re.escape(secret) + r"(?![0-9A-Za-z])(?!\d{1,2}[-/]\d{1,2})"
    )


def check(path, values):
    bad = []
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError as e:
        return ["%s: cannot read (%s)" % (path, e)]

    for i, line in enumerate(lines, 1):
        if MARKER in line:
            continue  # our own diagnostic, not the author's text
        # 1. credential-looking assignment
        for m in ASSIGN.finditer(line):
            val = m.group(2)
            if is_placeholder(val, line):
                continue
            # The wording matters too, but see MARKER above for the real fix.
            bad.append("%s %s:%d  possible credential (label %s, %d chars, withheld)"
                       % (MARKER, path, i, m.group(1), len(val.rstrip(TRAILING))))

        # 2. a known live value, in assignment context only
        for label, secret in values.items():
            pat = token_re(secret)
            for m in pat.finditer(line):
                window = line[max(0, m.start() - 40):m.start()]
                if not re.search(LABEL.pattern + r"[^:=\n]{0,30}[:=]\s*[\"']?\s*$", window, re.IGNORECASE):
                    continue
                bad.append("%s %s:%d  holds the live %s (%d chars, withheld)"
                           % (MARKER, path, i, label, len(secret)))
    return bad


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__.strip().splitlines()[-1])
    for a in args:
        if not pathlib.Path(a).is_file():
            print("  FAIL: %s does not exist" % a)
            sys.exit(1)

    values = known_values()
    print("  known live values read from disk: %s" % (", ".join(sorted(values)) or "NONE - cannot vouch"))
    for label, v in sorted(values.items()):
        if len(v) < 8:
            print("    note: %s is only %d chars - it cannot be found by substring search,"
                  " so this check uses assignment context only" % (label, len(v)))

    findings = []
    for a in args:
        findings.extend(check(pathlib.Path(a), values))

    print()
    if findings:
        print("  FAIL: %d problem(s) in the entry text:" % len(findings))
        for f in findings:
            print("    %s" % f)
        print()
        print("  Do not append this. Fix the entry first: write which FILE holds the")
        print("  credential, never the value. A journal gets copied, archived, grepped")
        print("  and pasted into chat; a secret does not survive that path.")
        sys.exit(1)
    print("  ok: no credential in the entry text")
    return 0


if __name__ == "__main__":
    sys.exit(main())
