#!/bin/sh
# Renders the README GIF (docs/demo.gif): a still-background variant of the video,
# 960 px wide at 15 fps with an optimised palette.
set -eu
cd "$(dirname "$0")/.."
npx remotion render src/index.ts Blink out/blink-gif.mp4 --props='{"forGif":true}' --muted
ffmpeg -loglevel error -y -i out/blink-gif.mp4 \
    -vf "fps=15,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    ../docs/demo.gif
ls -lh ../docs/demo.gif
