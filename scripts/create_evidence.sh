#!/usr/bin/env bash
set -euo pipefail

# Master script to create E01 evidence file from project evidence
# Usage: ./create_evidence.sh [output_dir] [case_name]

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR=${1:-./evidence_package}
CASE_NAME=${2:-csdf_case_$(date +%Y%m%d_%H%M%S)}

echo "=========================================="
echo "E01 Evidence File Creation"
echo "=========================================="
echo ""

# Step 1: Prepare evidence
echo "Step 1: Preparing evidence directory..."
"$PROJECT_ROOT/scripts/prepare_evidence.sh" "$OUTPUT_DIR" "$CASE_NAME"

if [ $? -ne 0 ]; then
    echo "Error: Failed to prepare evidence"
    exit 1
fi

echo ""
echo "Step 2: Creating E01 file..."
"$PROJECT_ROOT/scripts/create_e01.sh" "$OUTPUT_DIR" "$CASE_NAME" "${CASE_NAME}.E01"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create E01 file"
    exit 1
fi

echo ""
echo "=========================================="
echo "Evidence file created successfully!"
echo "=========================================="
echo ""
echo "E01 File: ${CASE_NAME}.E01"
echo ""
echo "To examine the evidence:"
echo "  sudo ./scripts/examine_evidence.sh ${CASE_NAME}.E01"
echo ""
echo "To verify the E01 file:"
echo "  ewfverify ${CASE_NAME}.E01"
echo ""

