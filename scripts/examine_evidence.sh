#!/usr/bin/env bash
set -euo pipefail

# Script to examine E01 evidence file
# Usage: ./examine_evidence.sh <evidence.E01> [mount_point]

E01_FILE=${1:-}
MOUNT_POINT=${2:-/tmp/ewf_mount}

if [ -z "$E01_FILE" ]; then
    echo "Usage: $0 <evidence.E01> [mount_point]"
    echo ""
    echo "This script will:"
    echo "  1. Mount the E01 file"
    echo "  2. Extract the evidence"
    echo "  3. Provide an interactive shell to examine it"
    exit 1
fi

if [ ! -f "$E01_FILE" ]; then
    echo "Error: E01 file not found: $E01_FILE"
    exit 1
fi

# Check if ewfmount is available
if ! command -v ewfmount &> /dev/null; then
    echo "Error: ewfmount not found. Please install libewf:"
    echo "  Arch: sudo pacman -S libewf"
    echo "  Debian/Ubuntu: sudo apt-get install libewf-tools"
    exit 1
fi

# Check if running as root (needed for mounting)
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges for mounting."
    echo "Please run with sudo:"
    echo "  sudo $0 $E01_FILE $MOUNT_POINT"
    exit 1
fi

EXTRACT_DIR="/tmp/evidence_extracted_$(basename "$E01_FILE" .E01)"

echo "Examining E01 evidence file: $E01_FILE"
echo "Mount point: $MOUNT_POINT"
echo "Extraction directory: $EXTRACT_DIR"
echo ""

