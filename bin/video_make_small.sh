#!/bin/bash
#
# Loop over all relevant (video) files and resize them.

# Configuration
# ----------------------------------------------------------------------

# The output directory
OUTPUT_DIR="script_output_small"

# Size after resize, 960x540 == "Half HD"
SIZE_HORIZONTAL=960
SIZE_VERTICAL=540

AUDIO_DEFAULT="-c:a aac -b:a 160k"

# Quality of resized video
# CRF, Constant Rate Factor: 0-51 (Best - Worst), Default: 23
#   17 should be "visually lossless"
QUALITY=17



# Handle arguments
# ----------------------------------------------------------------------
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

usage() {
    echo "Loop over all files in a directory, and convert video files to smaller versions. "
    echo "Default is \"half HD\" 960x540 mp4 (x264)"
    echo
    echo "Usage:"
    echo "   ${SCRIPT_NAME} [--force-deinterlace]"
    echo
    echo "   --1080p   Set the resulting resolution to 1920x1080"
    echo
    exit 1
}

OPTIONS=$(getopt -o 'h' --long 'help,1080p' -n "$SCRIPT_NAME" -- "$@")
if [ $? != 0 ]; then
    echo "Failed parsing options" >&2
fi

eval set -- "$OPTIONS"
while true; do
    case "$1" in
        '--1080p')
            SIZE_HORIZONTAL=1920
            SIZE_VERTICAL=1080
            OUTPUT_DIR="${OUTPUT_DIR}_1080"
            shift
            ;;
        '-h'|'--help') usage;;
        '--') shift; break;;
        ,*) break;;
    esac
done

echo "Target resolution is set to: ${SIZE_HORIZONTAL}x${SIZE_VERTICAL}"



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

for F in *.mp4 *.MP4 *.mts *.MTS *.mov *.MOV ; do
    if [ -f "$F" ]; then
        print_header "Processing \"$F\"" "-"

        WIDTH=$(mediainfo --Inform="Video;%Width%" "${F}")
        HEIGHT=$(mediainfo --Inform="Video;%Height%" "${F}")
        VIDEO_CODEC=$(mediainfo --Inform="Video;%CodecID%" "${F}")

        ROTATION=$(mediainfo --Inform="Video;%Rotation%" "${F}")
        ORIG_FRAMERATE=$(mediainfo --Inform="Video;%FrameRate%" "${F}")
        FRAMERATE=$(float_to_int ${ORIG_FRAMERATE})
        AUDIO_CODEC=$(mediainfo --Inform="Audio;%Format/String%" "${F}")

        echo "Resolution=${WIDTH}x${HEIGHT}, Rotation: ${ROTATION} deg, Frame rate=${ORIG_FRAMERATE} FPS, Video=${VIDEO_CODEC}, Audio=${AUDIO_CODEC}"

        SCALE=scale=${SIZE_HORIZONTAL}:${SIZE_VERTICAL}
        if [[ "$ROTATION" == *"90"* ]]; then
            # If the video is rotated (portrait), swap the scale
            SCALE=scale=${SIZE_VERTICAL}:${SIZE_HORIZONTAL}
            echo "Video is in portrait - Swapping scale parameter!"
        fi

        if [[ "${ORIG_FRAMERATE}" != *".000"* ]]; then
            echo "WARNING: Input frame rate is not an even integer! Frame rate will be changed: ${ORIG_FRAMERATE} -> ${FRAMERATE}"
        fi

        AUDIO="-c:a copy"
        if [[ "${AUDIO_CODEC}" != *"AAC"* ]]; then
            echo "NOTE: Detected audio codec \"${AUDIO_CODEC}\". Converting to AAC."
            AUDIO=${AUDIO_DEFAULT}
        fi

        echo
        bash -xc "ffmpeg -loglevel warning -i \"$F\" -filter:v $SCALE -vcodec libx264 -r $FRAMERATE -crf $QUALITY ${AUDIO} \"${OUTPUT_DIR}/${F%.*}.mp4\""
        echo
    fi
done

echo "Done!"
