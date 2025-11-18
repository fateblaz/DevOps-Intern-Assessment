#!/bin/bash
set -euo pipefail


SSM_PARAM_USER="${ssm_param_user}"
SSM_PARAM_PASSWORD="${ssm_param_password}"
DOCKER_IMAGE="${docker_image}"
DATA_DEVICE="${data_device:-/dev/xvdf}"
AWS_REGION="${aws_region:-ap-south-1}"


if command -v yum >/dev/null 2>&1; then
  yum update -y
  yum install -y docker jq awscli amazon-ssm-agent
  systemctl enable --now docker
  systemctl enable --now amazon-ssm-agent
else
  apt-get update -y
  apt-get install -y docker.io jq awscli
  systemctl enable --now docker
fi


mkdir -p /data/mongo
DEVICE="${DATA_DEVICE}"
for i in {1..15}; do
  if [ -b "${DEVICE}" ]; then break; fi
  sleep 2
done

if [ -b "${DEVICE}" ]; then
  if ! blkid "${DEVICE}" >/dev/null 2>&1; then
    mkfs.ext4 -F "${DEVICE}" || true
  fi
  mount "${DEVICE}" /data/mongo || true
  chown -R 999:999 /data/mongo || true
fi


cat > /etc/mongod.conf <<'EOF'
storage:
  dbPath: /data/db
net:
  bindIp: 0.0.0.0
  port: 27017
security:
  authorization: "enabled"
replication:
  replSetName: rs0
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
processManagement:
  fork: false
EOF

mkdir -p /var/log/mongodb
chown -R 999:999 /var/log/mongodb || true

MONGO_USER=""
MONGO_PW=""
for i in {1..6}; do
  if [ -z "$MONGO_USER" ]; then
    MONGO_USER=$(aws ssm get-parameter --name "${SSM_PARAM_USER}" --with-decryption --query "Parameter.Value" --output text --region "${AWS_REGION}" 2>/dev/null) || true
  fi
  if [ -z "$MONGO_PW" ]; then
    MONGO_PW=$(aws ssm get-parameter --name "${SSM_PARAM_PASSWORD}" --with-decryption --query "Parameter.Value" --output text --region "${AWS_REGION}" 2>/dev/null) || true
  fi
  if [ -n "$MONGO_USER" ] && [ -n "$MONGO_PW" ]; then
    break
  fi
  sleep 3
done

if [ -z "$MONGO_USER" ] || [ -z "$MONGO_PW" ]; then
  echo "ERROR: could not fetch Mongo admin username/password from SSM (user:${SSM_PARAM_USER}, pass:${SSM_PARAM_PASSWORD})" >&2
  exit 2
fi


cat > /etc/mongo_env <<EOF
MONGO_INITDB_ROOT_USERNAME=${MONGO_USER}
MONGO_INITDB_ROOT_PASSWORD=${MONGO_PW}
EOF
chmod 600 /etc/mongo_env
chown root:root /etc/mongo_env

# run mongo docker
docker pull ${DOCKER_IMAGE}
docker rm -f mongo || true

docker run -d --name mongo \
  --env-file /etc/mongo_env \
  -v /data/mongo:/data/db \
  -v /etc/mongod.conf:/etc/mongod.conf:ro \
  -p 27017:27017 \
  ${DOCKER_IMAGE} mongod --config /etc/mongod.conf --auth
