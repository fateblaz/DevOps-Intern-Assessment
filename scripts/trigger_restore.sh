#!/usr/bin/env bash
set -euo pipefail
CONFIG="${1:-config.yaml}"
if [ ! -f "$CONFIG" ]; then echo "Config file $CONFIG missing"; exit 1; fi

AWS_REGION=$(python3 - <<PY
import yaml,sys
cfg=yaml.safe_load(open("$CONFIG"))
print(cfg.get("aws_region"))
PY)

DOC=$(python3 - <<PY
import yaml
cfg=yaml.safe_load(open("$CONFIG"))
print(cfg.get("restore_document"))
PY)

INSTANCE_ID=$(python3 - <<PY
import yaml
cfg=yaml.safe_load(open("$CONFIG"))
print(cfg.get("staging_instance_id"))
PY)

echo "Sending restore SSM document '$DOC' to staging instance $INSTANCE_ID in region $AWS_REGION"
CMD_ID=$(aws ssm send-command --document-name "$DOC" --instance-ids "$INSTANCE_ID" --comment "Restore latest Mongo snapshot to staging" --region "$AWS_REGION" --query "Command.CommandId" --output text)
echo "Command ID: $CMD_ID"
echo "Waiting for command to reach status 'Success' or 'Failed'..."
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" --region "$AWS_REGION"
aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" --region "$AWS_REGION" --output text
echo "Restore command finished. Check staging mongo logs and service status."
