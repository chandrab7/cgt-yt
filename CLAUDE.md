# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Video production workspace for CGT (Chandra's Golf Tracker) YouTube promotional content. Uses ffmpeg to composite a final video from multiple source recordings, voiceover audio, and background music.

Published video: https://www.youtube.com/watch?v=nYaM5O9Qo5E

## Build Commands

Requires: `ffmpeg` (install via `brew install ffmpeg`), `python3`

```bash
# Build the main composited video (hero + screen recordings + voiceover)
bash build_video.sh
# Output: cgt_youtube_final.mov

# Add background music (run after build_video.sh)
# This is a manual ffmpeg step — see the amix command pattern in the script
```

## Architecture: build_video.sh

The build script assembles the final video in stages:

1. **Hero video** (mp4) — scaled to 1920x1080, keeps original audio for first 5s
2. **SR1** (landscape web app recording) — trimmed to key screens, scaled to 1080p. Supports per-segment `blur` flag for privacy (e.g., Google sign-in accounts)
3. **SR2** (portrait iOS app recording) — each segment is **pre-extracted first** (frame-accurate trim), then composited over the hero background image with the phone inset on the right side and soft-fade edges
4. **Crossfade transitions** (2s) between hero→SR2 and SR2→SR1 using xfade filter
5. **Audio assembly** — hero original audio plays first, then ElevenLabs voiceover is delayed and mixed in. If video is shorter than audio, last frame is held as a still

Key design decisions:
- SR2 segments use a **two-pass approach**: pre-extract with trim filter, then composite. This is necessary because ffmpeg's filter_complex doesn't seek accurately when trim and overlay are in the same graph with a looped image input.
- Cut segments are defined as arrays of `"start duration [flag]"` — easy to add/remove/reorder clips.
- Portrait video is cropped (630x1400 from 748x1480) to remove screen recording chrome, then overlaid with a `geq` alpha fade on edges.
- The `cgt_youtube_with_music.mov` variant adds background music mixed at -16dB with fade in/out.

## Source Files

- `hero_bg_frame.png` — extracted first frame from hero video, used as unblurred background behind SR2 phone inset
- Screen recordings may contain macOS special characters in filenames (narrow no-break spaces) — the glob tool finds them but ffmpeg may need the files renamed first
