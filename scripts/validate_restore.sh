#!/usr/bin/env bash
set -euo pipefail
CONFIG="${1:-config.yaml}"
python3 - <<PY
import yaml,sys,subprocess,shlex
cfg=yaml.safe_load(open("$CONFIG"))
staging_ip = cfg.get("staging_private_ip") or "<STAGING_PRIVATE_IP>"
admin_user = cfg.get("admin_ssm_user")
admin_pw_param = cfg.get("admin_ssm_password")
region = cfg.get("aws_region","ap-south-1")
pw = subprocess.check_output(shlex.split(f"aws ssm get-parameter --name {admin_pw_param} --with-decryption --query Parameter.Value --output text --region {region}")).decode().strip()
user = subprocess.check_output(shlex.split(f"aws ssm get-parameter --name {admin_user} --with-decryption --query Parameter.Value --output text --region {region}")).decode().strip()

print('Running simple validations (counts) — connecting to staging via mongo shell on localhost or adjust host as needed')
print('Placeholders: run these commands on the staging host or via SSH tunnel to staging:')
print()
print(f"mongo --host {staging_ip} -u {user} -p <SSM_PASSWORD> --authenticationDatabase admin --eval \"db.getSiblingDB('sampledb').users.count()\"")
print(f"mongo --host {staging_ip} -u {user} -p <SSM_PASSWORD> --authenticationDatabase admin --eval \"db.getSiblingDB('sampledb').orders.count()\"")
print()
print('Or run these same queries using the python pymongo script (anonymizer provides example).')
PY
