#!/bin/bash
set -e

HERO="20260409_015759_b486070b_visible_video_ff108b39d210.mp4"
SR1="Screen Recording 2026-04-08 at 2.47.17PM.mov"
SR2="Screen Recording 2026-04-08 at 2.54.45PM.mov"
AUDIO="ElevenLabs_2026-04-08T21_51_47_Hugh - Rhythmic and Engaging Storyteller_pvc_sp109_s50_sb75_se0_b_m2.mp3"
BG="hero_bg_frame.png"
OUTPUT="cgt_youtube_final.mov"

W=1920
H=1080
FPS=30

TMPDIR=$(mktemp -d)
echo "Working in $TMPDIR"

# ========================================
# 1. Hero video - scale to 1920x1080, 5s
# ========================================
echo "=== Processing hero video (with original audio) ==="
ffmpeg -y -i "$HERO" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$FPS" \
  -c:v libx264 -preset fast -crf 18 -c:a aac -b:a 192k -t 5 \
  "$TMPDIR/part_hero.mp4" 2>/dev/null

# ========================================
# 2. SR1 (landscape) - trim and scale
# ========================================
echo "=== Processing SR1 (landscape web app) ==="

# Define cut segments: start duration
SR1_CUTS=(
  "0 3"       # Landing page
  "10 2 blur" # Google sign-in (blur account names)
  "15 4"      # Welcome/loading
  "20 5"      # Dashboard browsing rounds
  "46 4.5"    # Map view (extended to replace removed analytics cut)
)

SR1_PARTS=""
i=0
for cut in "${SR1_CUTS[@]}"; do
  start=$(echo $cut | awk '{print $1}')
  dur=$(echo $cut | awk '{print $2}')
  flag=$(echo $cut | awk '{print $3}')
  out="$TMPDIR/sr1_part_${i}.mp4"

  BASE_VF="scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$FPS"

  if [ "$flag" = "blur" ]; then
    # Blur the center area where account names/emails appear
    # Google sign-in: accounts are roughly in the right 60% of screen, middle 70% vertically
    VF="${BASE_VF},split[main][blur_src];[blur_src]crop=iw*0.55:ih*0.7:iw*0.35:ih*0.12,boxblur=25:25[blurred];[main][blurred]overlay=W*0.35:H*0.12"
  else
    VF="$BASE_VF"
  fi

  ffmpeg -y -ss "$start" -i "$SR1" -t "$dur" \
    -vf "$VF" \
    -c:v libx264 -preset fast -crf 18 -an \
    "$out" 2>/dev/null
  SR1_PARTS="$SR1_PARTS|$out"
  ((i++))
done

# Concatenate SR1 parts
echo "=== Concatenating SR1 parts ==="
SR1_LIST="$TMPDIR/sr1_list.txt"
for ((j=0; j<i; j++)); do
  echo "file '$TMPDIR/sr1_part_${j}.mp4'" >> "$SR1_LIST"
done
ffmpeg -y -f concat -safe 0 -i "$SR1_LIST" -c copy "$TMPDIR/part_sr1.mp4" 2>/dev/null

# ========================================
# 3. SR2 (portrait) - hero bg + inset right
# ========================================
echo "=== Processing SR2 (portrait mobile app) ==="

# Define cut segments
SR2_CUTS=(
  "0 3"       # Home screen intro
  "29 7"      # Course selection flow
  "43 5"      # Start Round screen
  "52 4"      # Hole 1 with distances (334/341/371 view)
  "81 1"      # Hole view (233/244/270, trimmed to avoid simulator menu)
  "90 2"      # Lock screen live activities intro (217/229/254)
  "97 10"     # Lock screen live activities updating (185→168→152)
)

# Phone overlay settings
CROP_W=630
CROP_H=1400
CROP_X=59
CROP_Y=40
PHONE_H=972
PHONE_W=$(python3 -c "print(int($CROP_W / $CROP_H * $PHONE_H))")
X_POS=$(( W - PHONE_W - 80 ))
Y_POS=$(( (H - PHONE_H) / 2 ))
FADE=30

SR2_PARTS=""
i=0
for cut in "${SR2_CUTS[@]}"; do
  start=$(echo $cut | awk '{print $1}')
  dur=$(echo $cut | awk '{print $2}')
  clip="$TMPDIR/sr2_clip_${i}.mp4"
  out="$TMPDIR/sr2_part_${i}.mp4"

  # Step 1: Pre-extract the SR2 segment (frame-accurate)
  ffmpeg -y -i "$SR2" \
    -vf "trim=start=${start}:duration=${dur},setpts=PTS-STARTPTS" \
    -an -c:v libx264 -preset fast -crf 18 \
    "$clip" 2>/dev/null

  # Step 2: Composite pre-extracted clip over hero background
  ffmpeg -y -loop 1 -i "$BG" -i "$clip" \
    -filter_complex "
      [0:v]scale=${W}:${H},fps=$FPS[bg];
      [1:v]crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y},
           scale=${PHONE_W}:${PHONE_H},
           format=rgba,
           geq='r=r(X,Y):g=g(X,Y):b=b(X,Y):a=255*min(min(min(X,W-1-X),min(Y,H-1-Y)),${FADE})/${FADE}'[phone];
      [bg][phone]overlay=${X_POS}:${Y_POS}:shortest=1[out]
    " \
    -map "[out]" -c:v libx264 -preset fast -crf 18 \
    "$out" 2>/dev/null

  ((i++))
done

# Concatenate SR2 parts
echo "=== Concatenating SR2 parts ==="
SR2_LIST="$TMPDIR/sr2_list.txt"
for ((j=0; j<i; j++)); do
  echo "file '$TMPDIR/sr2_part_${j}.mp4'" >> "$SR2_LIST"
