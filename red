# NIS EF File Flow – Lambda Module

This repository provisions an **AWS Lambda function** with multiple **optional integrations** (S3, EventBridge, Secrets Manager, SFTP).

> ⚠️ **Lambda creation is mandatory**.
> Everything else is **explicitly enabled by passing flags = true**.

---

## What Is Mandatory

These resources are **always created**:

* `aws_lambda_function`
* Lambda ZIP package (`archive_file`)
* `aws_cloudwatch_log_group`
* Lambda execution role (via provided ARN / locals)
* Lambda environment variables

If you do **not** want a Lambda → **do not use this module**.

---

## Optional Features – How to Enable (IMPORTANT)

👉 **Nothing optional is created unless you explicitly pass `true`.**

| Feature                     | Variable to Pass              | Value   |
| --------------------------- | ----------------------------- | ------- |
| Enable S3 → Lambda invoke   | `enable_s3_lambda_permission` | `true`  |
| Enable EventBridge schedule | `enable_cloudwatch_event`     | `true`  |
| Create new SSH secret       | `create_sftp_secrets`         | `true`  |
| Use existing SSH secret     | `create_sftp_secrets`         | `false` |
| Create SFTP server secret   | `sftp_server_secrets`         | `true`  |

If a flag is **not passed or set to false**, the resource **will NOT be created**.

---

## Repository Structure

```
terraform/
├── modules/
│   └── file_flow/
│       ├── main.tf
│       ├── provider.tf
│       ├── enableall.tf
│       ├── lambdawiths3_event.tf
│       ├── useexistingsecret.tf
│       └── variables.tf
├── enableall.tf
├── lambdawiths3_event.tf
├── useexistingsecret.tf
└── provider.tf
```

---

## Mandatory Variables

### Mandatory (Always Required – Lambda Creation)

These **must** be provided in **every** module call because Lambda is always created.

| Variable             | Required | Description                                   |
| -------------------- | -------- | --------------------------------------------- |
| `nis_request_number` | Yes      | Unique request identifier used in tags/naming |
| `env`                | Yes      | Environment name (dev/test/prod/etc.)         |
| `region`             | Yes      | Short region value (ex: `west`, `east`)       |
| `lambda_source_file` | Yes      | Path to Lambda source file (.py)              |
| `function_name`      | Yes      | Lambda function name                          |
| `handler`            | Yes      | Lambda handler name                           |
| `env_vars`           | Yes      | Map of environment variables for Lambda       |

If **any of the above are missing**, Terraform will fail during plan/apply.

---

## Mandatory Variables When Enabling Optional Services

### S3 → Lambda Permission (`enable_s3_lambda_permission = true`)

| Variable                        | Required | Description           |
| ------------------------------- | -------- | --------------------- |
| `enable_s3_lambda_permission`   | Yes      | Must be `true`        |
| `s3_bucket` (inside `env_vars`) | Yes      | Source S3 bucket name |

If `enable_s3_lambda_permission = true` and bucket info is missing → **apply will fail**.

---

### EventBridge Schedule (`enable_cloudwatch_event = true`)

| Variable                  | Required | Description           |
| ------------------------- | -------- | --------------------- |
| `enable_cloudwatch_event` | Yes      | Must be `true`        |
| `schedule_rate_minutes`   | Yes      | Rate value in minutes |

Missing schedule variables → EventBridge rule creation fails.

---

### Create New SSH Secret (`create_sftp_secrets = true`)

| Variable              | Required | Description              |
| --------------------- | -------- | ------------------------ |
| `create_sftp_secrets` | Yes      | Must be `true`           |
| `sftp_secret_name`    | Yes      | Secret name suffix       |
| `sftp_secret_file`    | Yes      | SSH public key file path |

If file path is invalid → `file()` error.

---

### Use Existing SSH Secret (`create_sftp_secrets = false`)

| Variable              | Required | Description          |
| --------------------- | -------- | -------------------- |
| `create_sftp_secrets` | Yes      | Must be `false`      |
| `sftp_secret_name`    | Yes      | Existing secret name |

If secret does not exist → Secrets Manager lookup error.

---

### Create SFTP Server Secret (`sftp_server_secrets = true`)

