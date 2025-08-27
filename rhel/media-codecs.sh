#!/bin/bash

sudo dnf install \
@multimedia \
@sound-and-video \
ffmpeg-libs \
gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame*
