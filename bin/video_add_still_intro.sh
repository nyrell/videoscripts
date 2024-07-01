#!/bin/bash
#
# Loop over all relevant (video) files and combine them with an intro and/or outro.

# Example of ffmpeg complex filter parameters:
# https://www.youtube.com/watch?v=pBIPKn0bqCM

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


# Default configuration
# ----------------------------------------------------------------------

# The output directory
OUTPUT_DIR="script_output_with_intro"

# Default intro duration
INTRO_DURATION="3"

# Default outro duration
OUTRO_DURATION="3"

usage() {
    echo "Loop through all videos in a directory and add an image as a intro and/or outro."
    echo
    echo "Usage:"
    echo "   ${SCRIPT_NAME} [--intro-img] [--outro-img] [--intro-duration] [--outro-duration] [--res]"
    echo
    echo "   --intro-img          The image to use for the intro. Default: intro.png"
    echo "   --intro-duration     The duration of the intro. Default: 3 [sec]"
    echo
    echo "   --outro-img          The image to use for the outro. Default: outro.png"
    echo "   --outro-duration     The duration of the outro. Default: 3 [sec]"
    echo
    exit 1
}


OPTIONS=$(getopt -o 'h' --long 'help,intro-img:,intro-duration:,outro-img:,outro-duration:,force-output-res:' -n "$SCRIPT_NAME" -- "$@")
if [ $? != 0 ]; then
    echo "Failed parsing options" >&2
fi

eval set -- "$OPTIONS"
while true; do
    case "$1" in
        '--intro-img')        INTRO_IMG=$2 ; shift 2 ;;
        '--intro-duration')   INTRO_DURATION=$2 ; shift 2 ;;
        '--outro-img')        OUTRO_IMG=$2 ; shift 2 ;;
        '--outro-duration')   OUTRO_DURATION=$2 ; shift 2 ;;
        '--force-output-res') FORCED_RESOLUTION=$2 ; shift 2 ;;
        '-h'|'--help') usage;;
        '--') shift; break;;
        ,*) break;;
    esac
done

print_header "Settings" "-"
echo "Current directory: $(pwd)"

if [ ! -z "${INTRO_IMG}" ]; then
    echo "Intro: ${INTRO_IMG}   ${INTRO_DURATION} seconds"
fi
if [ ! -z "${OUTRO_IMG}" ]; then
    echo "Outro: ${OUTRO_IMG}   ${OUTRO_DURATION} seconds"
fi

# Sanity check of resolution
if [ ! -z ${FORCED_RESOLUTION} ]; then
    case "${FORCED_RESOLUTION}" in
        '640x480')   ;&
        '960x540')   ;&
        '1280x720')  ;&
        '1600x900')  ;&
        '1920x1080') ;&
        '2560x1440') ;&
        '2048x1080') ;&
        '3840x2160') echo "Output resolution will be forced to: ${FORCED_RESOLUTION}" ;;
        *)
            echo "ERROR: Unrecognized resolution: \"${FORCED_RESOLUTION}\""
            exit
    esac
fi




# Quality of resized video
# CRF, Constant Rate Factor: 0-51 (Best - Worst), Default: 23
#   17 should be "visually lossless"
QUALITY=17

# Start
# ----------------------------------------------------------------------

mkdir -p ${OUTPUT_DIR}

if [ ! -f "${INTRO_IMG}" ] && [ ! -f "${OUTRO_IMG}" ]; then
    echo "Error: Neither the intro file (${INTRO_IMG}) or the outro file (${OUTRO_IMG}) was found. Aborting!"
    echo
    exit 1
fi

if [ -f "${INTRO_IMG}" ]; then
    echo
    echo "Intro file found: "
    echo "  ${INTRO_IMG}"
    mediainfo --Inform="Image;  Format=%Format%, Resolution=%Width%x%Height%" "${INTRO_IMG}"
fi

if [ -f "${OUTRO_IMG}" ]; then
    echo
    echo "Outro file found:"
    echo "  ${OUTRO_IMG}"
    mediainfo --Inform="Image;  Format=%Format%, Resolution=%Width%x%Height%" "${OUTRO_IMG}"
fi
echo