| Variable              | Required | Description              |
| --------------------- | -------- | ------------------------ |
| `sftp_server_secrets` | Yes      | Must be `true`           |
| `sftp_username`       | Yes      | Transfer Family username |
| `home_directory`      | Yes      | User home directory      |
| `sftp_role`           | Yes      | IAM role ARN             |
| `sftp_password`       | Yes      | Password (sensitive)     |
| `prefix`              | Yes      | Prefix for policy/path   |

Missing any required field → secret payload build fails.

---

## Usage Scenarios

### 1️⃣ Lambda Only (Minimum Required)

```hcl
module "lambda_only" {
  providers = { aws = aws.west }

  source             = "./modules/file_flow"
  nis_request_number = "nis-test1"

  env    = var.env
  region = var.short_region_west

  lambda_source_file = "${path.module}/lambda_source_code/test.py"
  function_name      = "myapp-west-acct-test1"
  handler            = "test"

  env_vars = {
    DESTINATION_ARN = "arn"
    ROLE_ARN        = "arn"
    s3_bucket       = "bucket"
  }
}
```

---

### 2️⃣ Enable S3 Permission on Lambda

```hcl
enable_s3_lambda_permission = true
```

Creates:

* `aws_lambda_permission` (S3 invoke)

If this is **false or missing**, S3 **cannot invoke Lambda**.

---

### 3️⃣ Enable EventBridge Schedule on Lambda

```hcl
enable_cloudwatch_event = true
```

Creates:

* `aws_cloudwatch_event_rule`
* `aws_cloudwatch_event_target`
* `aws_lambda_permission` (EventBridge)

If this is **false**, no schedule is created.

---

### 4️⃣ Create New SSH Secret and Inject into Lambda

```hcl
create_sftp_secrets = true
sftp_secret_name   = "test3"
sftp_secret_file   = "ssh_key/boa.pub"
```

Behavior:

* Creates secret at:

  ```
  nis/ef/<sftp_secret_name>
  ```
* Reads SSH key using `file()`
* Injects secret ARN into Lambda env vars

⚠️ **Error if `sftp_secret_file` path is wrong**

---

### 5️⃣ Use Existing SSH Secret (No Creation)

```hcl
create_sftp_secrets = false
sftp_secret_name   = "existing-secret-name"
```

Behavior:

* Looks up existing secret:

  ```
  nis/ef/<sftp_secret_name>
  ```
* Injects ARN into Lambda env vars
* Does NOT create any Secrets Manager resource

⚠️ **Error if secret does not exist**

---

### 6️⃣ Create SFTP Server User Secret

```hcl
sftp_server_secrets = true
sftp_username       = "test3"
home_directory      = "test3"
sftp_role           = "arn:aws-us-gov:iam::XXXX:role/devops-sftp"
sftp_password       = "test3"
prefix              = "test3"
```

Creates:

* Transfer Family user secret
* KMS-encrypted payload

If `sftp_server_secrets = false` → nothing is created.

---

## Common Errors & Why They Happen

### ❌ `Invalid index` / `[0]` error

**Cause**

* Resource has `count = 0` but is still referenced

**Fix**

* Flags must match usage:

  * `create_sftp_secrets = true` when creating
  * `create_sftp_secrets = false` when using existing

---

### ❌ `Secret not found`

**Cause**

* Using existing secret but it does not exist

**Fix**

* Verify secret exists:

  ```
  nis/ef/<sftp_secret_name>
  ```

---

### ❌ `file()` function failed

**Cause**

* SSH key file path is wrong

**Fix**

* Path must exist relative to Terraform execution directory

---

### ❌ S3 does not trigger Lambda

**Cause**

* `enable_s3_lambda_permission` not set to true

**Fix**

```hcl
enable_s3_lambda_permission = true
```

---

### ❌ EventBridge rule exists but Lambda not invoked

**Cause**

* Missing EventBridge Lambda permission

**Fix**

```hcl
enable_cloudwatch_event = true
```

---

## Design Rules (Do Not Violate)

* Lambda is always created
* Optional resources require explicit `true`
* No `null_resource`
* No hidden auto-creation
* Safe repeated `terraform apply`
* Designed for east/west provider aliases

---

## When NOT to Use This Module

* You want conditional Lambda creation
* You want secrets fully managed outside Terraform
* You want multiple Lambdas from one module call

---

## Summary

✔ Lambda is mandatory
✔ Optional features require `true`
✔ Predictable and safe behavior
✔ No side effects

---
