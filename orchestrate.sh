#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-config.yaml}"

if [ ! -f "$CONFIG" ]; then
  echo "❌ Config file '$CONFIG' not found."
  echo "Usage: ./orchestrate.sh config.yaml"
  exit 1
fi

echo "Using config: $CONFIG"

echo "Step 1 — Triggering snapshot on secondary..."
./scripts/trigger_snapshot.sh "$CONFIG"
echo "Snapshot step completed."

echo "Step 2 — Restoring latest snapshot to staging..."
./scripts/trigger_restore.sh "$CONFIG"
echo "Restore step completed."

echo "Step 3 — Running anonymizer on staging..."
python3 ./scripts/anonymize_staging.py --config "$CONFIG"
echo "Anonymization complete."

echo "Step 4 — Validating restore..."
./scripts/validate_restore.sh "$CONFIG"
echo "Validation script executed."

