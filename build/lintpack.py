import sys,socket,struct,os,subprocess,time,glob,re
SID="241920ac-55ce-46c6-aa2f-c42ebf290457"
pw=[l.split("=",1)[1].rstrip("\n") for l in open(os.path.expanduser("~/crafty/servers/%s/server.properties"%SID)) if l.startswith("rcon.password=")][0]
host=subprocess.check_output(["docker","inspect","-f","{{range $k, $v := .NetworkSettings.Networks}}{{if $v.IPAddress}}{{$v.IPAddress}}{{end}}{{end}}","crafty"]).decode().strip()
def pk(i,t,p):
    pl=struct.pack("<ii",i,t)+p.encode()+b"\x00\x00"; return struct.pack("<i",len(pl))+pl
def rd():
    h=s.recv(4)
    if len(h)<4: return None,None
    ln=struct.unpack("<i",h)[0]; b=b""
    while len(b)<ln:
        c=s.recv(ln-len(b))
        if not c: break
        b+=c
    if len(b)<8: return None,None
    i,t=struct.unpack("<ii",b[:8])
    return i,(b[8:ln-2].decode(errors="replace") if ln>10 else "")
# CONNECT IN A FUNCTION, so it can be called again. The original opened one socket
# at module scope and drove the whole lint through it - around 1200 commands and
# several minutes on a single connection. Minecraft's RCON handler runs on one
# thread behind a queue and is free to close a long-lived connection, and it does:
# the v31 lint died with BrokenPipeError partway through and took the whole gate
# with it. The gate correctly refused to deploy, but it refused for the wrong
# reason and produced no verdict about the pack at all, which is the least useful
# outcome a pre-deploy gate has.
def connect():
    global s
    s=socket.create_connection((host,25575),timeout=5); s.settimeout(30)
    s.sendall(pk(19,3,pw))
    if rd()[0]!=19: sys.exit("AUTH FAILED")
connect()

ROOT=sys.argv[1]
# HOW A LINE IS JUDGED TO HAVE FAILED - and this list used to be the whole
# mechanism, which is how v28 installed a file the server refuses to load while
# the lint printed PARSE FAILURES: 0.
#
# The first version matched seven literal error strings. The line that broke the
# v28 deploy, `damage @s -1 minecraft:generic`, fails with
#
#   Float must not be less than 0.0: found -1.0 at position 90: ...damage @s <--[HERE]
#
# which contains none of them, so it counted as a PASS. The pack installed, the
# server logged "Failed to load function fartpack:player/press", and every
# crouch-fart in the pack silently stopped healing. A gate built from an
# allow-list of known failures passes anything new by default - it is a gate that
# gets weaker exactly when the codebase does something it has not done before,
# which is the only time a lint is worth running.
#
# So the caret is now the mechanism, not the list. Every command-parser error the
# server emits ends in `<--[HERE]`, whatever the message says, so that one
# substring covers the whole parser family. The strings below are for the errors
# that never reach the parser - a macro with no variables, a function file that
# cannot be read - and for the specific parser messages worth naming in the
# report.
#
# WHAT WAS TRIED AND REMOVED, because the broadening had a cost: an intermediate
# version added "Invalid", "Too many", "Out of range", "is not allowed",
# "Malformed" and "not a valid" on the theory that a wider net catches more. It
# reported 3 false positives on a clean build - all of them bossbar macro
# instantiations, whose text contains "Out of range". Every one of those six is
# generic enough to appear in a message that is not a parse error, and the caret
# already catches real ones. A lint that cries wolf is a lint that gets disabled.
# `Expected literal` is the one addition kept, because it was observed on a real
# error this pack hit: `{Health:[probe:heal 2]}` in a `data merge` is rejected
# with "Expected literal (...)" and there is no caret in the part that is useful.
PARSE_ERR=("Unknown or incomplete","Incorrect argument for command","Expected","No variables in macro",
           "Can't parse function line","Expected whitespace","Unknown registry key",
           "Expected literal")
