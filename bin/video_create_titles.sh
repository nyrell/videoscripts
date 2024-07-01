#!/bin/bash
#
usage()
{
    echo "Usage:"
    echo "    video_create_titles.sh <image> <duration> <prefix>"
    echo ""
    echo "    <image>      Should be a PNG image of size 1920x1080"
    echo "    <duration>   The duration in seconds of the generated video clips"
    echo "    <prefix>     The prefix is added to the beginning of the name of all generated files"
    echo ""
    echo "    The script will take the input <image> and convert it to video of the specified <duration>. Many"
    echo "    videoclips in different resolutions will be generated. All outputs will use the <prefix> followed"
    echo "    by size information."
    echo 
    echo "Example:"
    echo "    video_create_titles.sh title_2024_1920_1080.png 3 title_2024"
    echo
    exit 1
}
IMAGE=$1
DURATION=$2
PREFIX=$3

# It is important that the frame rate is the same as the video that the title will be merged/concatenated with.
FRAMERATE=30

if [ $# -ne 3 ]; then
    echo "Error: Incorrect number of parameters!"
    echo
    usage
fi

if [ ! -f "$IMAGE" ]; then
    echo "Error: The input image ($IMAGE) was not found. Aborting!"
    exit
fi

DUR_MIN=1
DUR_MAX=20
if [ "$DURATION" -lt "$DUR_MIN" ] || [ "$DURATION" -gt "$DUR_MAX" ]; then
    echo "Error: Incorrect duration ($DURATION). Should be in the range: ${DUR_MIN} to ${DUR_MAX}. Aborting!"
    exit 1
fi

# Create different sized versions of the image
convert "$IMAGE" -resize 1600x900 "${PREFIX}_1600x900.png"
convert "$IMAGE" -resize 1440x810 "${PREFIX}_1440x810.png"
convert "$IMAGE" -resize 1280x720 "${PREFIX}_1280x720.png"
convert "$IMAGE" -resize 1120x630 "${PREFIX}_1120x630.png"
convert "$IMAGE" -resize 960x540  "${PREFIX}_960x540.png"

# Convert the images to video
ffmpeg -y -loglevel warning -loop 1 -i "${PREFIX}_1920x1080.png" -c:v libx264 -t $DURATION -pix_fmt yuv420p -vf scale=1920:1080 -r $FRAMERATE "/tmp/tmp_${PREFIX}_1920x1080.mp4"
ffmpeg -y -loglevel warning -loop 1 -i "${PREFIX}_1600x900.png"  -c:v libx264 -t $DURATION -pix_fmt yuv420p -vf scale=1600:900  -r $FRAMERATE "/tmp/tmp_${PREFIX}_1600x900.mp4"
ffmpeg -y -loglevel warning -loop 1 -i "${PREFIX}_1440x810.png"  -c:v libx264 -t $DURATION -pix_fmt yuv420p -vf scale=1440:810  -r $FRAMERATE "/tmp/tmp_${PREFIX}_1440x810.mp4"
ffmpeg -y -loglevel warning -loop 1 -i "${PREFIX}_1280x720.png"  -c:v libx264 -t $DURATION -pix_fmt yuv420p -vf scale=1280:720  -r $FRAMERATE "/tmp/tmp_${PREFIX}_1280x720.mp4"
ffmpeg -y -loglevel warning -loop 1 -i "${PREFIX}_1120x630.png"  -c:v libx264 -t $DURATION -pix_fmt yuv420p -vf scale=1120:630  -r $FRAMERATE "/tmp/tmp_${PREFIX}_1120x630.mp4"
ffmpeg -y -loglevel warning -loop 1 -i "${PREFIX}_960x540.png"   -c:v libx264 -t $DURATION -pix_fmt yuv420p -vf scale=960:540   -r $FRAMERATE "/tmp/tmp_${PREFIX}_960x540.mp4"

# Add an empty audio track to the video
ffmpeg -loglevel warning -ar 48000 -acodec pcm_s16le -f s16le -ac 2 -channel_layout 2.1 -i /dev/zero -i "/tmp/tmp_${PREFIX}_1920x1080.mp4" -vcodec copy -acodec aac -strict -2 -shortest "${PREFIX}_1920x1080_r${FRAMERATE}.mp4"
ffmpeg -loglevel warning -ar 48000 -acodec pcm_s16le -f s16le -ac 2 -channel_layout 2.1 -i /dev/zero -i "/tmp/tmp_${PREFIX}_1600x900.mp4" -vcodec copy -acodec aac -strict -2 -shortest "${PREFIX}_1600x900_r${FRAMERATE}.mp4"
ffmpeg -loglevel warning -ar 48000 -acodec pcm_s16le -f s16le -ac 2 -channel_layout 2.1 -i /dev/zero -i "/tmp/tmp_${PREFIX}_1440x810.mp4" -vcodec copy -acodec aac -strict -2 -shortest "${PREFIX}_1440x810_r${FRAMERATE}.mp4"
ffmpeg -loglevel warning -ar 48000 -acodec pcm_s16le -f s16le -ac 2 -channel_layout 2.1 -i /dev/zero -i "/tmp/tmp_${PREFIX}_1280x720.mp4" -vcodec copy -acodec aac -strict -2 -shortest "${PREFIX}_1280x720_r${FRAMERATE}.mp4"
ffmpeg -loglevel warning -ar 48000 -acodec pcm_s16le -f s16le -ac 2 -channel_layout 2.1 -i /dev/zero -i "/tmp/tmp_${PREFIX}_1120x630.mp4" -vcodec copy -acodec aac -strict -2 -shortest "${PREFIX}_1120x630_r${FRAMERATE}.mp4"
ffmpeg -loglevel warning -ar 48000 -acodec pcm_s16le -f s16le -ac 2 -channel_layout 2.1 -i /dev/zero -i "/tmp/tmp_${PREFIX}_960x540.mp4" -vcodec copy -acodec aac -strict -2 -shortest "${PREFIX}_960x540_r${FRAMERATE}.mp4"

# Clean up
rm /tmp/tmp_${PREFIX}_*

echo "Done!"
