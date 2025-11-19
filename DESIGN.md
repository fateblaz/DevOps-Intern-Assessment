# MongoDB Production → Staging Sync with EBS Snapshot
## Overview
This design provides a reliable and safe mechanism to synchronize production MongoDB data into a staging environment. It uses EBS snapshots from a hidden replica to avoid impacting production, and performs anonymization on staging before exposing data to developers or testers.

### Core Workflow
1. Use a **hidden, non-voting secondary** for consistent snapshots.
2. Apply **fsyncLock → EBS snapshot → fsyncUnlock** to ensure crash consistency.
3. Create a **new EBS volume** from snapshot and attach it to the staging EC2 instance.
4. Copy data files (rsync or direct mount replacement).
5. Run **data anonymization** on staging.
6. Automate all steps using **AWS SSM Documents**.

## ASCII Architecture Diagram
```
                     ┌──────────────────────────┐
                     │       AWS VPC            │
                     │      (ap-south-1)        │
                     └──────────────────────────┘
                               │
                ┌───────────────────────────────────────────┐
                │          Production Environment            │
                └───────────────────────────────────────────┘
                           │                    │
                           ▼                    ▼
                ┌────────────────┐   ┌────────────────────────┐
                │ Primary EC2    │   │ Hidden Secondary EC2    │
                │ ap-south-1a    │   │ ap-south-1b             │
                │ Docker MongoDB │   │ Docker MongoDB          │
                │ replSet: rs0   │   │ priority:0, votes:0    │
                └────────────────┘   └────────────────────────┘
                         │                     │
                         │ (async replication) │
                         └─────────────────────┘
                                 │
                                 ▼
                   ┌────────────────────────────┐
                   │   EBS Snapshot (Secondary) │
                   │   Consistent via fsyncLock │
                   └────────────────────────────┘
                                 │
                                 ▼
                ┌──────────────────────────────────────────┐
                │               Staging EC2                │
                │             ap-south-1a/b                │
                │     Docker MongoDB (restored copy)       │
                └──────────────────────────────────────────┘
                                 │
                                 ▼
                   ┌───────────────────────────────┐
                   │  Anonymizer (Python Script)   │
                   │  Masks PII before use         │
                   └───────────────────────────────┘

```

## Architecture Components

### **Production**
- **Primary (ap-south-1a)**
  - Handles all writes.
  - Never touched during sync.

- **Hidden Secondary (ap-south-1b)**
  - Configuration:
    ```json
    { "priority": 0, "votes": 0, "hidden": true }
    ```
  - Used for snapshot operations.
  - Prevents elections and isolates snapshot load.

### **Staging (ap-south-1b)**
- Separate EC2 instance with its own EBS volume.
- Receives restored data and runs anonymization script.

---

## Automation Components
### **AWS SSM Documents**
| Document Name       | Purpose |
|--------------------|---------|
| `mongo-snapshot`   | fsyncLock → snapshot → fsyncUnlock |
| `mongo-restore`    | Create EBS volume → attach → copy/restore |
| `replica-init`     | Setup hidden replica configuration |

### **SSM Parameter Store**
- `/mongo/admin` (username)
- `/mongo/admin/password` (password)
- Stored as **SecureString** (KMS encrypted).

### **Terraform**
- Provisions:
  - EC2 instances
  - EBS volumes
  - Snapshot IAM permissions
  - SSM Documents
  - User-data scripts
  - S3 + DynamoDB backend for Terraform state

### **Sanitization**
- Script: `anonymize_staging.py`
- Runs post-restore
- Masks PII fields deterministically

---

## Design Rationale & Trade-offs

### **EBS Snapshot vs. mongodump**
| Aspect | EBS Snapshot | mongodump |
|--------|---------------|------------|
| Speed | 🚀 Very fast (TB-scale) | Slow for large datasets |
| Restore Time | Minutes (create volume) | Very slow (full import) |
| Consistency | Needs fsyncLock on secondary | Built-in |
| Cost | Snapshot storage | Compute time + storage |

**Verdict:** EBS snapshot strategy is optimal for large datasets.

---

### **Hidden Non-Voting Secondary**
- Prevents impact on primary.
- Prevents accidental traffic routing.
- Allows safe fsyncLock operations.

---

### **Anonymization on Staging Only**
- Zero risk of modifying production data.
- Staging gets clean + realistic dataset.
- Script is deterministic so the same PII → same masked value.

---

## Security & Safety

### **Credentials**
- Stored in **SSM Parameter Store (SecureString)**.
- Accessed only by instance IAM role.

### **Access Control**
- IAM policy restricts actions:
  - `ssm:GetParameter`
  - `ec2:CreateSnapshot`, `ec2:CreateVolume`, `ec2:AttachVolume`
  - No broad EC2 permissions.

### **Data Protection**
- Snapshot happens on the **hidden replica**, not primary.
- Staging data is **sanitized** before use.
- Snapshot retention policy reduces cost.

---

## Summary
This system provides:
- A fast, production-safe MongoDB → staging sync process.
- Automated snapshot + restore workflows.
- Secure and deterministic anonymization for staging.
- A fully auditable flow using AWS SSM and Terraform.

