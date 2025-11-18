{
  "schemaVersion": "2.2",
  "description": "Snapshot MongoDB EBS volumes fsyncLock -> snapshot -> fsyncUnlock.",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "snapshotMongo",
      "inputs": {
        "runCommand": [
          "#!/bin/bash -e",
          "AWS_REGION=\"${aws_region}\"",
          "SNAP_TAG=\"${name_prefix}-mongo-weekly-$(date -u +%Y%m%dT%H%M%SZ)\"",
          "echo \"Starting fsyncLock...\"",
          "mongo --quiet --eval \"db.getSiblingDB('admin').runCommand({fsync:1, lock:true})\"",
          "INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
          "echo \"Instance: $INSTANCE_ID\"",
          "VOLUMES=$(aws ec2 describe-volumes --region ${AWS_REGION} --filters Name=attachment.instance-id,Values=$INSTANCE_ID --query 'Volumes[].VolumeId' --output text)",
          "for VOL in $VOLUMES; do",
          "  echo \"Creating snapshot for volume $VOL\"",
          "  SNAP_ID=$(aws ec2 create-snapshot --region ${AWS_REGION} --volume-id $VOL --description \"${name_prefix}-mongo-weekly snapshot ${VOL}\" --query SnapshotId --output text)",
          "  aws ec2 create-tags --region ${AWS_REGION} --resources $SNAP_ID --tags Key=Name,Value=${name_prefix}-mongo-weekly Key=env,Value=prod || true",
          "  echo \"Snapshot initiated: $SNAP_ID\"",
          "done",
          "echo \"Releasing fsyncLock...\"",
          "mongo --quiet --eval \"db.getSiblingDB('admin').runCommand({fsyncUnlock:1})\"",
          "echo \"Done. Snapshots started.\""
        ]
      }
    }
  ]
}
