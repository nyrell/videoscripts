# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Repository overview

A collection of Bash scripts that use `ffmpeg` and `mediainfo` to batch-convert
video files in a directory. Each script loops over the video files in the
current working directory (`*.mp4 *.MP4 *.mts *.MTS *.mov *.MOV`) and produces
output in a dedicated subdirectory (e.g. `script_output_small/`).

Scripts live in `bin/`:

- `video_make_small.sh` — resize videos to a smaller version (default "half HD"
  960x540 mp4/x264).
- `video_make_mp4.sh` — convert videos to mp4 (x264), auto-detecting which files
  need conversion plus audio/deinterlace/pixel-format handling.
- `video_add_intro.sh` — prepend/append an intro/outro video via an ffmpeg
  complex filter.
- `video_add_still_intro.sh` — prepend/append a still image as an intro/outro.
- `video_create_titles.sh` — create a title clip from an image and duration.
- `video_print_info.sh` / `video_info_diff.sh` — inspect/compare media metadata.

## Conventions

- Scripts are POSIX-ish Bash; parse options with `getopt`, read metadata with
  `mediainfo --Inform=...`, and echo the full `ffmpeg` command via `bash -xc`
  so the user can see exactly what runs.
- Keep configuration in clearly-labelled variables at the top of each script.
- Match the existing style (comment headers, `print_header`, helper functions).

## Dependencies

Requires `ffmpeg`, `ffprobe`, `mediainfo`, and `getopt` on `PATH`.

## Verifying changes

- Syntax check any edited script: `bash -n bin/<script>.sh`.
- For encoding changes, run the script in a folder containing a sample video and
  confirm the emitted `ffmpeg` command, then inspect the output (e.g. keyframe
  spacing with `ffprobe -select_streams v -show_frames ...`).

## Git rules

- **You may commit.** Do **not** list yourself (Claude) as the author or as a
  co-author — no `Co-Authored-By` trailer and do not alter the commit author.
- **Do not push.** Leave pushing to the user.