# Create mount point (ensure it's empty)
if [ -d "$MOUNT_POINT" ] && [ "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
    echo "Cleaning mount point..."
    rm -rf "$MOUNT_POINT"/*
fi
mkdir -p "$MOUNT_POINT"
mkdir -p "$EXTRACT_DIR"

# Track ewfmount PID for cleanup (if using mount method)
EWFMOUNT_PID_STORED=""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Cleaning up..."
    # Kill ewfmount process if it's running (from mount method)
    if [ -n "$EWFMOUNT_PID_STORED" ] && kill -0 "$EWFMOUNT_PID_STORED" 2>/dev/null; then
        kill "$EWFMOUNT_PID_STORED" 2>/dev/null || true
        sleep 1
    fi
    # Try to unmount if we used mount method
    MOUNT_POINT_ABS=$(readlink -f "$MOUNT_POINT" 2>/dev/null || echo "$MOUNT_POINT")
    if mountpoint -q "$MOUNT_POINT_ABS" 2>/dev/null; then
        umount "$MOUNT_POINT_ABS" 2>/dev/null || true
        fusermount -u "$MOUNT_POINT_ABS" 2>/dev/null || true
    fi
    rmdir "$MOUNT_POINT_ABS" 2>/dev/null || true
    # Clean up any log files
    rm -f /tmp/ewfmount_*.log
    echo "Cleanup complete."
}

trap cleanup EXIT INT TERM

# Extract the E01 file
echo "Extracting E01 file..."
# Get absolute paths
E01_FILE_ABS=$(readlink -f "$E01_FILE" || echo "$E01_FILE")

# Check if ewfexport is available (preferred method, doesn't require FUSE)
if command -v ewfexport &> /dev/null; then
    echo "Using ewfexport to extract E01 file..."
    RAW_FILE="$EXTRACT_DIR/evidence.raw"
    # ewfexport is interactive, so we need to pipe answers
    # Order: segment size (0 = unlimited), start offset (0), bytes to export (empty = all), then it auto-confirms
    printf "0\n0\n\n" | ewfexport -f raw -t "$RAW_FILE" "$E01_FILE_ABS" > /tmp/ewfexport_$$.log 2>&1
    
    if [ -f "$RAW_FILE" ]; then
        echo "✓ E01 file extracted successfully"
        # The raw file is actually our tar.gz
        mv "$RAW_FILE" "$EXTRACT_DIR/evidence.tar.gz"
        rm -f /tmp/ewfexport_$$.log
    else
        echo "Error: ewfexport failed to create output file"
        echo "ewfexport output:"
        cat /tmp/ewfexport_$$.log 2>/dev/null || true
        rm -f /tmp/ewfexport_$$.log
        exit 1
    fi
# Fallback to ewfmount if FUSE is available
elif command -v ewfmount &> /dev/null && lsmod | grep -q "^fuse"; then
    echo "Using ewfmount (FUSE method)..."
    MOUNT_POINT_ABS=$(readlink -f "$MOUNT_POINT" || echo "$MOUNT_POINT")
    
    # ewfmount runs as a daemon, so we need to run it in background and wait for mount
    ewfmount -f files -v "$E01_FILE_ABS" "$MOUNT_POINT_ABS" > /tmp/ewfmount_$$.log 2>&1 &
    EWFMOUNT_PID=$!
    
    # Wait for the mount to be ready (check for ewf1 file)
    echo "Waiting for mount to be ready..."
    MAX_WAIT=10
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if [ -f "$MOUNT_POINT_ABS/ewf1" ]; then
            break
        fi
        if ! kill -0 "$EWFMOUNT_PID" 2>/dev/null; then
            echo "Warning: ewfmount process exited early"
            wait $EWFMOUNT_PID 2>/dev/null
            break
        fi
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        echo -n "."
    done
    echo ""
    
    if [ -f "$MOUNT_POINT_ABS/ewf1" ]; then
        echo "✓ E01 file mounted successfully"
        cp "$MOUNT_POINT_ABS/ewf1" "$EXTRACT_DIR/evidence.tar.gz"
        # Store PID for cleanup
        EWFMOUNT_PID_STORED=$EWFMOUNT_PID
    else
        echo "Error: Failed to mount E01 file"
        cat /tmp/ewfmount_$$.log 2>/dev/null || true
        kill $EWFMOUNT_PID 2>/dev/null || true
        rm -f /tmp/ewfmount_$$.log
        exit 1
    fi
    rm -f /tmp/ewfmount_$$.log
else
    echo "Error: Neither ewfexport nor ewfmount (with FUSE) is available"
    echo "Please install libewf-tools and ensure FUSE is loaded, or use ewfexport"
    exit 1
fi

echo ""

# Extract the tar archive
echo "Extracting evidence archive..."
if tar -xzf "$EXTRACT_DIR/evidence.tar.gz" -C "$EXTRACT_DIR" 2>/dev/null; then
    echo "✓ Evidence extracted successfully"
else
    # If extraction fails, try to find the correct size
    echo "Attempting to find correct extraction size..."
    FILE_SIZE=$(stat -c%s "$EXTRACT_DIR/evidence.tar.gz")
    
    # Try different sizes around the file size
    for size in $FILE_SIZE $((FILE_SIZE - 100)) $((FILE_SIZE - 50)) $((FILE_SIZE + 50)) $((FILE_SIZE + 100)); do
        if dd if="$EXTRACT_DIR/evidence.tar.gz" bs=1 count=$size of="$EXTRACT_DIR/evidence_fixed.tar.gz" 2>/dev/null; then
            if tar -tzf "$EXTRACT_DIR/evidence_fixed.tar.gz" >/dev/null 2>&1; then
                tar -xzf "$EXTRACT_DIR/evidence_fixed.tar.gz" -C "$EXTRACT_DIR"
                echo "✓ Evidence extracted successfully (using size: $size)"
                break
            fi
        fi
    done
fi

# Find the extracted case directory
CASE_DIR=$(find "$EXTRACT_DIR" -maxdepth 2 -type d -name "*case*" | head -1)
if [ -z "$CASE_DIR" ]; then
    CASE_DIR="$EXTRACT_DIR"
fi

echo ""
echo "Evidence extracted to: $CASE_DIR"
echo ""
echo "Evidence contents:"
ls -lh "$CASE_DIR" | head -20
echo ""

# Show summary if available
if [ -f "$CASE_DIR/EVIDENCE_SUMMARY.txt" ]; then
    echo "Evidence Summary:"
    echo "================="
    cat "$CASE_DIR/EVIDENCE_SUMMARY.txt"
    echo ""
fi

# Show metadata if available
if [ -f "$CASE_DIR/CASE_METADATA.txt" ]; then
    echo "Case Metadata:"
    echo "=============="
    head -20 "$CASE_DIR/CASE_METADATA.txt"
    echo ""
fi

# Show auth.log preview if available
if [ -f "$CASE_DIR/var/log/auth.log" ]; then
    echo "Auth.log preview (first 20 lines):"
    echo "=================================="
    head -20 "$CASE_DIR/var/log/auth.log"
    echo ""
    echo "Auth.log statistics:"
    echo "  Total lines: $(wc -l < "$CASE_DIR/var/log/auth.log")"
    echo "  Failed attempts: $(grep -c "Failed password" "$CASE_DIR/var/log/auth.log" 2>/dev/null || echo "0")"
    echo "  Successful logins: $(grep -c "Accepted password" "$CASE_DIR/var/log/auth.log" 2>/dev/null || echo "0")"
    echo ""
fi

echo "Evidence is available at: $CASE_DIR"
echo ""
echo "You can now examine the evidence. The E01 file will remain mounted"
echo "until you press Ctrl+C or exit this script."
echo ""
if [ -n "$EWFMOUNT_PID_STORED" ]; then
    echo "To manually unmount later, run:"
    echo "  sudo fusermount -u $MOUNT_POINT_ABS"
    echo "  or"
    echo "  sudo umount $MOUNT_POINT_ABS"
fi
echo ""
read -p "Press Enter to continue examining (or Ctrl+C to exit and unmount)..."

