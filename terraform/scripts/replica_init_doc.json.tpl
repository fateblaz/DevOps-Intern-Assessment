{
  "schemaVersion": "2.2",
  "description": "Initialize replica set on primary and add secondary as hidden non-voting member (fetch admin creds from SSM).",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "initReplica",
      "inputs": {
        "runCommand": [
          "#!/bin/bash -e",
          "AWS_REGION=\"${aws_region}\"",
          "ADMIN_USER_PARAM=\"${admin_ssm_user}\"",
          "ADMIN_PW_PARAM=\"${admin_ssm_password}\"",
          "",
          "echo 'Fetching Mongo admin creds from SSM...'",
          "MONGO_USER=$(aws ssm get-parameter --name \"$ADMIN_USER_PARAM\" --with-decryption --query Parameter.Value --output text --region $AWS_REGION) || true",
          "MONGO_PW=$(aws ssm get-parameter --name \"$ADMIN_PW_PARAM\" --with-decryption --query Parameter.Value --output text --region $AWS_REGION) || true",
          "if [ -z \"$MONGO_USER\" ] || [ -z \"$MONGO_PW\" ]; then echo 'ERROR: cannot fetch admin creds from SSM' >&2; exit 2; fi",
          "",
          "PRIMARY_IP=\"${primary_ip}\"",
          "SECONDARY_IP=\"${secondary_ip}\"",
          "echo \"Primary IP: $PRIMARY_IP  Secondary IP: $SECONDARY_IP\"",
          "",
          "echo 'Attempting rs.initiate() on primary (idempotent attempt)...'",
          "docker exec mongo mongo --username \"$MONGO_USER\" --password \"$MONGO_PW\" --authenticationDatabase admin --eval \"try{ rs.initiate({_id: 'rs0', members:[{ _id:0, host:'${primary_ip}:27017' }]}); } catch(e) { print('rs.initiate: ' + e); }\" || true",
          "sleep 3",
          "",
          "echo 'Adding secondary as hidden non-voting member (idempotent attempt)...'",
          "docker exec mongo mongo --username \"$MONGO_USER\" --password \"$MONGO_PW\" --authenticationDatabase admin --eval \"try{ rs.add({ _id:1, host:'${secondary_ip}:27017', priority:0, votes:0, hidden:true }); } catch(e) { print('rs.add: ' + e); }\" || true",
          "sleep 3",
          "echo 'Replica set status:'",
          "docker exec mongo mongo --username \"$MONGO_USER\" --password \"$MONGO_PW\" --authenticationDatabase admin --eval \"printjson(rs.status())\" || true",
          "echo 'Replica-init script finished.'"
        ]
      }
    }
  ]
}
