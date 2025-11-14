#!/usr/bin/env bash
set -euo pipefail

# Script to prepare evidence directory structure for E01 creation
# Usage: ./prepare_evidence.sh [output_dir] [case_name]

OUTPUT_DIR=${1:-./evidence_package}
CASE_NAME=${2:-csdf_case_$(date +%Y%m%d_%H%M%S)}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Preparing evidence package: $CASE_NAME"
echo "Output directory: $OUTPUT_DIR"

# Create evidence directory structure
EVIDENCE_DIR="$OUTPUT_DIR/$CASE_NAME"
mkdir -p "$EVIDENCE_DIR/var/log"
mkdir -p "$EVIDENCE_DIR/etc"
mkdir -p "$EVIDENCE_DIR/root/.ssh"
mkdir -p "$EVIDENCE_DIR/home/vb11x/Downloads/csdf-project"

# Copy main evidence files
echo "Copying evidence files..."

# Main log file (primary evidence)
if [ -f "$PROJECT_ROOT/auth.log" ]; then
    cp "$PROJECT_ROOT/auth.log" "$EVIDENCE_DIR/var/log/auth.log"
    echo "  ✓ Copied auth.log"
else
    echo "  ⚠ Warning: auth.log not found"
fi

# Configuration files
if [ -f "$PROJECT_ROOT/logstash.conf" ]; then
    cp "$PROJECT_ROOT/logstash.conf" "$EVIDENCE_DIR/etc/logstash.conf"
    echo "  ✓ Copied logstash.conf"
fi

if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    cp "$PROJECT_ROOT/docker-compose.yml" "$EVIDENCE_DIR/etc/docker-compose.yml"
    echo "  ✓ Copied docker-compose.yml"
fi

# Project files
if [ -f "$PROJECT_ROOT/gen_fake_ssh_attacks.sh" ]; then
    cp "$PROJECT_ROOT/gen_fake_ssh_attacks.sh" "$EVIDENCE_DIR/home/vb11x/Downloads/csdf-project/gen_fake_ssh_attacks.sh"
    echo "  ✓ Copied gen_fake_ssh_attacks.sh"
fi

# Create hash file first (before metadata that references it)
echo "Calculating file hashes..."
(cd "$EVIDENCE_DIR" && find . -type f ! -name "HASHES.txt" ! -name "CASE_METADATA.txt" ! -name "EVIDENCE_SUMMARY.txt" -exec sha256sum {} \; > "./HASHES.txt" 2>/dev/null || echo "Hash calculation failed" > "./HASHES.txt")

# Create case metadata
cat > "$EVIDENCE_DIR/CASE_METADATA.txt" <<EOF
Case Information
================
Case Name: $CASE_NAME
Collection Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Collection System: $(hostname 2>/dev/null || uname -n)
Collector: $(whoami)

Evidence Description
===================
This evidence package contains simulated SSH attack logs and related
configuration files from a cybersecurity forensics exercise.

Contents:
- /var/log/auth.log: SSH authentication logs with simulated attack attempts
- /etc/logstash.conf: Logstash configuration for log parsing
- /etc/docker-compose.yml: Docker Compose configuration for ELK stack
- /home/vb11x/Downloads/csdf-project/: Project files including attack generator

Hash Information
================
$(cat "$EVIDENCE_DIR/HASHES.txt" 2>/dev/null || echo "Hash information not available")

Collection Notes
================
This evidence was collected as part of a digital forensics exercise.
The auth.log file contains simulated SSH brute-force attack attempts
generated for training purposes.

EOF

echo "  ✓ Created CASE_METADATA.txt"
echo "  ✓ Created HASHES.txt"

# Create a summary report
cat > "$EVIDENCE_DIR/EVIDENCE_SUMMARY.txt" <<EOF
Evidence Summary Report
=======================
Case: $CASE_NAME
Date: $(date)

File Statistics:
$(cd "$EVIDENCE_DIR" && find . -type f -exec ls -lh {} \; | awk '{print $5, $9}')

Log Analysis (if auth.log exists):
$(if [ -f "$EVIDENCE_DIR/var/log/auth.log" ]; then
    echo "Total lines: $(wc -l < "$EVIDENCE_DIR/var/log/auth.log")"
    echo "Failed login attempts: $(grep -c "Failed password" "$EVIDENCE_DIR/var/log/auth.log" 2>/dev/null || echo "0")"
    echo "Successful logins: $(grep -c "Accepted password" "$EVIDENCE_DIR/var/log/auth.log" 2>/dev/null || echo "0")"
    echo "Unique source IPs: $(grep -oP 'from \K[0-9.]+' "$EVIDENCE_DIR/var/log/auth.log" 2>/dev/null | sort -u | wc -l || echo "0")"
fi)

EOF

echo "  ✓ Created EVIDENCE_SUMMARY.txt"

echo ""
echo "Evidence package prepared successfully!"
echo "Location: $EVIDENCE_DIR"
echo ""
echo "Next step: Run ./scripts/create_e01.sh $OUTPUT_DIR $CASE_NAME"

