#!/usr/bin/env python3
"""Remove the macOS-style panels (top bar + icons-only floating dock) from Plasma
appletsrc, persistently. Run ONLY while plasmashell is stopped.

Removes containments that are:
  * a top panel  : plugin=org.kde.panel AND location=3, OR
  * the dock     : plugin=org.kde.panel AND location=4 AND applets == {icontasks}
Keeps: the desktop, and any normal bottom panel (location=4 with kickoff/systemtray).

Usage:  kde-remove-mac-panels.py <appletsrc> [--dry-run]
"""
import re, sys

def main():
    args=[a for a in sys.argv[1:] if not a.startswith("--")]
    dry="--dry-run" in sys.argv
    if len(args)!=1:
        sys.stderr.write("usage: kde-remove-mac-panels.py <appletsrc> [--dry-run]\n"); return 2
    path=args[0]
    lines=open(path,encoding="utf-8").read().splitlines(keepends=True)
    hdr=re.compile(r'^\[Containments\]\[(\d+)\](.*)$')

    cont={}
    cur=None; top=False; appl=False
    for ln in lines:
        s=ln.rstrip("\n"); m=hdr.match(s)
        if s.startswith("["):
            if m:
                n=m.group(1); rest=m.group(2)
                cont.setdefault(n,{"plugin":None,"location":None,"applets":set()})
                cur=n; top=(rest==""); appl=bool(re.match(r'^\[Applets\]\[\d+\]$',rest))
            else:
                cur=None; top=False; appl=False
        elif cur is not None and "=" in ln:
            k,v=ln.split("=",1); k=k.strip(); v=v.strip()
            if top and k=="plugin": cont[cur]["plugin"]=v
            elif top and k=="location": cont[cur]["location"]=v
            elif appl and k=="plugin": cont[cur]["applets"].add(v)

    targets=set()
    for n,i in cont.items():
        if i["plugin"]!="org.kde.panel": continue
        if i["location"]=="3":                                       # top bar
            targets.add(n)
        elif i["location"]=="4" and i["applets"]=={"org.kde.plasma.icontasks"}:  # dock
            targets.add(n)

    if not targets:
        print("removed:none"); return 0
    if dry:
        print("would-remove:"+",".join(sorted(targets))); return 0

    out=[]; skip=False
    for ln in lines:
        s=ln.rstrip("\n"); m=hdr.match(s)
        if s.startswith("["):
            skip=bool(m and m.group(1) in targets)
        if not skip: out.append(ln)
    open(path,"w",encoding="utf-8").write("".join(out))
    print("removed:"+",".join(sorted(targets)))
    return 0

sys.exit(main())
