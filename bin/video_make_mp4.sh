#!/bin/bash

# Configuration
# ----------------------------------------------------------------------

# The output directory
OUTPUT_DIR="script_output_mp4"

# Quality of resized video
# CRF, Constant Rate Factor: 0-51 (Best - Worst), Default: 23
#   17 should be "visually lossless"
QUALITY=17



# Handle arguments
# ----------------------------------------------------------------------
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

usage() {
    echo "Loop over all files in a directory, and try to be smart about which ones need to be converted"
    echo "to mp4 (x264). Also try to be smart about audio conversion, deinterlace, pixel formats and"
    echo "resolution etc."
    echo
    echo "Being smart, in this case means getting a good result on my collection of old training videos,"
    echo "filmed by different people and equipment. The script tries to actually change the resulting"
    echo "video as little as possible compared to the original."
    echo
    echo "Usage:"
    echo "   ${SCRIPT_NAME} [--force-deinterlace]"
    echo
    echo "   --force-deinterlace   This parameter was needed for old videos from 2008 in svcd format. They"
    echo "                         were interlaced, but mediainfo still reported them as progressive, so"
    echo "                         it was not possible to handle this automatically."
    echo
    exit 1
}


OPTIONS=$(getopt -o 'h' --long 'help,force-deinterlace' -n "$SCRIPT_NAME" -- "$@")
if [ $? != 0 ]; then
    echo "Failed parsing options" >&2
fi

AUDIO_DEFAULT="-c:a aac -b:a 160k"
DEINT_DEFAULT=", nnedi=weights=/home/matny/Downloads/nnedi3_weights.bin"

VF_DEINT=""

eval set -- "$OPTIONS"
while true; do
    case "$1" in
        '--force-deinterlace')
            # VF_DEINT=", yadif=1"

            # nnedi is better than yadif but requires nnedi3_weights.bin that needs to be downloaded from github
            VF_DEINT=${DEINT_DEFAULT}
            echo "Note: Forcing deinterlace filter!"
            shift
            ;;
        '-h'|'--help') usage;;
        '--') shift; break;;
        ,*) break;;
    esac
done



# Start
# ----------------------------------------------------------------------

