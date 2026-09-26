# Server handoff — read this before touching anything

> **Canonical source is the wiki on the server, not this file.** This is the
> paste-into-your-chat-window onboarding doc. When the two disagree, the wiki
> wins, because it is what lives next to the machine:
>
> - `~/homelab/server-info/00-README.md` — index
> - `~/homelab/server-info/AI-REGISTRY.md` — **check this first: is another AI
>   already on this box, and what do they own?**
> - `~/homelab/server-info/AI-RULES.md` — binding norms
> - `~/homelab/server-info/11-ENVIRONMENT-TRAPS.md` — the traps below, in full
> - `~/homelab/server-info/JOURNAL.md` — latest state
>
> AI-1 is registered as the FartPack AI. Journals are per-AI
> (`~/homelab/AI-<N>-JOURNAL.md`); the shared log is for state changes.

You are working on a private homelab Minecraft server. Everything you need to
connect is below. Read the whole thing once before your first command; most of
the wasted time in this environment comes from the shell and the RCON quoting,
not from Minecraft.

---

## 1. What is here

| | |
|---|---|
| Server | Minecraft **1.21.11**, running under **Crafty** in Docker |
| Host | `nept@192.168.99.56` (LAN only — not reachable from outside) |
| RCON | port **25575**, password in `world/server.properties` as `rcon.password` |
| Server ID | `241920ac-55ce-46c6-aa2f-c42ebf290457` |
| World dir | `~/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/` |
| Datapacks | `~/crafty/servers/<ID>/world/datapacks/` |
| Logs | `~/crafty/servers/<ID>/logs/latest.log` |
| RCON helper | `/tmp/rcon.py` on the server |
| Journals | `~/homelab/AI-JOURNAL.md` and `~/homelab/server-info/JOURNAL.md` |

Installed and **not yours to change**: Fabric mods (`antixray`, `collective`,
`dynamiclights`, `easyauth`, `vanish`, `fabric-convention-tags-v2`,
`server_translations_api`), and the world datapacks **`pwr`**, **`Graves v3.0.0`**,
and **`fartpack`**. FartPack is currently **disabled** — see §6.

---

## 2. Talking to the server

**Via SSH** (for files, logs, the filesystem):

```bash
ssh nept@192.168.99.56
```

**Via RCON** (for game commands) — always through the helper on the server:

```bash
ssh nept@192.168.99.56 'python3 /tmp/rcon.py list'
ssh nept@192.168.99.56 'python3 /tmp/rcon.py "scoreboard players get #x fart.var"'
```

Two rules that will bite you:

- **No leading slash on RCON commands.** `rcon.py list`, not `rcon.py /list`.
- **In bash, the helper must be an array.** `R=(python3 /tmp/rcon.py)` then
  `"${R[@]}" 'cmd'`. Writing `R=$(python3 /tmp/rcon.py)` makes `R` the literal
  *string* `"python3 /tmp/rcon.py"`, and every call then silently does nothing —
  including the ones you use to check whether the server is safe to touch. This
  has already caused a real incident here. Never use the string form quoted.

---

## 3. The remote shell is fish — this is the big one

`ssh host 'command'` runs **fish**, not bash. It will reject things that look
perfectly valid:

| Don't | Why | Do instead |
|---|---|---|
| `VAR=$(cmd)` | fish has no `$( )`; it wants `(cmd)` | `set VAR (cmd)`, or avoid it |
| `cat <<EOF ... EOF` | no heredocs at all | write a file locally, `scp` it, `cat` it |
| `cmd1 & cmd2` | `&` is a syntax error, not "run in background" | one command, or use a script |
| `a && b` in some forms | unreliable | one command per line |

**The rule that makes all of this go away: never pass a multi-line or complex
command inline. Write a bash script locally, `scp` it, then run it.**

```bash
# locally
cat > /tmp/mytest.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
python3 /tmp/rcon.py list
EOF
scp /tmp/mytest.sh nept@192.168.99.56:/tmp/
ssh nept@192.168.99.56 'bash /tmp/mytest.sh'
```

The script runs under `bash` and behaves normally. This is how every script in
this project's `build/` directory is meant to be used.

**Do not edit a script while it is running.** `bash` reads scripts incrementally,
so a file changed mid-run causes it to execute garbage. Write a new file with a
new name instead.

**Tooling on the server:** `python3` is available. **`zip`, `unzip` and `bsdtar`
are not installed** — use `python3 -c "import zipfile; ..."`.

---

## 4. Hard rules

1. **Never print a secret.** The RCON password and the Discord webhook
   (`~/homelab/.discord_webhook`) are secrets. Read them into a variable from the
   file; never echo them, never pass them on a command line where they'd land in
   a log or a `ps` listing.
