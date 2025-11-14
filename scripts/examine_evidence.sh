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

# Create mount point
mkdir -p "$MOUNT_POINT"
mkdir -p "$EXTRACT_DIR"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Cleaning up..."
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        umount "$MOUNT_POINT" 2>/dev/null || true
    fi
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    echo "Cleanup complete."
}

trap cleanup EXIT INT TERM

# Mount the E01 file
echo "Mounting E01 file..."
ewfmount -f files "$E01_FILE" "$MOUNT_POINT"

if [ ! -f "$MOUNT_POINT/ewf1" ]; then
    echo "Error: Failed to mount E01 file or ewf1 not found"
    exit 1
fi

echo "✓ E01 file mounted successfully"
echo ""

# Extract the evidence
echo "Extracting evidence..."
# The ewf1 file is actually the tar.gz file we created
cp "$MOUNT_POINT/ewf1" "$EXTRACT_DIR/evidence.tar.gz"

# Try to extract
if tar -xzf "$EXTRACT_DIR/evidence.tar.gz" -C "$EXTRACT_DIR" 2>/dev/null; then
    echo "✓ Evidence extracted successfully"
else
    # If extraction fails, try to find the correct size
    echo "Attempting to find correct extraction size..."
    FILE_SIZE=$(stat -c%s "$EXTRACT_DIR/evidence.tar.gz")
    
    # Try different sizes around the file size
    for size in $FILE_SIZE $((FILE_SIZE - 100)) $((FILE_SIZE - 50)) $((FILE_SIZE + 50)) $((FILE_SIZE + 100)); do
        if dd if="$MOUNT_POINT/ewf1" bs=1 count=$size of="$EXTRACT_DIR/evidence_fixed.tar.gz" 2>/dev/null; then
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
echo "To manually unmount later, run:"
echo "  sudo umount $MOUNT_POINT"
echo ""
read -p "Press Enter to continue examining (or Ctrl+C to exit and unmount)..."

