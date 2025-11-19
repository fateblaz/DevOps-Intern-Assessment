#!/usr/bin/env python3

import yaml, argparse, os
from pymongo import MongoClient
import hashlib

parser = argparse.ArgumentParser()
parser.add_argument("--config", "-c", default="config.yaml", help="Path to config")
args = parser.parse_args()

cfg = yaml.safe_load(open(args.config))
region = cfg.get("aws_region", "ap-south-1")
staging_host = cfg.get("staging_private_ip", "127.0.0.1")
admin_user_param = cfg.get("admin_ssm_user")
admin_pw_param = cfg.get("admin_ssm_password")

def get_ssm_param(name):
    import subprocess, shlex
    cmd = f"aws ssm get-parameter --name {name} --with-decryption --query Parameter.Value --output text --region {region}"
    out = subprocess.check_output(shlex.split(cmd)).decode().strip()
    return out

admin_user = get_ssm_param(admin_user_param)
admin_pw = get_ssm_param(admin_pw_param)


mongo_uri = f"mongodb://{admin_user}:{admin_pw}@{staging_host}:27017/admin"
client = MongoClient(mongo_uri)
db = client.get_database("sampledb")

def deterministic_hash(val: str) -> str:
    return hashlib.sha256(val.encode()).hexdigest()[:16]


mappings = {
    "users": {
        "email": lambda doc: f"user_{doc.get('_id')}@example.local",
        "name": lambda doc: f"User_{doc.get('_id')}",
        "phone": lambda doc: None,
    },
    "orders": {
        "note": lambda doc: "anonymized"
    }
}

for coll, fields in mappings.items():
    col = db.get_collection(coll)
    docs = col.find({}, {"_id":1})
    count = 0
    for d in docs:
        update = {}
        for field, fn in fields.items():
            update[field] = fn(d)
        if update:
            col.update_one({"_id": d["_id"]}, {"$set": update})
            count += 1
    print(f"Anonymized {count} documents in collection {coll}")

print("Anonymization complete.")
