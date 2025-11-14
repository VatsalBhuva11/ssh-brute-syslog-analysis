#!/usr/bin/env bash
set -euo pipefail

# Script to create E01 evidence file from prepared evidence directory
# Usage: ./create_e01.sh [evidence_dir] [case_name] [output_e01_name]

EVIDENCE_DIR=${1:-./evidence_package}
CASE_NAME=${2:-$(ls -t "$EVIDENCE_DIR" 2>/dev/null | head -1 || echo "csdf_case")}
# Remove .E01 extension if present, as ewfacquire will add it
OUTPUT_BASE=${3:-${CASE_NAME}}
OUTPUT_BASE=${OUTPUT_BASE%.E01}
OUTPUT_NAME="${OUTPUT_BASE}.E01"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_PATH="$EVIDENCE_DIR/$CASE_NAME"

# Check if evidence directory exists
if [ ! -d "$EVIDENCE_PATH" ]; then
    echo "Error: Evidence directory not found: $EVIDENCE_PATH"
    echo "Run ./scripts/prepare_evidence.sh first"
    exit 1
fi

# Check if ewfacquire is available
if ! command -v ewfacquire &> /dev/null; then
    echo "Error: ewfacquire not found. Please install libewf:"
    echo "  Arch: sudo pacman -S libewf"
    echo "  Debian/Ubuntu: sudo apt-get install libewf-tools"
    exit 1
fi

echo "Creating E01 evidence file..."
echo "Evidence source: $EVIDENCE_PATH"
echo "Output file: $OUTPUT_NAME"

# Create a tar archive of the evidence first (E01 works better with single files)
TAR_FILE="/tmp/${CASE_NAME}_evidence.tar.gz"
echo "Creating tar archive..."
tar -czf "$TAR_FILE" -C "$EVIDENCE_DIR" "$CASE_NAME"

# Get file size for E01 creation
FILE_SIZE=$(stat -c%s "$TAR_FILE")
echo "Archive size: $FILE_SIZE bytes"

# Create E01 file from the tar archive
# Using 'files' format since we're imaging a file, not a disk
echo ""
echo "Creating E01 file (this may take a moment)..."
echo "Case: $CASE_NAME"
echo "Description: SSH Attack Logs - Simulated Evidence"

# Use ewfacquire with files format
# Note: ewfacquire automatically appends .E01 to the target name, so we don't include it
# Also, ewfacquire is interactive by default, so we need to pipe responses
echo "0
$FILE_SIZE
512
64
64
2
no
yes" | ewfacquire \
    -f files \
    -c bzip2 \
    -S "$FILE_SIZE" \
    -e "$(whoami)" \
    -m removable \
    -M logical \
    -l "${OUTPUT_BASE}.E01.log" \
    -D "SSH Attack Logs - Simulated Evidence for Case: $CASE_NAME" \
    -C "$CASE_NAME" \
    -N "Evidence collection from $(hostname 2>/dev/null || uname -n) on $(date)" \
    -E "Digital forensics exercise - SSH attack simulation" \
    -t "$OUTPUT_BASE" \
    "$TAR_FILE"

# Clean up temporary tar file
rm -f "$TAR_FILE"

# Verify the E01 file was created (ewfacquire appends .E01 to the target name)
E01_FILE="${OUTPUT_BASE}.E01"
if [ -f "$E01_FILE" ]; then
    E01_SIZE=$(stat -c%s "$E01_FILE")
    echo ""
    echo "✓ E01 file created successfully!"
    echo "  File: $E01_FILE"
    echo "  Size: $E01_SIZE bytes ($(numfmt --to=iec-i --suffix=B $E01_SIZE 2>/dev/null || echo "${E01_SIZE} bytes"))"
    echo ""
    echo "To examine the evidence, run:"
    echo "  sudo ./scripts/examine_evidence.sh $E01_FILE"
    echo ""
    echo "To verify the E01 file:"
    echo "  ewfverify $E01_FILE"
else
    echo "Error: E01 file was not created: $E01_FILE"
    echo "Checking for alternative filenames..."
    ls -lh "${OUTPUT_BASE}"* 2>/dev/null || true
    exit 1
fi

