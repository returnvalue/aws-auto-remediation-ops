# AWS Auto-Remediation Ops Lab

This lab demonstrates a foundational security automation pattern: **detecting and automatically fixing security misconfigurations**. Using Terraform and LocalStack, we've built a workflow that monitors an S3 bucket for public access changes and automatically reverts them to private.

## Architecture Overview

The system follows an event-driven "Detection-Response" loop:

1.  **Detection:** Amazon EventBridge listens for `PutBucketAcl` API calls via CloudTrail events.
2.  **Trigger:** When a configuration change is detected, EventBridge triggers a target Lambda function.
3.  **Remediation:** A Python-based Lambda function inspects the target bucket and immediately resets its Access Control List (ACL) to `private`.

## Key Components

-   **Target S3 Bucket:** The resource being monitored for compliance.
-   **Remediation Lambda:** Contains the logic to revert public ACLs.
-   **IAM Role & Policy:** Grants the Lambda precise permissions to modify S3 ACLs and write logs to CloudWatch.
-   **EventBridge Rule:** The "event bus" that captures bucket configuration changes.
-   **Lambda Permission:** Explicitly allows EventBridge to invoke the remediation function.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To simulate a security misconfiguration and verify the auto-remediation:

1.  **Simulate Misconfiguration (Make Bucket Public):**
    ```bash
    awslocal s3api put-bucket-acl --bucket auto-remediation-target-bucket --acl public-read
    aws s3api put-bucket-acl --bucket auto-remediation-target-bucket --acl public-read
    ```

2.  **Trigger Remediation (Simulate EventBridge):**
    *In a live AWS environment, this happens automatically. In LocalStack, you can trigger the function manually:*
    ```bash
    awslocal lambda invoke --function-name s3-remediation-function response.json
    aws lambda invoke --function-name s3-remediation-function response.json
    ```

3.  **Confirm the Fix:**
    Verify the bucket's ACL is now back to `private`:
    ```bash
    awslocal s3api get-bucket-acl --bucket auto-remediation-target-bucket
    aws s3api get-bucket-acl --bucket auto-remediation-target-bucket
    ```

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