# The general shape. Checked with `in`, not a regex, so there is nothing to get
# wrong about escaping.
CARET="<--[HERE]"
# Runtime messages that mean "the command was understood, it just had no target".
# These are NORMAL for a lint that executes every line over RCON with no player
# online - `damage @s -1` and `damage @s 0` differ only in this respect, which is
# precisely why the first version's list could not tell a parse error from a
# missing chicken.
BENIGN=("No entity was found","No player was found","No players were found",
        "Nothing was selected","No block was found","No objective was found",
        "Test failed","already exists by that name","Summoned new")
n=0
# Returned by run() when a line could not be checked even after a reconnect. It
# is a prefix rather than a value so the main loop can tell "the server said
# nothing" from "we never got to ask" - and those are opposites for a gate.
UNK="LINT_UNCHECKED_RCON_LOST"
# THE MEASURED RCON COMMAND LENGTH LIMIT, and the reason it is a constant rather
# than something worked out inline.
#
# This server silently drops the connection on any command longer than roughly
# 1450 characters. Measured, not guessed: build/probe-threshold.py binary-searches
# the boundary with real `give` commands padded with real pages, and the samples
# were 1433 chars SILENT (accepted) and 1455 chars LOST, with the control command
# answering on every call. The exact number is not round, which is consistent with
# an RCON buffer somewhere in the stack rather than a documented protocol limit.
#
# WHY IT MATTERS ENOUGH TO ENCODE. The v31 lint hit this on the profile/book give
# line, a 2149-character book, and reported it as a parse failure with the
# connection dying twice - which reads as "the pack is broken" when the truth is
# "the gate could not carry the line". A gate that blames the code for its own
# transport limit sends the next person to rewrite a book that was fine.
#
# SO: an over-long line FAILS, loudly, with a message that says what to do about
# it. It is deliberately not a skip - a skip is how a line ends up never examined
# while the report still reads clean, which is the entire failure this file exists
# to prevent. Failing closed costs an author one edit; passing silently costs a
# version.
#
# The v30 spawn book is 846 characters and is comfortably inside this. Keep new
# lines inside it, and if something genuinely cannot be short enough, it needs a
# load-time or runtime check of its own, not a hopeful lint.
RCON_MAX=1400
def run(c):
    global n; n+=1
    for attempt in (1,2):
        try:
            s.sendall(pk(n,2,c)); time.sleep(0.06)
            r=rd()
            if r[0] is None: raise OSError("empty response, server closed the connection")
            return (r[1] or "").strip()
        except OSError as e:
            # BrokenPipeError, ConnectionResetError and socket.timeout are all
            # OSError subclasses, so this catches the whole family including ones
            # that do not exist on this platform yet.
            #
            # A retry re-executes a line that may already have run, which is
            # acceptable HERE and only here: the lint's job is to ask the parser
            # whether a line is well formed, and the lines it replays are scoreboard
            # writes and tag operations whose repeat is a no-op or a duplicate that
            # the next line overwrites. It would not be acceptable in a gate with
            # side effects, and the comment is here so nobody copies the pattern.
            if attempt==2: return "%s (%s)" % (UNK, e)
            sys.stderr.write("  [lint] rcon dropped on line %d (%s); reconnecting\n" % (n, e))
            try: s.close()
            except OSError: pass
            connect()

fails=[]; checked=0; skipped=0
census={}
# BOSS BAR IS A DECLARED BLIND SPOT, and the skip has to be transitive.
#
# The lint never executes a line containing "bossbar" - it mutates real state and
# the pack's boss bars are verified by hand. That was enough until v28, when the
# same blind spot was reached a second way: a line like
#
#   function fartpack:admin/set_max with storage fartpack:data macro
#
# contains no "bossbar", so it was executed, and the macro INSTANTIATION ran the
# bossbar line inside it and failed. The lint then reported a parse failure in a
# file with no parse error in it. Widening the error list made this worse before
# it made it better: it produced 3 false positives on a build that was clean.
#
# So the skip is now computed from the tree rather than from the line: find every
# function that contains a bossbar command, and skip any line that CALLS one. A
# macro is the only way one command reaches another's internals, so this covers
# the indirect route. The count of transitively-skipped lines is printed, because
# a skip that is not counted is a skip nobody can audit.
_boss=set()
_files=sorted(glob.glob(ROOT+"/**/*.mcfunction", recursive=True))
# The id a command uses is `namespace:path` - `fartpack:admin/set_max` - but the
# file on disk is `data/fartpack/function/admin/set_max.mcfunction`. The first
# version of this compared the file path against the command id, matched nothing,
# skipped nothing, and still reported the 3 false positives. A skip list that
# never matches is indistinguishable from no skip list, which is how this went
# unnoticed on the run where I thought I had fixed it.
_ID=re.compile(r"^data/([^/]+)/function/(.+)$")
for _p in _files:
    for _l in open(_p,encoding="utf8").read().split("\n"):
        if "bossbar" not in _l: continue
        m=_ID.match(os.path.relpath(_p,ROOT)[:-len(".mcfunction")])
        if m: _boss.add("%s:%s" % (m.group(1), m.group(2)))
