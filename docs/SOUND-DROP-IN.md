# Adding new fart sounds

You drop `.ogg` files in; I do the rest. This file is the whole procedure.

## 1. The format your files must be

Copy the settings from the existing files exactly — they are all identical:

| Setting | Value |
|---|---|
| Container | Ogg Vorbis (`.ogg`) — **not** Ogg Opus, not MP3, not WAV |
| Channels | 1 (mono) |
| Sample rate | 48000 Hz |
| Bitrate | don't worry, Vorbis handles it |

Check before you hand them over:

```sh
ffprobe -v error -show_entries stream=codec_name,channels,sample_rate -of default=nw=1 fart7.ogg
# expect: codec_name=vorbis, channels=1, sample_rate=48000
```

Anything else still plays in Minecraft, it just sounds worse and wastes download.
Mono matters most — a stereo fart in a game where the sound is positioned in 3D
sounds oddly wide and panned wrong.

## 2. Where the files go

One directory only:

```
fartpack_sounds/assets/fartpack/sounds/
```

That is the **source**. `build.sh` sets `RP_SRC="fartpack_sounds"` and zips it
into `fartpack_sounds.zip`, which is what gets uploaded as the release asset.

There is also a `src/resourcepack/` directory holding an identical copy of the
tree. **Do not put anything there** — it is a generated mirror, refreshed by
`rsync -a --delete` on every `build.sh` run, so a file you drop into it is
silently deleted by the next build. It is gitignored for the same reason.

Name new files `fart7.ogg`, `fart8.ogg`, … Do not reuse `fart1`–`fart6` or
`fart_legendary`; you would overwrite a sound that is already in use.

## 3. What I do once the files exist

1. Add each file to the `fart.burp` variant list in
   `fartpack_sounds/assets/fartpack/sounds.json`
2. `./build.sh` — rebuilds **both** zips. The RP build normalises every mtime to
   the zip epoch so the same input always produces the same sha1. The datapack
   zip is rebuilt too; that is harmless but it does mean its sha1 will move.
3. `rpverify.sh` — downloads what was uploaded and proves it is byte-identical
   before the server is pointed at it
4. Patch `resource-pack-sha1` in `server.properties`
5. `rpdeploy.sh` — **aborts if anyone is online**, then bounces the server

Note on step 2: `build.sh` also refreshes `backups/MANIFEST.sha256`.

Step 5 is the one that needs you. `require-resource-pack=true` means a bad sha1
locks everyone out, which is why the verify step is not optional.

## 4. Timings, so you record to fit

The existing set is the reference for how long a fart should be:

| File | Duration | Sounds like |
|---|---|---|
| `fart1.ogg` | 0.34s | short, quick |
| `fart3.ogg` | 0.55s | short-ish |
| `fart5.ogg` | 0.44s | short, different timbre |
| `fart6.ogg` | 0.57s | mid |
| `fart2.ogg` | 1.21s | long rumble |
| `fart4.ogg` | 1.59s | longest of the six |
| `fart_legendary.ogg` | 3.72s | the big one |

Minecraft plays a random variant each time, so the set reads as variety. **The
mix matters more than any single file.** A pack of seven near-identical 0.5s
farts sounds worse than six that genuinely differ.

Useful gaps if you want to fill them: something very short and squeaky (under
0.3s), something with a long tail, and if you can manage it one that's clearly a
different register rather than just a longer version of the same noise.

## 5. What I need from you

Just the files, in the folder above. I'll tell you the sha1 and ask before the
restart.

## Not doing

I can't record the audio. I also won't synthesise placeholder `.ogg` files and
present them as real farts — if I did, you'd find out at the worst moment, in
front of someone, from a sound that isn't one.
