#!/usr/bin/env bash
set -euo pipefail
CONFIG="${1:-config.yaml}"
if [ ! -f "$CONFIG" ]; then echo "Config file $CONFIG missing"; exit 1; fi

AWS_REGION=$(yq -r '.aws_region' $CONFIG 2>/dev/null || python3 -c "import yaml,sys;print(yaml.safe_load(open('$CONFIG'))['aws_region'])")
DOC=$(yq -r '.snapshot_document' $CONFIG 2>/dev/null || python3 - <<PY
import yaml
print(yaml.safe_load(open("$CONFIG"))["snapshot_document"])
PY)

INSTANCE_ID=$(yq -r '.secondary_instance_id' $CONFIG 2>/dev/null || python3 - <<PY
import yaml
print(yaml.safe_load(open("$CONFIG"))["secondary_instance_id"])
PY)

echo "Sending snapshot SSM document '$DOC' to instance $INSTANCE_ID in region $AWS_REGION"
CMD_ID=$(aws ssm send-command --document-name "$DOC" --instance-ids "$INSTANCE_ID" --comment "Snapshot Mongo secondary" --region "$AWS_REGION" --query "Command.CommandId" --output text)
echo "Command ID: $CMD_ID"
echo "Waiting for command to reach status 'Success' or 'Failed'..."
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" --region "$AWS_REGION"
aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" --region "$AWS_REGION" --output text
echo "Snapshot command finished. Cloud-native snapshot creation is asynchronous — check EC2 snapshots console for snapshot id(s)."
