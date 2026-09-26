import sys,socket,struct,os,subprocess
SID="241920ac-55ce-46c6-aa2f-c42ebf290457"
pw=[l.split("=",1)[1].rstrip("\n") for l in open(os.path.expanduser("~/crafty/servers/%s/server.properties"%SID)) if l.startswith("rcon.password=")][0]
host=subprocess.check_output(["docker","inspect","-f","{{range $k, $v := .NetworkSettings.Networks}}{{if $v.IPAddress}}{{$v.IPAddress}}{{end}}{{end}}","crafty"]).decode().strip()
s=socket.create_connection((host,25575),timeout=5); s.settimeout(25)
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
n=1
def run(c):
    global n; n+=1
    s.sendall(pk(n,2,c)); time.sleep(0.4); return (rd()[1] or "").strip()
import time
for c in sys.argv[1:]:
    print("> %s"%c)
    for line in run(c).splitlines():
        if line.strip() and not line.startswith("----"): print("   "+line)
    time.sleep(0.5)
s.sendall(pk(999,0,"")); s.close()
