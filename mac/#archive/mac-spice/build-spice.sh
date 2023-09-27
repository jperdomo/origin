#!/bin/sh
cd ~/.local/bin
jhbuild bootstrap
jhbuild build
jhbuild run remote-viewer
#Bundling
#jhbuild run gtk-mac-bundler ~/Source/spice-jhbuild/bundle/remote-viewer.bundle
#hdiutil create ~/Desktop/dist/RemoteViewer.dmg -srcfolder ~/Desktop/dist/ -ov