# A function id in a command is `namespace:path` - `fartpack:admin/set_max` - and
# the COLON IS THE POINT. The first version of this pattern was
# `[a-z0-9_.-]+/[a-z0-9_./-]+`, with no colon, which therefore cannot match a
# single function id in this pack: it matched 0 of 84. The skip list looked
# correct, the set it was tested against looked correct, and the three false
# positives came straight back - and the first run reported them as "still 3",
# which reads like the fix had partially worked rather than like the fix had
# never once fired. Verified against the real tree before being committed this
# time: 84 ids matched, 12 of the 13 bossbar-bearing functions reached.
#
# The 13th is `fartpack:tick`, which is invoked by the engine rather than by a
# `function` line, so it needs no entry and gets none.
_CALL=re.compile(r"\bfunction\s+([a-z0-9_.-]+:[a-z0-9_./-]+)")
for path in _files:
    for i,line in enumerate(open(path,encoding="utf8").read().split("\n"),1):
        raw=line.strip()
        if not raw or raw.startswith("#"): continue
        # macro lines: substitute the macro var so the line becomes concrete
        #
        # This used to substitute only $(pid). The v26 admin/* functions take
        # $(arg0)/$(arg1) instead, so their lines were sent to the server with
        # the raw `$(arg0)` in place. That happens to parse - `$(arg0)` is a
        # legal scoreboard holder name - which is precisely why the arity bug in
        # admin/cap went unseen: the line had the right *shape* and the wrong
        # field count, and a literal token did not reveal it. Substituting every
        # macro var with a single benign token tests the real arity instead.
        #
        # Honest limitation: `1` is a plausible player name AND a plausible
        # number, so it cannot catch a line that is only correct for one kind of
        # value. The static check in build/checkcmds.py covers arity without a
        # server, and deploy.sh aborts on the load-time "Failed to load
        # function" errors. Three layers, because one was not enough - see #30.
        cmd = re.sub(r"\$\([^)]*\)", "1", raw.lstrip("$")).strip()
        # skip state-mutating bossbar lines (we verify those by hand)
        if "bossbar" in cmd:
            skipped+=1; continue
        # ...and anything that would run one indirectly, by calling a function
        # that has one inside it. See the note where _boss is built.
        _c=_CALL.search(cmd)
        if _c and _c.group(1) in _boss:
            skipped+=1; continue
        # Over-long lines are rejected BEFORE being sent, so this is a verdict
        # about the line rather than an observation of the transport failing.
        if len(cmd)>RCON_MAX:
            fails.append((os.path.relpath(path,ROOT), i, raw,
                          "LINE IS %d CHARS, OVER THE MEASURED %d-CHAR RCON LIMIT - "
                          "NOT CHECKED AND NOT PARSED. Shorten it; the gate cannot "
                          "carry it and will not pretend otherwise."
                          % (len(cmd), RCON_MAX)))
            continue
        checked+=1
        out=run(cmd)
        # AN UNCHECKABLE LINE IS A FAILURE, not a pass and not a skip. Silently
        # dropping it would restore the exact failure this file exists to prevent:
        # a line that was never examined reported as clean. The lint would go on to
        # print PARSE FAILURES: 0 over a build it had only partly looked at, and
        # that sentence is trusted.
        if out.startswith(UNK):
            fails.append((os.path.relpath(path,ROOT), i, raw,
                          "RCON lost twice - THIS LINE WAS NOT CHECKED, not passed"))
            continue
        bad = any(e in out for e in PARSE_ERR) or CARET in out
        if bad:
            fails.append((os.path.relpath(path,ROOT), i, raw, out))
        else:
            # Census of what was ACCEPTED. The point is to surface a response
            # shape nobody expected, so it counts by SHAPE and not by literal
            # text: "Set [fart.var] for #dx to 0" and "Set [fart.var] for #dz to 0"
            # are one shape, not two.
            #
            # This is not a cosmetic choice. Counting literally produced 125
            # distinct entries, 120-odd of them `Set [fart.var] for #<name> to
            # <n>`, and the reader has to scroll past all of them to find the one
            # unfamiliar string the census exists to reveal. A 125-line dump is
            # the same as no dump: the signal is buried in the noise it created.
            # Collapsed by shape it is about a dozen lines, and the first real
            # example of each is kept alongside the count so a collapsed entry is
            # still traceable to a real response rather than to a regex's idea of
            # one.
            if out and not any(b in out for b in BENIGN):
                # ORDER IS LOAD-BEARING, and so is each pattern's output. All
                # three collisions below were real, and each is a way for the
                # census to under-count and hide the thing it exists to expose.
                #
                #   identifiers before numbers - collapsing digits first turns
                #     the scoreboard holder `#neg1` into `#neg#`, and the name
                #     pattern then stops at the `#` it just made, yielding the
                #     nonsense shape `#N#`.
                #   a `-` inside the number, not outside it - otherwise
                #     "Set [...] for #N to -1" and "to 0" are two shapes for the
                #     same event, and roughly half the real sign-bearing
                #     responses are uncollapsed.
                #   the function marker carries NO leading `#` - as `#FN` it was
                #     then swallowed by the `#name` pattern and became `#N`,
                #     which is the same shape as a scoreboard holder. Two
                #     unrelated response kinds reporting as one is worse than
                #     not reporting: the count looks plausible and means nothing.
                shape=re.sub(r"[a-z0-9_.-]+:[a-z0-9_./-]+","FNID",out)
                shape=re.sub(r"#[A-Za-z0-9_.-]+","#N",shape)
                shape=re.sub(r"-?[0-9]+(\.[0-9]+)?[dfb]?","#",shape)
                shape=re.sub(r"\s+"," ",shape).strip()
                n,ex=census.get(shape,(0,out))
                census[shape]=(n+1,ex)
