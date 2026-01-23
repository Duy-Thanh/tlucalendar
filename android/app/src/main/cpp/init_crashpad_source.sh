#!/bin/bash
set -e

# Define directories
CPP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRASHPAD_DIR="$CPP_DIR/crashpad"
MINI_CHROMIUM_DIR="$CPP_DIR/crashpad/third_party/mini_chromium/mini_chromium"

echo "Downloading Crashpad sources to $CRASHPAD_DIR..."

# Clone Crashpad if not exists
if [ ! -d "$CRASHPAD_DIR" ]; then
    git clone https://chromium.googlesource.com/crashpad/crashpad.git "$CRASHPAD_DIR"
    # Checkout a relatively stable recent hash to ensure reproducibility 
    # (Optional, but good practice. Using a recent one from late 2024/2025 if possible, or just HEAD)
    # cd "$CRASHPAD_DIR" && git checkout <some_hash>
else
    echo "Crashpad directory already exists."
fi

# Clone Mini Chromium (dependency)
mkdir -p "$CPP_DIR/crashpad/third_party/mini_chromium"

if [ ! -d "$MINI_CHROMIUM_DIR" ]; then
    echo "Downloading Mini Chromium..."
    git clone https://chromium.googlesource.com/chromium/mini_chromium "$MINI_CHROMIUM_DIR"
else
     echo "Mini Chromium directory already exists."
fi

echo "Done. Crashpad sources are ready."
