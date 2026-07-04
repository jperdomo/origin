#!/usr/bin/env python3
"""Edit the floating dock's Icons-Only Task Manager launchers in Plasma appletsrc.

Run ONLY while plasmashell is stopped (else plasmashell rewrites the file on exit).
Identifies the dock as: plugin=org.kde.panel, location=4 (bottom), whose applet
set is exactly {org.kde.plasma.icontasks} (never the full panel, top bar, desktop).
Then rewrites that icontasks applet's launchers list.

Usage:
  kde-dock-launchers.py <appletsrc> [--prepend <desktop-id>]... [--remove <desktop-id>]... [--dry-run]

Launcher entries are 'applications:<desktop-id>'. --prepend puts ids first (deduped);
--remove drops any entry containing that id. Prints the resulting launchers line.
"""
import re, sys

def parse_args(argv):
    path=None; prepend=[]; remove=[]; dry=False; i=0
    while i < len(argv):
        a=argv[i]
        if a=="--prepend" and i+1<len(argv): prepend.append(argv[i+1]); i+=2
        elif a=="--remove" and i+1<len(argv): remove.append(argv[i+1]); i+=2
        elif a=="--dry-run": dry=True; i+=1
        else: path=a; i+=1
    return path, prepend, remove, dry

def main():
    path, prepend, remove, dry = parse_args(sys.argv[1:])
    if not path:
        sys.stderr.write("usage: kde-dock-launchers.py <appletsrc> [--prepend id]... [--remove id]...\n"); return 2
    lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
    hdr = re.compile(r'^\[Containments\]\[(\d+)\](.*)$')

    # Pass 1: per-containment plugin/location/applets, and map applet-id -> plugin
    cont={}; applet_plugin={}   # applet_plugin[(N,M)] = plugin
    cur=None; top=False; appl_m=None
    for ln in lines:
        s=ln.rstrip("\n"); m=hdr.match(s)
        if s.startswith("["):
            if m:
                n=m.group(1); rest=m.group(2)
                cont.setdefault(n, {"plugin":None,"location":None,"applets":set()})
                cur=n; top=(rest=="")
                am=re.match(r'^\[Applets\]\[(\d+)\]$', rest); appl_m=am.group(1) if am else None
            else:
                cur=None; top=False; appl_m=None
        elif cur is not None and "=" in ln:
            k,v=ln.split("=",1); k=k.strip(); v=v.strip()
            if top and k=="plugin": cont[cur]["plugin"]=v
            elif top and k=="location": cont[cur]["location"]=v
            elif appl_m and k=="plugin":
                cont[cur]["applets"].add(v); applet_plugin[(cur,appl_m)]=v

    dock=[n for n,i in cont.items()
          if i["plugin"]=="org.kde.panel" and i["location"]=="4" and i["applets"]=={"org.kde.plasma.icontasks"}]
    if not dock:
        print("no-dock"); return 0
    N=dock[0]
    M=next((mm for (nn,mm),pl in applet_plugin.items() if nn==N and pl=="org.kde.plasma.icontasks"), None)
    if M is None:
        print("no-icontasks"); return 0

    target_hdr = f"[Containments][{N}][Applets][{M}][Configuration][General]"

    def transform(cur_val):
        items=[x for x in cur_val.split(",") if x]
        items=[x for x in items if not any(r in x for r in remove)]
        pre=[(p if p.startswith("applications:") else "applications:"+p) for p in prepend]
        items=[x for x in items if x not in pre]
        return ",".join(pre+items)

    # Pass 2: rewrite (or insert) launchers within the dock's General group
    out=[]; in_general=False; wrote=False; new_line_val=None
    i=0
    while i < len(lines):
        ln=lines[i]; s=ln.rstrip("\n")
        if s.startswith("["):
            # leaving a group: if we were in target General and never saw launchers, insert it
            if in_general and not wrote:
                nv=transform("")
                out.append(f"launchers={nv}\n"); wrote=True; new_line_val=nv
            in_general = (s==target_hdr)
            out.append(ln); i+=1; continue
        if in_general and s.startswith("launchers="):
            nv=transform(s.split("=",1)[1])
            new_line_val=nv
            out.append(f"launchers={nv}\n"); wrote=True; i+=1; continue
        out.append(ln); i+=1
    if in_general and not wrote:   # target group was last in file
        nv=transform(""); out.append(f"launchers={nv}\n"); new_line_val=nv

    if dry:
        print(f"dock=[{N}] icontasks=[{M}] launchers -> {new_line_val}"); return 0
    open(path,"w",encoding="utf-8").write("".join(out))
    print(f"set:launchers={new_line_val}")
    return 0

sys.exit(main())