try: s.sendall(pk(999,0,"")); s.close()
except OSError: pass
print("lines parse-checked: %d   (skipped %d bossbar lines, direct or via a macro call)"
      % (checked, skipped))
print("bossbar-bearing functions found: %s" % (", ".join(sorted(_boss)) or "none"))
print("PARSE FAILURES: %d\n" % len(fails))
_unc=sum(1 for f in fails if f[3].startswith("RCON lost"))
if _unc:
    print("  of which %d were NOT CHECKED (rcon lost), not parser verdicts.\n" % _unc)
for p,i,raw,out in fails:
    msg=" | ".join(l.strip() for l in out.splitlines() if l.strip() and not l.startswith("----"))
    print("%s:%d\n   %s\n   -> %s\n" % (p,i,raw,msg[:220]))

print("RESPONSE CENSUS - every response SHAPE the lint accepted, not matched by any")
print("error pattern above, counted with names and numbers collapsed. A new error")
print("class can only hide as a shape not in this list, so an unfamiliar line here")
print("is the signal to extend PARSE_ERR. Shapes are not vetted: several of these")
print("are uninteresting success confirmations, and the list is left unfiltered on")
print("purpose - every filter added here is a chance to filter out the thing that")
print("matters, which is the failure this census was written to fix.")
if not census:
    print("  (none - every accepted line returned nothing or a known benign message)")
for shape,(n,ex) in sorted(census.items(), key=lambda kv:-kv[1][0]):
    print("  %4dx  %-62s e.g. %s" % (n, shape[:62], ex[:70]))
print()

# A gate that reports a failure and then exits 0 is a printout, not a gate.
# deployauto.sh runs `bash /tmp/lint.sh` and branches on $?, so the parse result
# has to reach the exit status. This is the third thing that let #30 reach the
# live server: the lint was reading a stale tarball, AND its result was not
# wired to the exit code, AND deploy.sh carried on after printing "count: 2".
sys.exit(1 if fails else 0)
