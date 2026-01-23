#!/bin/bash
set -e

# Define directories
CPP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRASHPAD_DIR="$CPP_DIR/crashpad"
MINI_CHROMIUM_DIR="$CPP_DIR/crashpad/third_party/mini_chromium/mini_chromium"

echo "Downloading Crashpad sources to $CRASHPAD_DIR..."

# Clone Crashpad if not exists
if [ ! -d "$CRASHPAD_DIR" ]; then
    git clone --recursive https://chromium.googlesource.com/crashpad/crashpad.git "$CRASHPAD_DIR"
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
    git clone --recursive https://chromium.googlesource.com/chromium/mini_chromium "$MINI_CHROMIUM_DIR"
else
     echo "Mini Chromium directory already exists."
fi

# Clone Linux Syscall Support (LSS) - Required for Android/Linux
LSS_DIR="$CRASHPAD_DIR/third_party/lss/lss"
if [ ! -d "$LSS_DIR" ]; then
    echo "Downloading LSS..."
    mkdir -p "$LSS_DIR"
    # Clone into temp and move files to avoid 'non-empty dir' git errors if any specific issues arise, 
    # but cloning into empty dir is fine.
    git clone https://chromium.googlesource.com/linux-syscall-support "$LSS_DIR"
else
    echo "LSS directory already exists."
fi

# Clone Zlib - Crashpad needs it
ZLIB_DIR="$CRASHPAD_DIR/third_party/zlib/zlib"
if [ ! -d "$ZLIB_DIR" ]; then
    echo "Downloading Zlib..."
    mkdir -p "$ZLIB_DIR"
    git clone https://chromium.googlesource.com/chromium/src/third_party/zlib "$ZLIB_DIR"
else
    echo "Zlib directory already exists."
fi

# Patch zlib_output_stream.cc for const correctness (Android NDK / newer clang issue)
# Error: assigning to 'Bytef *' (aka 'unsigned char *') from 'const uint8_t *'
ZLIB_OUTPUT_STREAM="$CRASHPAD_DIR/util/stream/zlib_output_stream.cc"
if [ -f "$ZLIB_OUTPUT_STREAM" ]; then
    echo "Patching zlib_output_stream.cc..."
    # Use sed to cast data to Bytef* (removing const)
    sed -i 's/zlib_stream_.next_in = data;/zlib_stream_.next_in = const_cast<Bytef*>(data);/g' "$ZLIB_OUTPUT_STREAM"
else
    echo "Warning: zlib_output_stream.cc not found, cannot patch."
fi

# Patch system_snapshot_linux.cc to disable __system_property_read_callback (API 26+)
# This function is not available on Android 24, causing build failure.
SYSTEM_SNAPSHOT_LINUX="$CRASHPAD_DIR/snapshot/linux/system_snapshot_linux.cc"
if [ -f "$SYSTEM_SNAPSHOT_LINUX" ]; then
    echo "Patching system_snapshot_linux.cc (disable __system_property_read_callback)..."
    # Comment out the line: __system_property_read_callback(prop, ReadPropertyCallback, &data);
    # matches the function call and replaces it with // comment
    sed -i 's/__system_property_read_callback(prop, ReadPropertyCallback, &data);/\/\/ __system_property_read_callback(prop, ReadPropertyCallback, \&data);/g' "$SYSTEM_SNAPSHOT_LINUX"
else
    echo "Warning: system_snapshot_linux.cc not found, cannot patch."
fi

echo "Done. Crashpad sources are ready."
