import sys,socket,struct,os,subprocess,time,glob
SID="241920ac-55ce-46c6-aa2f-c42ebf290457"
pw=[l.split("=",1)[1].rstrip("\n") for l in open(os.path.expanduser("~/crafty/servers/%s/server.properties"%SID)) if l.startswith("rcon.password=")][0]
host=subprocess.check_output(["docker","inspect","-f","{{range $k, $v := .NetworkSettings.Networks}}{{if $v.IPAddress}}{{$v.IPAddress}}{{end}}{{end}}","crafty"]).decode().strip()
s=socket.create_connection((host,25575),timeout=5); s.settimeout(30)
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
s.sendall(pk(19,3,pw))
if rd()[0]!=19: sys.exit("AUTH FAILED")

ROOT=sys.argv[1]
PKG="/data/fartpack/"          # namespace stripped; only pack-owned lines are linted
PARSE_ERR=("Unknown or incomplete","Incorrect argument for command","Expected","No variables in macro",
           "Can't parse function line","Expected whitespace","Unknown registry key")
n=0
def run(c):
    global n; n+=1
    s.sendall(pk(n,2,c)); time.sleep(0.06)
    return (rd()[1] or "").strip()

fails=[]; checked=0; skipped=0
for path in sorted(glob.glob(ROOT+"/**/*.mcfunction", recursive=True)):
    for i,line in enumerate(open(path,encoding="utf8").read().split("\n"),1):
        raw=line.strip()
        if not raw or raw.startswith("#"): continue
        # macro lines: substitute the macro var so the line becomes concrete
        cmd = raw.lstrip("$").replace("$(pid)","1")
        # skip state-mutating bossbar lines (we verify those by hand)
        if "bossbar" in cmd:
            skipped+=1; continue
        checked+=1
        out=run(cmd)
        if any(e in out for e in PARSE_ERR):
            fails.append((os.path.relpath(path,ROOT), i, raw, out))
s.sendall(pk(999,0,"")); s.close()
print("lines parse-checked: %d   (skipped %d bossbar lines)" % (checked, skipped))
print("PARSE FAILURES: %d\n" % len(fails))
for p,i,raw,out in fails:
    msg=" | ".join(l.strip() for l in out.splitlines() if l.strip() and not l.startswith("----"))
    print("%s:%d\n   %s\n   -> %s\n" % (p,i,raw,msg[:220]))
