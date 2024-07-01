#!/bin/bash

# for F in *.mp4 *.MP4 *.mts *.MTS; do
#     echo $F
# done

find . -maxdepth 1 -type f -iregex ".*\.\(mp4\|mts\)" | sort | while read F; do
    # echo $F

    INFO=$(mediainfo --Inform="Video;%Width%x%Height% @ %FrameRate% FPS, %Bits-(Pixel*Frame)% BPPF, %Rotation% deg, Codec %CodecID%" "${F}")

    printf "%-60s %s\n" "$INFO" "$F"
done
