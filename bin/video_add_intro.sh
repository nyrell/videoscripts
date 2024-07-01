#!/bin/bash
#
# Loop over all relevant (video) files and combine them with an intro and/or outro.

# Example of ffmpeg complex filter parameters:
# https://www.youtube.com/watch?v=pBIPKn0bqCM

# Configuration
# ----------------------------------------------------------------------

# The output directory
OUTPUT_DIR="script_output_with_intro"

# The video file that will be used as an intro
INTRO="intro.mp4"

# The video file that will be used as an outro / ending
OUTRO="outro.mp4"

if [ ! -f $INTRO ] && [ ! -f $OUTRO ]; then
    echo "Error: Neither the intro file ($INTRO) or the outro file ($OUTRO) was found. Aborting!"
    echo
    exit 1
fi

# Quality of resized video
# CRF, Constant Rate Factor: 0-51 (Best - Worst), Default: 23
#   17 should be "visually lossless"
QUALITY=17

# Start
# ----------------------------------------------------------------------

print_header()
{
  STR=$1        # The string to print as a header
  UNDERLINE=$2  # The character to use as underline, for example "-"

  COUNT=${#STR}
  echo
  echo $STR
  eval printf "%.s${UNDERLINE}" {1.."$COUNT"}
  echo
}

float_to_int()
{
    LC_ALL=C printf "%.0f" $1
}

mkdir -p ${OUTPUT_DIR}

if [ -f "$INTRO" ]; then
    print_header "Media information for intro" "-"
    mediainfo --Inform="Video;Resolution=%Width%x%Height%, Rotation: %Rotation% deg, Frame rate=%FrameRate% FPS, Codec=%CodecID%" "$INTRO"
fi

if [ -f "$OUTRO" ]; then
    print_header "Media information for outro" "-"
    mediainfo --Inform="Video;Resolution=%Width%x%Height%, Rotation: %Rotation% deg, Frame rate=%FrameRate% FPS, Codec=%CodecID%" "$OUTRO"
fi
echo

for F in *.mp4 *.MP4 *.MTS ; do
    if [ -f "$F" ] && [ "$F" != "$INTRO" ] && [ "$F" != "$OUTRO" ]; then

        print_header "Processing \"$F\"" "-"
        mediainfo --Inform="Video;Resolution=%Width%x%Height%, Rotation: %Rotation% deg, Frame rate=%FrameRate% FPS, Codec=%CodecID%" "${F}"

        ORIG_FRAMERATE=$(mediainfo --Inform="Video;%FrameRate%" "${F}")
        FRAMERATE=$(float_to_int ${ORIG_FRAMERATE})
        if [[ "${ORIG_FRAMERATE}" != *".000"* ]]; then
            echo "WARNING: Input frame rate is not an even integer! Frame rate will be changed: ${ORIG_FRAMERATE} -> ${FRAMERATE}"
        fi
        echo
        
        # If both INTRO and OUTRO exist, then we will merge 3 files, otherwise only 2
        if [ -f $INTRO ] && [ -f $OUTRO ]; then
            echo ffmpeg -loglevel warning -i $INTRO -i \"$F\" -i $OUTRO -filter_complex \"\[0:v\] \[0:a\] \[1:v\] \[1:a\] \[2:v\] \[2:a\] concat=n=3:v=1:a=1 [v] [a]\" -map "[v]" -map "[a]" -r $FRAMERATE -crf $QUALITY \"${OUTPUT_DIR}/${F}\"
            ffmpeg -loglevel warning -i $INTRO -i "$F" -i $OUTRO -filter_complex "[0:v] [0:a] [1:v] [1:a] [2:v] [2:a] concat=n=3:v=1:a=1 [v] [a]" -map "[v]" -map "[a]" -r $FRAMERATE -crf $QUALITY "${OUTPUT_DIR}/${F}"
        
        elif [ -f $INTRO ]; then
            echo ffmpeg -loglevel warning -i $INTRO -i \"$F\" -filter_complex \"\[0:v\] \[0:a\] \[1:v\] \[1:a\] concat=n=2:v=1:a=1 [v] [a]\" -map "[v]" -map "[a]" -r $FRAMERATE -crf $QUALITY \"${OUTPUT_DIR}/${F}\"
            ffmpeg -loglevel warning -i $INTRO -i "$F" -filter_complex "[0:v] [0:a] [1:v] [1:a] concat=n=2:v=1:a=1 [v] [a]" -map "[v]" -map "[a]" -r $FRAMERATE -crf $QUALITY "${OUTPUT_DIR}/${F}"
            
        else
            echo ffmpeg -loglevel warning -i \"$F\" -i $OUTRO -filter_complex \"\[0:v\] \[0:a\] \[1:v\] \[1:a\] concat=n=2:v=1:a=1 [v] [a]\" -map "[v]" -map "[a]" -r $FRAMERATE -crf $QUALITY \"${OUTPUT_DIR}/${F}\"
            ffmpeg -loglevel warning -i "$F" -i $OUTRO -filter_complex "[0:v] [0:a] [1:v] [1:a] concat=n=2:v=1:a=1 [v] [a]" -map "[v]" -map "[a]" -r $FRAMERATE -crf $QUALITY "${OUTPUT_DIR}/${F}"
        fi
    fi
done

echo "Done!"
