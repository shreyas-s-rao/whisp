#!/usr/bin/env bash
set -e

BASE="$HOME/.whisp"
WHISPER_DIR="$BASE/whisper.cpp"
HAMMERSPOON_INIT="$HOME/.hammerspoon/init.lua"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GITHUB_RAW="https://raw.githubusercontent.com/shreyas-s-rao/whisp/main"

# Copy a file from the local repo if available, otherwise download it.
fetch() {
  local src="$1" dst="$2"
  if [ -f "$REPO_DIR/$src" ]; then
    cp "$REPO_DIR/$src" "$dst"
  else
    curl -fsSL "$GITHUB_RAW/$src" -o "$dst"
  fi
}

echo ""
echo "╔════════════════════════════════╗"
echo "║        Whisp Installer         ║"
echo "╚════════════════════════════════╝"
echo ""

# ── keybinding selection ──────────────────────────────────────────────────────

# When a function key is physically pressed in the terminal, the shell receives
# its escape sequence instead of its name. Map sequences back to key names.
decode_key() {
  case "$1" in
    $'\eOP'|$'\e[11~')  echo "F1"  ;;
    $'\eOQ'|$'\e[12~')  echo "F2"  ;;
    $'\eOR'|$'\e[13~')  echo "F3"  ;;
    $'\eOS'|$'\e[14~')  echo "F4"  ;;
    $'\e[15~')           echo "F5"  ;;
    $'\e[17~')           echo "F6"  ;;
    $'\e[18~')           echo "F7"  ;;
    $'\e[19~')           echo "F8"  ;;
    $'\e[20~')           echo "F9"  ;;
    $'\e[21~')           echo "F10" ;;
    $'\e[23~')           echo "F11" ;;
    $'\e[24~')           echo "F12" ;;
    $'\e[25~')           echo "F13" ;;
    $'\e[26~')           echo "F14" ;;
    $'\e[28~')           echo "F15" ;;
    $'\e[29~')           echo "F16" ;;
    $'\e[31~')           echo "F17" ;;
    $'\e[32~')           echo "F18" ;;
    $'\e[33~')           echo "F19" ;;
    $'\e[34~')           echo "F20" ;;
    *)                   echo "$1"  ;;
  esac
}

# Parse a hotkey string of the form [modifier+...]key.
# Accepted modifiers: ctrl, alt, cmd, shift (combinable, e.g. ctrl+alt+F1).
# Outputs two lines: a Lua modifier table (e.g. {"ctrl"}) and the key name.
# NOTE: avoid ctrl/cmd as modifiers for the hold-to-record key — holding them
# will intercept other shortcuts while you're recording. F-keys or alt+key
# are recommended for recording; modifier combos work fine for the learn key.
parse_hotkey() {
  local input="$1" label="$2"
  local mods_lua="{" key mod first=true

  # Split on '+'. The last token is the key; preceding tokens are modifiers.
  local IFS='+'
  local parts=()
  read -ra parts <<< "$input"
  local n=${#parts[@]}
  key="$(decode_key "${parts[$((n-1))]}")" 

  for ((i=0; i<n-1; i++)); do
    mod="${parts[$i]}"
    case "$mod" in
      ctrl|alt|cmd|shift) ;;
      *)
        echo "Error: '$mod' is not a valid modifier for $label. Use: ctrl, alt, cmd, shift." >&2
        exit 1
        ;;
    esac
    if $first; then mods_lua+="\"$mod\""; first=false
    else mods_lua+=", \"$mod\""; fi
  done
  mods_lua+="}"

  # Reject shifted characters as the base key.
  case "$key" in
    '~'|'!'|'@'|'#'|'$'|'%'|'^'|'&'|'*'|'('|')'|'_'|'+'|'{'|'}'|'|'|':'|'"'|'<'|'>'|'?')
      echo "Error: '$key' is a shifted character and cannot be used as a hotkey." >&2
      echo "       Use the unshifted key name (e.g. '\`' instead of '~', '-' instead of '_')." >&2
      exit 1
      ;;
  esac

  echo "$mods_lua"
  echo "$key"
}