done
ffmpeg -y -f concat -safe 0 -i "$SR2_LIST" -c copy "$TMPDIR/part_sr2.mp4" 2>/dev/null

# ========================================
# 4. End card generation
# ========================================
echo "=== Generating end card ==="
python3 generate_end_card.py

END_CARD_DUR=5
ffmpeg -y -loop 1 -i end_card.png -t "$END_CARD_DUR" \
  -vf "scale=${W}:${H},fps=$FPS" \
  -c:v libx264 -preset fast -crf 18 \
  "$TMPDIR/part_endcard.mp4" 2>/dev/null

# ========================================
# 5. Crossfade transitions between sections
# ========================================
echo "=== Adding crossfade transitions ==="
XFADE_DUR=2  # 2-second crossfade

# Get durations for offset calculations
HERO_VID_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMPDIR/part_hero.mp4")
SR2_VID_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMPDIR/part_sr2.mp4")

# Crossfade hero -> SR2
OFFSET1=$(python3 -c "print(float('$HERO_VID_DUR') - $XFADE_DUR)")
ffmpeg -y -i "$TMPDIR/part_hero.mp4" -i "$TMPDIR/part_sr2.mp4" \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=${XFADE_DUR}:offset=${OFFSET1}[v12]
  " \
  -map "[v12]" -c:v libx264 -preset fast -crf 18 -an \
  "$TMPDIR/hero_sr2.mp4" 2>/dev/null

# Crossfade (hero+SR2) -> SR1
HERO_SR2_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMPDIR/hero_sr2.mp4")
OFFSET2=$(python3 -c "print(float('$HERO_SR2_DUR') - $XFADE_DUR)")
ffmpeg -y -i "$TMPDIR/hero_sr2.mp4" -i "$TMPDIR/part_sr1.mp4" \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=${XFADE_DUR}:offset=${OFFSET2}[v_no_end]
  " \
  -map "[v_no_end]" -c:v libx264 -preset fast -crf 18 -an \
  "$TMPDIR/video_no_endcard.mp4" 2>/dev/null

# Crossfade SR1 -> end card
SR1_FULL_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMPDIR/video_no_endcard.mp4")
OFFSET3=$(python3 -c "print(float('$SR1_FULL_DUR') - $XFADE_DUR)")
ffmpeg -y -i "$TMPDIR/video_no_endcard.mp4" -i "$TMPDIR/part_endcard.mp4" \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=${XFADE_DUR}:offset=${OFFSET3}[vout]
  " \
  -map "[vout]" -c:v libx264 -preset fast -crf 18 -an \
  "$TMPDIR/video_only.mp4" 2>/dev/null

# Get hero duration for audio offset
HERO_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMPDIR/part_hero.mp4")
echo "=== Adding audio: hero audio for ${HERO_DUR}s, then MP3 voiceover ==="

# Calculate total audio duration needed: hero audio + full MP3
MP3_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")
TOTAL_AUDIO_DUR=$(python3 -c "print(float('$HERO_DUR') + float('$MP3_DUR'))")
VIDEO_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMPDIR/video_only.mp4")

echo "Video: ${VIDEO_DUR}s, Audio needed: ${TOTAL_AUDIO_DUR}s"

# If video is shorter than audio, extend last frame to match
if python3 -c "exit(0 if float('$VIDEO_DUR') < float('$TOTAL_AUDIO_DUR') else 1)"; then
  echo "=== Extending video to match full audio ==="
  # Extract last frame and create a still extension
  EXTEND_DUR=$(python3 -c "print(float('$TOTAL_AUDIO_DUR') - float('$VIDEO_DUR') + 0.5)")
  ffmpeg -y -sseof -0.1 -i "$TMPDIR/video_only.mp4" -vframes 1 -update 1 "$TMPDIR/last_frame.png" 2>/dev/null
  ffmpeg -y -loop 1 -i "$TMPDIR/last_frame.png" -t "$EXTEND_DUR" \
    -vf "scale=${W}:${H},fps=$FPS" \
    -c:v libx264 -preset fast -crf 18 \
    "$TMPDIR/extension.mp4" 2>/dev/null

  EXT_LIST="$TMPDIR/ext_list.txt"
  echo "file '$TMPDIR/video_only.mp4'" > "$EXT_LIST"
  echo "file '$TMPDIR/extension.mp4'" >> "$EXT_LIST"
  ffmpeg -y -f concat -safe 0 -i "$EXT_LIST" -c copy "$TMPDIR/video_extended.mp4" 2>/dev/null
  VIDEO_FILE="$TMPDIR/video_extended.mp4"
else
  VIDEO_FILE="$TMPDIR/video_only.mp4"
fi

DELAY_MS=$(python3 -c "print(int(float('$HERO_DUR')*1000))")

# Mix hero original audio (placed at start) with delayed MP3 voiceover
ffmpeg -y -i "$VIDEO_FILE" -i "$TMPDIR/part_hero.mp4" -i "$AUDIO" \
  -filter_complex "
    [1:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[hero_audio];
    [2:a]adelay=${DELAY_MS}|${DELAY_MS},aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[mp3_delayed];
    [hero_audio][mp3_delayed]amix=inputs=2:duration=longest[aout]
  " \
  -map 0:v:0 -map "[aout]" \
  -c:v copy -c:a aac -b:a 192k \
  -shortest \
  "$OUTPUT" 2>/dev/null

# Get final duration
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT")
echo ""
echo "=== Done! ==="
echo "Output: $OUTPUT"
echo "Duration: ${DURATION}s"
echo "Temp files in: $TMPDIR"
