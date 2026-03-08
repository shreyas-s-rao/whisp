#!/usr/bin/env bash
set -e

BASE="$HOME/.whisp"
LOG="$BASE/debug.log"

echo "---- $(date) ----" >> "$LOG"

# shellcheck source=/dev/null
source "$BASE/config.sh"

AUDIO="/tmp/dict.wav"
OUT="/tmp/out"

echo "audio?" >> "$LOG"
ls -l "$AUDIO" >> "$LOG" 2>&1 || true

PROMPT=""
if [ -f "$BASE/config/whisper_prompt.txt" ]; then
  PROMPT=$(cat "$BASE/config/whisper_prompt.txt")
fi

echo "running whisper-cli" >> "$LOG"

"$WHISP_WHISPER" \
  -m "$WHISP_MODEL" \
  -f "$AUDIO" \
  -t 8 \
  --prompt "$PROMPT" \
  -otxt \
  -of "$OUT" >> "$LOG" 2>&1

RAW=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$OUT.txt")
echo "raw: $RAW" >> "$LOG"

echo "$RAW" > "$BASE/last_raw.txt"

TEXT=$(echo "$RAW" | "$WHISP_VENV/bin/python" "$BASE/format.py" 2>> "$LOG" || echo "$RAW")
echo "formatted: $TEXT" >> "$LOG"

if [ -z "$TEXT" ]; then
  echo "nothing to paste" >> "$LOG"
  exit 0
fi

echo -n "$TEXT" | pbcopy
osascript -e 'tell application "System Events" to keystroke "v" using command down'
echo "pasted" >> "$LOG"

rm -f /tmp/out.txt /tmp/dict.wav