echo "Tip: You can also type the key name (e.g. F19). Add modifiers with + (e.g. alt+F1, ctrl+shift+F2)."
echo "     For the record key, avoid ctrl/cmd — holding them interferes with other shortcuts."
echo ""
read -rp "Key for recording (press-and-hold) [default: F19]: " RECORD_INPUT
RECORD_INPUT="${RECORD_INPUT:-F19}"
mapfile -t _rec < <(parse_hotkey "$RECORD_INPUT" "record key")
RECORD_MODS="${_rec[0]}" RECORD_KEY="${_rec[1]}"

read -rp "Key for learning corrections [default: F18]: " LEARN_INPUT
LEARN_INPUT="${LEARN_INPUT:-F18}"
mapfile -t _lrn < <(parse_hotkey "$LEARN_INPUT" "learn key")
LEARN_MODS="${_lrn[0]}" LEARN_KEY="${_lrn[1]}"

echo ""
echo "Available Whisper models:"
echo "  1) base.en   — fastest, English only, ~150 MB  [default]"
echo "  2) small.en  — better accuracy, English only, ~490 MB"
echo "  3) medium.en — high accuracy, English only, ~1.5 GB"
echo "  4) base      — multilingual, ~150 MB"
echo "  5) small     — multilingual, ~490 MB"
echo "  6) medium    — multilingual, ~1.5 GB"
echo ""
read -rp "Choose model [1-6, default: 1]: " MODEL_CHOICE

case "$MODEL_CHOICE" in
  2) MODEL_NAME="small.en"  ;;
  3) MODEL_NAME="medium.en" ;;
  4) MODEL_NAME="base"      ;;
  5) MODEL_NAME="small"     ;;
  6) MODEL_NAME="medium"    ;;
  *) MODEL_NAME="base.en"   ;;
esac

echo ""
echo "Installing with:"
echo "  Record key : $RECORD_INPUT"
echo "  Learn key  : $LEARN_INPUT"
echo "  Model      : ggml-${MODEL_NAME}"
echo ""

# ── homebrew ──────────────────────────────────────────────────────────────────

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is required. Install it from https://brew.sh and re-run."
  exit 1
fi

echo "→ Checking system dependencies..."
brew_install_if_missing() {
  local cmd="$1" pkg="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✓ $pkg already installed, skipping."
  else
    echo "→ Installing $pkg..."
    brew install "$pkg"
  fi
}

brew_install_if_missing cmake
brew_install_if_missing sox
brew_install_if_missing python3
brew_install_if_missing git

if [ -d "/Applications/Hammerspoon.app" ]; then
  echo "✓ Hammerspoon already installed, skipping."
else
  echo "→ Installing Hammerspoon..."
  brew install --cask hammerspoon
fi

# ── directory structure ───────────────────────────────────────────────────────

echo "→ Creating ~/.whisp..."
mkdir -p "$BASE/config"

# ── whisper.cpp ───────────────────────────────────────────────────────────────

if [ ! -f "$WHISPER_DIR/build/bin/whisper-cli" ]; then
  echo "→ Cloning whisper.cpp..."
  if [ ! -d "$WHISPER_DIR/.git" ]; then
    git clone https://github.com/ggml-org/whisper.cpp "$WHISPER_DIR"
  fi
  echo "→ Building whisper.cpp (this may take a few minutes)..."
  cmake \
    -S "$WHISPER_DIR" \
    -B "$WHISPER_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON
  cmake --build "$WHISPER_DIR/build" --config Release -j
  echo "✓ whisper.cpp built."
else
  echo "✓ whisper.cpp already built, skipping."
fi

# ── model download ────────────────────────────────────────────────────────────