print_header()
{
  STR=$1        # The string to print as a header
  UNDERLINE=$2  # The character to use as underline, for example "-"

  COUNT=${#STR}
  echo
  echo "$STR"
  eval printf "%.s${UNDERLINE}" {1.."$COUNT"}
  echo
}


float_to_int()
{
    LC_ALL=C printf "%.0f" $1
}


mkdir -p ${OUTPUT_DIR}

for F in *.avi *.AVI *.mpeg *.MPEG *.mpg *.MPG *.mod *.MOD *.mov *.MOV *.flv *.FLV *.mts *.MTS *.mkv *.MKV *.3gp *3GP *.mp4 *.MP4; do
    if [ -f "$F" ]; then
        print_header "Processing \"$F\"" "-"
        mediainfo --Inform="Video;Resolution=%Width%x%Height%, Rotation: %Rotation% deg, Frame rate=%FrameRate% FPS, Format=%Format%, Codec=%CodecID%" "${F}"

        VIDEO_CODEC=$(mediainfo --Inform="Video;%Format%" "${F}")
        ROTATION=$(mediainfo --Inform="Video;%Rotation%" "${F}")
        SCALE=$(mediainfo --Inform="Video;%Width%:%Height%" "${F}")
        ORIG_FRAMERATE=$(mediainfo --Inform="Video;%FrameRate%" "${F}")
        ORIG_FRAMERATEMODE=$(mediainfo --Inform="Video;%FrameRate_Mode/String%" "${F}")
        FRAMERATE=$(float_to_int "${ORIG_FRAMERATE}")
        VIDEO_REENCODING_NEEDED=false

        if [[ "$ROTATION" == *"90"* ]]; then
            # If the video is rotated (portrait), swap the scale
            echo "Video is in portrait - Swapping scale parameter!"
            SCALE=$(mediainfo --Inform="Video;scale=%Height%:%Width%")
            VIDEO_REENCODING_NEEDED=true
        elif [[ "$SCALE" == "480:576" ]]; then
            echo "NOTE: This is 480x576 SVCD format, that in 4:3 will be displayed square at 768x576. Setting SCALE to 768x576!"
            SCALE="768:576"
            VIDEO_REENCODING_NEEDED=true
        # elif [[ "$SCALE" == "1440:1080" ]]; then
        #     echo "NOTE: The stored resolution is 1440x1080 but display resolution is 1920x1080. Setting SCALE to 1920x1080!"
        #     SCALE="1920:1080"
        #     VIDEO_REENCODING_NEEDED=true
        fi

        if [[ "${ORIG_FRAMERATE}" != *".000"* ]]; then
            echo "NOTE: Input frame rate is not an even integer! Frame rate will be changed: ${ORIG_FRAMERATE} -> ${FRAMERATE}"
            VIDEO_REENCODING_NEEDED=true
        elif [[ "${ORIG_FRAMERATEMODE}" == "Variable" ]]; then
            echo "NOTE: Input frame rate mode is variable! Frame rate mode will be changed to constant"
            VIDEO_REENCODING_NEEDED=true
        fi

        SCAN_TYPE=$(mediainfo --Inform="Video;%ScanType%" "${F}")
        if [[ "${SCAN_TYPE}" == "Interlaced" ]]; then
            echo "NOTE: Detected interlaced video. Converting to progressive."
            VF_DEINT=${DEINT_DEFAULT}
            VIDEO_REENCODING_NEEDED=true
        fi

        MORE_PARAMS=""
        CHROMA_SUB_SAMPLING=$(mediainfo --Inform="Video;%ChromaSubsampling%" "${F}")
        if [[ "${CHROMA_SUB_SAMPLING}" != *"4:2:0"* ]]; then
            echo "NOTE: ChromaSubsampling=${CHROMA_SUB_SAMPLING}, adding pixel format conversion flag!"
            MORE_PARAMS="-pix_fmt yuv420p"
            VIDEO_REENCODING_NEEDED=true
        fi

        VIDEO_RECODE_PARAMS="${MORE_PARAMS} -filter:v \"scale=${SCALE}${VF_DEINT}\" -vcodec libx264 -r $FRAMERATE -crf $QUALITY"
        if [[ "${VIDEO_CODEC}" == *"AVC"* && "${VIDEO_REENCODING_NEEDED}" == false ]]; then
            echo "NOTE: Detected video codec \"${VIDEO_CODEC}\". No re-encode needed!"
            VIDEO="-c:v copy"
        elif [[ "${VIDEO_CODEC}" == *"AVC"* && "${VIDEO_REENCODING_NEEDED}" == true ]]; then
            echo "NOTE: Video codec is already \"${VIDEO_CODEC}\", but will re-encoding to AVC libx264 due to other changes!"
            VIDEO=${VIDEO_RECODE_PARAMS}
        else
            echo "NOTE: Found video codec \"${VIDEO_CODEC}\", will re-encoding to AVC libx264!"
            VIDEO=${VIDEO_RECODE_PARAMS}
        fi

        AUDIO="-c:a copy"
        AUDIO_CODEC=$(mediainfo --Inform="Audio;%Format/String%" "${F}")
        if [[ "${AUDIO_CODEC}" == "AAC" ]]; then
            echo "NOTE: Detected audio codec \"${AUDIO_CODEC}\". No conversion needed!"
        else
            echo "NOTE: Detected audio codec \"${AUDIO_CODEC}\". Converting to AAC."
            AUDIO=${AUDIO_DEFAULT}
        fi

        echo
        bash -xc "ffmpeg -loglevel warning -i \"$F\" ${VIDEO} ${AUDIO} \"${OUTPUT_DIR}/${F%.*}.mp4\" -y"
        echo
    fi
done

echo "Done!"
