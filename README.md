# cloudfront-logs

This repository deploys CloudFront + S3 + Kinesis + Firehose + Lambda for processing CloudFront real-time logs using Terraform.

## What it creates

- An S3 bucket for frontend static assets
- A CloudFront distribution serving the S3 bucket
- A Kinesis Data Stream (`aws_kinesis_stream.cloudfront_streams`) for real-time logs
- A Kinesis Data Firehose delivery stream to S3 for storing logs
- A Lambda function that consumes the Kinesis stream and writes to CloudWatch Logs
- IAM roles/policies required for the above


## Quickstart

1. Install Terraform 1.3+ and AWS CLI.
2. Configure AWS credentials for the account and region you want to deploy to. By default the project uses `us-east-2`.

```bash
export AWS_PROFILE=default
export AWS_REGION=us-east-2
terraform init
terraform plan
terraform apply -auto-approve
```

## Variables

- `aws_region` (default: `us-east-2`) — Region to deploy resources
- `env` (default: `dev`) — Environment name suffix
- `bucket_name` — S3 bucket name for frontend assets

You can override them via `terraform.tfvars` or CLI `-var` flags.

## Viewing the Kinesis Stream

The Kinesis stream name is `cloudfront-stream-${var.env}`, e.g. `cloudfront-stream-dev`.

Console:

Example (replace `us-east-2` and `cloudfront-stream-dev` with your region and stream name if different):
https://console.aws.amazon.com/kinesis/home?region=us-east-2#/streams/details?streamName=cloudfront-stream-dev

CLI example:

```bash
aws kinesis describe-stream-summary --stream-name cloudfront-stream-dev --region us-east-2
```

## Removing everything

To destroy all resources created by Terraform:

```bash
terraform destroy -auto-approve
```

If CloudFront distributions don't delete due to being enabled, disable them in the Console or via the AWS CLI before deleting.

## Troubleshooting

- If `terraform destroy` fails, check for `prevent_destroy` lifecycle rules, dependencies, or resources managed outside Terraform.
- For missing AWS Console items, verify account/region (`aws sts get-caller-identity`).

## Notes

- The Lambda consumer is in `lambda/kinesis_to_cloudwatch.py`. It decodes records and writes to CloudWatch Logs. It was updated to log exceptions and include client IP when possible.

---

If you want a more detailed README (architecture diagram, diagram links, or CI/CD steps), tell me what you'd like and I'll expand it.