2. **0 players online before any `reload` or restart.** `reload` disconnects
   everyone. Always *check*, don't assume — and if you cannot read the player
   count, stop and say so rather than proceeding. A previous deploy printed the
   check and reloaded with a player online anyway.
3. **Ask before restarting the server.** It's a shared box; someone may be
   mid-session. `reload` is cheaper than a restart and usually enough.
4. **Never change the `resource-pack` URL or `resource-pack-sha1` casually.**
   `require-resource-pack=true`, so a bad URL or a hash that doesn't match the
   zip **makes the server unjoinable**. If you must change it: build the zip,
   host it, verify the URL downloads and matches byte-for-byte, *then* patch the
   properties, *then* restart, *then* confirm a player can connect.
5. **Back up before you change a datapack or `server.properties`.** One file,
   one timestamped copy, next to the original.
6. **Log what you changed** in `~/homelab/AI-JOURNAL.md` and
   `~/homelab/server-info/JOURNAL.md`. Append by **copying a file in**, never a
   heredoc — markdown is full of backticks and `$`, and a heredoc will mangle it
   or silently append nothing.
7. **A check that prints a failure and then continues is not a check.** If you
   write a verification step, make it exit non-zero and actually branch on it.
   This has also caused a real incident here.

---

## 5. Minecraft gotchas on this box (each one cost real time)

- **An empty server does not tick.** `pause-when-empty-seconds=60` means with
  nobody online the world pauses and **datapack `tick` functions stop running**.
  So after a reload on an empty server, anything gated behind a tick — including
  a version-gate or bootstrap function — **will not have run yet**. It fires
  when a player next joins. Don't conclude it broke; drive the function by hand
  if you need it to run now.
- **Unloaded chunks make commands silently no-op.** `execute if block` in an
  unloaded chunk just does nothing, no error. Every scripted check needs to run
  in a `forceload`ed chunk.
- **`setblock` lies about success.** It reports "Could not set the block" when
  the operation is a no-op, and with an unknown block id it fails *and leaves the
  old block in place*. Confirm with `execute if block`.
- **A function that fails to load makes its whole feature silently do nothing.**
  The only evidence is one `ERROR` line in the log naming the file. After every
  reload, grep the log for `Failed to load function` — scoped to the lines that
  reload added, not the whole file.
- **`latest.log` rotates on boot, not on reload.** After a `reload` the old
  errors are still in the file, so a bare `grep -c` counts failures from days
  ago. Record the line count before you reload and only look at what came after.
- **A `#` in the middle of a command is not a comment** — it's a scoreboard
  fake-player name (`#loaded`, `#rc`). Only a `#` in leading whitespace starts a
  comment.
- **Scoreboard operations work on fake players.** `#anything` is a legal holder
  with nobody connected, so `scoreboard players set #test foo 1` is a safe way to
  test scoreboard logic at 0 players.
- **`execute as <name>` only resolves against real entities.** On a fake holder
  that line quietly does nothing — fine for scoreboard-only code, a trap for
  anything entity-related.
- **Don't assert absolute health on a mob.** `summon ... {Health:20.0f}` gets
  clamped to the mob's `max_health`; assert a delta from a baseline instead.
- **Test subjects wander.** Anything that compares positions needs `NoAI:1b`.

---

## 6. FartPack is currently DISABLED

It was turned off deliberately so it wouldn't interfere with other testing. It
lives at `world/datapacks/fartpack.zip`.

**To re-enable it** (with 0 players online, then `reload`):

```bash
python3 /tmp/rcon.py 'datapack enable "file/fartpack.zip"'
python3 /tmp/rcon.py reload
```

**Leave it disabled** unless you are specifically asked to work on FartPack. It
is a large datapack with its own per-tick work, and it will interfere with
anything else you are testing. If you must enable it, tell the user first.

Current state, for context: the last deploy went out as **v27**, and it
**self-reported as FAILED** — correctly. The eight lines that had broken the
previous build were fixed and all functions now load, but the per-player config
commands (`/function fartpack:admin/rate <player> <n>` and friends) are
currently **not working** and are being debugged. Do not rely on them, and do not
try to fix them unless asked.

---

## 7. If something looks broken

Work in this order — it is the order that distinguishes "the pack is wrong" from
"my test is wrong", and the distinction has been wrong every single time:

1. Is the thing you're testing even loaded? Grep the log for
   `Failed to load function`.
2. Did your command actually do what you think? **Read the value back.** Never
   trust a command's exit status or its silence.
3. Could your test be unable to fail? A test that can't fail is worse than no
   test, because it gets reported as a pass.
4. Only then look at the pack logic.

And when you report: say what you verified, what you could not verify, and what
you did not test. Do not describe something as working because a gate printed a
green word.
