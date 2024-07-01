#!/bin/bash
#
# Loop over all relevant (video) files and resize them. 

# Configuration
# ----------------------------------------------------------------------

# The output directory
OUTPUT_DIR="script_output_hd"

# Size after resize, 960x540 == "Half HD"
# SIZE_HORIZONTAL=960
SIZE_HORIZONTAL=1920

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

for F in *.mp4 *.MP4 *.mts *.MTS *.mov *.MOV ; do
    if [ -f "$F" ]; then
        print_header "Processing \"$F\"" "-"
        mediainfo --Inform="Video;Resolution=%Width%x%Height%, Rotation: %Rotation% deg, Frame rate=%FrameRate% FPS, Codec=%CodecID%" "${F}"

        ROTATION=$(mediainfo --Inform="Video;%Rotation%" "${F}")
        SCALE=scale=${SIZE_HORIZONTAL}:-1
        if [[ "$ROTATION" == *"90"* ]]; then
            # If the video is rotated (portrait), swap the scale
            SCALE=scale=-1:${SIZE_HORIZONTAL}
            echo "Video is in portrait - Swapping scale parameter!"
        fi

        ORIG_FRAMERATE=$(mediainfo --Inform="Video;%FrameRate%" "${F}")
        FRAMERATE=$(float_to_int ${ORIG_FRAMERATE})
        if [[ "${ORIG_FRAMERATE}" != *".000"* ]]; then
            echo "WARNING: Input frame rate is not an even integer! Frame rate will be changed: ${ORIG_FRAMERATE} -> ${FRAMERATE}"
        fi
        
        echo
        echo ffmpeg -loglevel warning -i \"$F\" -filter:v $SCALE -c:a copy -vcodec libx264 -r $FRAMERATE -crf $QUALITY \"${OUTPUT_DIR}/${F%.*}.mp4\"
        ffmpeg -loglevel warning -i "$F" -filter:v $SCALE -c:a copy -vcodec libx264 -r $FRAMERATE -crf $QUALITY "${OUTPUT_DIR}/${F%.*}.mp4"
        echo
    fi
done

echo "Done!"