MODEL_FILE="$WHISPER_DIR/models/ggml-${MODEL_NAME}.bin"
if [ ! -f "$MODEL_FILE" ]; then
  echo "→ Downloading model: ggml-${MODEL_NAME}..."
  bash "$WHISPER_DIR/models/download-ggml-model.sh" "$MODEL_NAME"
  echo "✓ Model downloaded."
else
  echo "✓ Model already present, skipping."
fi

# ── python venv ───────────────────────────────────────────────────────────────

echo "→ Setting up Python venv..."
python3 -m venv "$BASE/venv"
"$BASE/venv/bin/pip" install --quiet --upgrade pip
"$BASE/venv/bin/pip" install --quiet rapidfuzz
echo "✓ Python venv ready."

# ── scripts ───────────────────────────────────────────────────────────────────

echo "→ Installing scripts..."
fetch scripts/format.py     "$BASE/format.py"
fetch scripts/learn.py      "$BASE/learn.py"
fetch scripts/transcribe.sh "$BASE/transcribe.sh"
chmod +x "$BASE/transcribe.sh"

# config: always refresh the prompt, never overwrite an existing learned vocab
fetch config/whisper_prompt.txt "$BASE/config/whisper_prompt.txt"
if [ ! -f "$BASE/config/vocab.json" ]; then
  fetch config/vocab.json "$BASE/config/vocab.json"
fi

# ── hammerspoon ───────────────────────────────────────────────────────────────

echo "→ Installing Hammerspoon config..."
fetch hammerspoon/whisp.lua "$BASE/whisp.lua"

# Detect rec binary path (sox) — works on both Apple Silicon and Intel Macs
REC_PATH="$(brew --prefix)/bin/rec"

# Write Lua config (keys + paths read by whisp.lua at runtime)
cat > "$BASE/config.lua" <<LUA
-- Auto-generated by install.sh — re-run install.sh to update these values.
return {
  record      = "$RECORD_KEY",
  record_mods = $RECORD_MODS,
  learn       = "$LEARN_KEY",
  learn_mods  = $LEARN_MODS,
  sox_rec     = "$REC_PATH",
}
LUA

# Inject a single dofile() line into ~/.hammerspoon/init.lua
mkdir -p "$HOME/.hammerspoon"
touch "$HAMMERSPOON_INIT"
DOFILE_LINE='dofile(os.getenv("HOME") .. "/.whisp/whisp.lua")'
if ! grep -qF "$DOFILE_LINE" "$HAMMERSPOON_INIT"; then
  printf '\n\n-- whisp\n%s\n' "$DOFILE_LINE" >> "$HAMMERSPOON_INIT"
  echo "✓ Injected whisp into ~/.hammerspoon/init.lua."
else
  echo "✓ Hammerspoon already configured, skipping."
fi

# Write shell config (sourced by transcribe.sh)
cat > "$BASE/config.sh" <<SH
WHISP_WHISPER="$WHISPER_DIR/build/bin/whisper-cli"
WHISP_MODEL="$MODEL_FILE"
WHISP_VENV="$BASE/venv"
SH

echo ""
echo "✓ Whisp installed successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Required: macOS permissions (one-time setup)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Open Hammerspoon (it may already be in your menu bar)."
echo ""
echo "  2. Grant Accessibility access (required to simulate keypresses):"
echo "       System Settings → Privacy & Security → Accessibility"
echo "       → enable Hammerspoon"
echo ""
echo "  3. Grant Microphone access (required to record audio):"
echo "       System Settings → Privacy & Security → Microphone"
echo "       → enable Hammerspoon"
echo ""
echo "  4. Reload the Hammerspoon config:"
echo "       Click the Hammerspoon menu bar icon → Reload Config"
echo "       (or press Cmd+Ctrl+R inside Hammerspoon)"
echo ""
echo "  5. Set Hammerspoon to start at login so Whisp is always available:"
echo "       System Settings → General → Login Items & Extensions"
echo "       → click + and add Hammerspoon"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Usage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Hold $RECORD_KEY   → speak → release   (dictate and paste)"
echo "  Select corrected text → press $LEARN_KEY   (teach a correction)"
echo ""
