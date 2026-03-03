#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Sight Words — Generate All Audio
#  Run this ONCE from the sight_words/ project root.
# ═══════════════════════════════════════════════════════════════
#
#  Prerequisites:
#    pip install requests
#    ffmpeg must be installed (sudo apt install ffmpeg / brew install ffmpeg)
#
#  Usage:
#    ./scripts/generate_audio.sh YOUR_GEMINI_API_KEY
#
# ═══════════════════════════════════════════════════════════════

set -e

API_KEY="${1:-$GEMINI_API_KEY}"

if [ -z "$API_KEY" ]; then
    echo "❌ Usage: ./scripts/generate_audio.sh YOUR_GEMINI_API_KEY"
    echo "   Or:   export GEMINI_API_KEY=... && ./scripts/generate_audio.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔊 Generating ALL audio with Gemini 2.5 Flash TTS (voice: Kore)"
echo "   This takes ~15-20 minutes on a paid API key."
echo ""

python3 "$SCRIPT_DIR/generate_tts_gemini.py" \
    --api-key "$API_KEY" \
    --voice Kore \
    --output "$SCRIPT_DIR/../assets/audio" \
    --rpm 15

echo ""
echo "🎉 Done! Now build the app:"
echo "   flutter pub get"
echo "   flutter run"
