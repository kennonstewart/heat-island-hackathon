# Terraform Stack (Hackathon Mode)

This stack is intentionally minimal and uses a **single environment** (`hackathon`) with configurable defaults.

## What It Provisions

- One S3 data lake bucket (raw/curated/features/inference/artifacts)
- ECS cluster + Fargate API service
- AWS Batch compute environment (Fargate) + queue + job definition
- Glue catalog database + crawler over curated data
- Athena workgroup with query results in S3
- Minimal IAM roles/policies needed for those services
- Default VPC + default subnets by default (overridable)

## Backend (Already Bootstrapped)

- S3 state bucket: `heat-island-hackathon-tf-state-033286551182`
- DynamoDB lock table: `heat-island-hackathon-tf-locks`
- Region: `us-east-1`

## S3 Data Layout Recommendation (Glue/Athena Friendly)

Use Hive-style partition keys (`key=value`) in folder paths.

- `raw/source=<source>/dataset=<dataset>/ingest_date=<YYYY-MM-DD>/...`
- `curated/domain=<domain>/dataset=<dataset>/year=<YYYY>/month=<MM>/day=<DD>/...`
- `features/model=<model>/version=<version>/run_date=<YYYY-MM-DD>/...`
- `inference/run_id=<run_id>/date=<YYYY-MM-DD>/...`
- `artifacts/models/<model_name>/<run_id>/...`
- `athena/results/...`

Preferred table file formats:

- `curated/`: Parquet + Snappy
- `features/`: Parquet
- `raw/`: JSON/CSV/JSONL as landed

## Use It

1. Copy vars:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Initialize with remote backend:

```bash
terraform init -backend-config=backend.hcl.example
```

3. Preview and apply:

```bash
terraform plan
terraform apply
```

4. Destroy at hackathon end:

```bash
terraform destroy
```

## Optional Network Overrides

Set `vpc_id` and `subnet_ids` in `terraform.tfvars` if you do not want to use your default VPC/subnets.
