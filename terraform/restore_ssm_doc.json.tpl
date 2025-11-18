{
  "schemaVersion": "2.2",
  "description": "Restore latest Mongo weekly snapshot to staging instance (create volume from snapshot -> attach -> copy data -> restart docker container).",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "restoreMongo",
      "inputs": {
        "runCommand": [
          "#!/bin/bash -e",
          "AWS_REGION=\"${aws_region}\"",
          "TAG_PREFIX=\"${name_prefix}-mongo-weekly-\"",
          "echo \"Finding latest snapshot tagged with Name starting with ${name_prefix}-mongo-weekly-\"",
          "SNAP_ID=$(aws ec2 describe-snapshots --region ${AWS_REGION} --filters Name=tag:Name,Values=${name_prefix}-mongo-weekly-* Name=tag:env,Values=prod --query 'Snapshots | sort_by(@, &StartTime) | [-1].SnapshotId' --output text)",
          "if [ -z \"$SNAP_ID\" ] || [ \"$SNAP_ID\" = \"None\" ]; then echo \"No snapshot found\"; exit 2; fi",
          "echo \"Latest snapshot: $SNAP_ID\"",
          "AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)",
          "echo \"Creating volume in $AZ from snapshot $SNAP_ID\"",
          "VOL_ID=$(aws ec2 create-volume --region ${AWS_REGION} --snapshot-id $SNAP_ID --availability-zone $AZ --volume-type gp3 --query VolumeId --output text)",
          "echo \"Waiting for volume to become available: $VOL_ID\"",
          "aws ec2 wait volume-available --region ${AWS_REGION} --volume-ids $VOL_ID",
          "INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
          "DEVICE=/dev/xvdf",
          "echo \"Attaching volume $VOL_ID to instance $INSTANCE_ID as $DEVICE\"",
          "aws ec2 attach-volume --region ${AWS_REGION} --volume-id $VOL_ID --instance-id $INSTANCE_ID --device $DEVICE",
          "sleep 5",
          "sudo mkdir -p /mnt/mongo-snap",
          "sudo mount $DEVICE /mnt/mongo-snap",
          "echo \"Stopping mongo docker container if running\"",
          "docker stop mongo || true",
          "echo \"Syncing snapshot data to /data/mongo\"",
          "sudo mkdir -p /data/mongo",
          "sudo rsync -aH /mnt/mongo-snap/ /data/mongo/",
          "sudo chown -R 999:999 /data/mongo || true",
          "echo \"Unmounting snapshot volume\"",
          "sudo umount /mnt/mongo-snap || true",
          "echo \"Starting mongo container\"",
          "docker start mongo || docker run -d --name mongo -v /data/mongo:/data/db mongo:6.0 mongod --bind_ip_all --auth",
          "echo \"Restore complete. Volume $VOL_ID was used for restore.\""
        ]
      }
    }
  ]
}
