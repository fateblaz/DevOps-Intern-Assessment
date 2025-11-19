# Permissions Required

The user running orchestrate.sh must have:
- `ssm:SendCommand`
- `ssm:GetCommandInvocation`
- `ssm:GetParameter — if validation/anonymizer fetch credentials`
  
The S3 + DynamoDB Terraform state access
# Pre-checks Before Running
## 1. Terraform infrastructure is deployed and outputs available
- `primary_instance_id`, `secondary_instance_id`, `staging_instance_id`
- `primary_private_ip`, `secondary_private_ip`, `staging_private_ip`
## 2. MongoDB credentials exist in SSM Parameter Store:
- `/mongo/admin (username)`
- `/mongo/admin/password (SecureString password)`
## 3. SSM Agent is running on all EC2 instances
Auto-installed via EC2 user-data; no manual action needed unless debugging
## 4. IAM permissions validated:
### EC2 instance role has:
```
ssm:GetParameter
ec2:CreateSnapshot
ec2:CreateVolume
ec2:AttachVolume
```
Operator/CI running the scripts has:
```
ssm:SendCommand
ssm:GetCommandInvocation
```
## 5. config.yaml is prepared:
- Copy from template: `cp config-template.yaml config.yaml`
- Fill placeholders with Terraform outputs (instance IDs, doc names, region).

## One-Command Orchestration
``` make sync ``` This runs all four steps automatically

Manual

- Snapshot on secondary `./scripts/trigger_snapshot.sh config.yaml`
- Restore to staging `./scripts/trigger_restore.sh config.yaml`
- Anonymize PII `python3 scripts/anonymize_staging.py --config config.yaml`
- Validate restore `./scripts/validate_restore.sh config.yaml`

## Post-checks
1. Staging MongoDB container is running
2. Document counts look correct
3. PII fields are masked
4. Snapshot exists for today:
```
aws ec2 describe-snapshots \
  --filters Name=tag:Name,Values=sync-system-mongo-weekly* \
  --region ap-south-1
```
## Rollback
If restore fails or staging data is incorrect:

1.Stop MongoDB on staging
```
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --instance-ids <STAGING_ID> \
  --parameters commands=["docker stop mongo || true"] \
  --region ap-south-1
```
2. Find previous snapshot 
```
aws ec2 describe-snapshots \
  --filters Name=tag:Name,Values=sync-system-mongo-weekly* \
  --query "Snapshots | sort_by(@,&StartTime)[-2]" \
  --region ap-south-1
```
3. Re-run restore using previous snapshot (manual volume + rsync or customized restore doc).