for F in *.mp4 *.MP4 *.MTS ; do
    if [ -f "$F" ] && [ "$F" != "${INTRO_IMG}" ] && [ "$F" != "${OUTRO_IMG}" ]; then

        print_header "Processing \"$F\"" "-"
        mediainfo --Inform="Video;Resolution=%Width%x%Height%, Rotation: %Rotation% deg, Frame rate=%FrameRate% FPS, Codec=%CodecID%" "${F}"

        ROTATION=$(mediainfo --Inform="Video;%Rotation%" "${F}")
        INPUT_RESOLUTION=$(mediainfo --Inform="Video;%Width%x%Height%" "${F}")
        if [[ ! -z ${FORCED_RESOLUTION} ]]; then
            VIDEO_RESOLUTION=${FORCED_RESOLUTION}
            echo "Use forced resolution: ${VIDEO_RESOLUTION}"
        else
            VIDEO_RESOLUTION=${INPUT_RESOLUTION}
            echo "Use original video resolution ${VIDEO_RESOLUTION}"
        fi
            
        if [[ -z ${FORCED_RESOLUTION} && $ROTATION == "0"* ]]; then
            echo "Use original resolution, no rotation needed"
            COPY_OR_RESIZE_FILTER="copy"
            
        elif [[ $ROTATION == "90"* ]]; then
            echo "Rotation ($ROTATION) detected, output will be rotated and padded to landscape!"
            HEIGHT=${VIDEO_RESOLUTION#*x}
            COPY_OR_RESIZE_FILTER="scale=-2:${HEIGHT}, pad=${VIDEO_RESOLUTION/x/:}:(ow-iw)/2:(oh-ih)/2, setdar=16/9"
            
        else
            echo "Use forced resolution, but no rotation needed"
            COPY_OR_RESIZE_FILTER="scale=${VIDEO_RESOLUTION}, setdar=16/9"
        fi
        
        ORIG_FRAMERATE=$(mediainfo --Inform="Video;%FrameRate%" "${F}")
        FRAMERATE=$(float_to_int ${ORIG_FRAMERATE})
        if [[ "${ORIG_FRAMERATE}" != *".000"* ]]; then
            echo "WARNING: Input frame rate is not an even integer! Frame rate will be changed: ${ORIG_FRAMERATE} -> ${FRAMERATE}"
        fi
        echo
        
        # If both INTRO and OUTRO_IMG exist, then we will merge 3 files, otherwise only 2
        if [[ -f "${INTRO_IMG}" && -f "${OUTRO_IMG}" ]]; then
            bash -xc "ffmpeg -loglevel warning -loop 1 -t ${INTRO_DURATION} -i \"${INTRO_IMG}\" -t 0.1 -f lavfi -i anullsrc -i \"$F\" -loop 1 -t 3 -i \"${OUTRO_IMG}\" -filter_complex \"[0:v] scale=${VIDEO_RESOLUTION},setdar=16/9 [intro] ; [3:v] scale=${VIDEO_RESOLUTION},setdar=16/9 [outro] ; [2:v] ${COPY_OR_RESIZE_FILTER} [video] ; [intro] [1] [video] [2:a] [outro] [1] concat=n=3:v=1:a=1 [v] [a]\" -map [v] -map [a] -r 30 -crf 17 -y \"${OUTPUT_DIR}/${F}\""

        elif [[ -f "${INTRO_IMG}" ]]; then
            bash -xc "ffmpeg -loglevel warning -loop 1 -t ${INTRO_DURATION} -i \"${INTRO_IMG}\" -t 0.1 -f lavfi -i anullsrc -i \"$F\" -filter_complex \"[0:v] scale=${VIDEO_RESOLUTION},setdar=16/9 [intro] ; [2:v] ${COPY_OR_RESIZE_FILTER} [video] ; [intro] [1] [video] [2:a] concat=n=2:v=1:a=1 [v] [a]\" -map [v] -map [a] -r 30 -crf 17 -y \"${OUTPUT_DIR}/${F}\""
            
        else
            # Add the outro also as an input in place of the intro, just to avoid renumbering in the filter
            bash -xc "ffmpeg -loglevel warning -loop 1 -t ${INTRO_DURATION} -i \"${OUTRO_IMG}\" -t 0.1 -f lavfi -i anullsrc -i \"$F\" -loop 1 -t ${OUTRO_DURATION} -i \"${OUTRO_IMG}\" -filter_complex \"[3:v] scale=${VIDEO_RESOLUTION},setdar=16/9 [outro] ; [2:v] ${COPY_OR_RESIZE_FILTER} [video] ; [video] [2:a] [outro] [1] concat=n=2:v=1:a=1 [v] [a]\" -map [v] -map [a] -r 30 -crf 17 -y \"${OUTPUT_DIR}/${F}\""
        fi
    fi
done

echo "Done!"
