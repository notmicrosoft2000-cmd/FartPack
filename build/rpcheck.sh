#!/usr/bin/env bash
set -euo pipefail
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
cd /tmp
rm -rf rpdl
mkdir rpdl
cd rpdl
sed -n 's/^resource-pack=//p' "$SRV/server.properties" | sed 's|\\||g' > url.txt
echo "url bytes: $(stat -c%s url.txt)"
curl -sL -o dl.zip "$(cat url.txt)"
echo "downloaded bytes: $(stat -c%s dl.zip)"
echo "downloaded sha1 : $(sha1sum dl.zip | cut -d' ' -f1)"
echo "properties sha1 : $(grep '^resource-pack-sha1=' "$SRV/server.properties" | cut -d= -f2)"
python3 -c "import zipfile;zipfile.ZipFile('dl.zip').extractall('x')"
echo '--- contents ---'
find x -type f | sort
echo '--- pack.mcmeta ---'
cat x/pack.mcmeta
echo
echo '--- sounds.json ---'
cat x/assets/fartpack/sounds.json
echo
echo '--- en_us.json ---'
cat x/assets/fartpack/lang/en_us.json
echo
echo '--- ogg sizes ---'
find x -name '*.ogg' -printf '%s %p\n' | sort -k2
