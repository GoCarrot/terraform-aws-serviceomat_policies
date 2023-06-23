# Serviceomat Policies

Serviceomat Policies is a module to create basic IAM policies for logging and AppConfig access generally used by services configured by [Serviceomat](https://registry.terraform.io/modules/GoCarrot/serviceomat/aws/latest).

## Installation

This is a complete example of a minimal serviceomat policies setup.

```hcl
provider "aws" {
  alias = "meta"
}

# Skip this if you already have a configured omat organiztion prefix!
resource "aws_ssm_parameter" "org_prefix" {
  name  = "/omat/organization_prefix"
  type  = "String"
  value = "myorg"
}

module "serviceomat_policies" {
  source = "GoCarrot/serviceomat_policies/aws"

  providers = {
    aws.meta = aws.meta
  }
}
```

This will create IAM Policies named `LogAccess` and `ConfigAccess` which use [Attribute Based Access Control](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_attribute-based-access-control.html) to permit services to access CloudWatch Log Groups and AppConfig configurations relevant to the service.

You may create an S3 bucket to provide backup configuration in the event AppConfig experiences an outage. To grant additional permissions necessary to read these backup configuration objects, set the `config_bucket_id` variable to the bucket's name.

This is a complete example of a serviceomat policies setup with S3 configuration backup.

```hcl
provider "aws" {
  alias = "meta"
}

# Skip this if you already have a configured omat organiztion prefix!
resource "aws_ssm_parameter" "org_prefix" {
  name  = "/omat/organization_prefix"
  type  = "String"
  value = "myorg"
}

# Skip this if you already have a configured config backup bucket!
resource "aws_s3_bucket" "config-backup" {
  bucket_prefix = "config-backup-"
}

resource "aws_s3_bucket_versioning" "config-backup" {
  bucket = aws_s3_bucket.config-backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "config-backup" {
  bucket = aws_s3_bucket.config-backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "serviceomat_policies" {
  source = "GoCarrot/serviceomat_policies/aws"

  providers = {
    aws.meta = aws.meta
  }

  config_bucket_id = aws_s3_bucket.config-backup.id
}
```

## Policy Descriptions

### LogAccess

The `LogAccess` policy grants the following permissions
- logs:CreateLogStream and logs:DescribeLogStreams on log groups in all accounts and regions with the names
-- /{omat_prefix}/server/{iam_role_tags/Environment}/ancillary/\*
-- /{omat_prefix}/server/{iam_role_tags/Environment}/service/{iam_role_tags/Service}
-- /{omat_prefix}/server/{iam_role_tags/Environment}/service/{iam_role_tags/Service}/\*
- logs"PutLogEvents on all log streams in all accounts and regions with the names
-- /{omat_prefix}/server/{iam_role_tags/Environment}/ancillary/\*:{iam_role_tags/Service}.\*
-- /{omat_prefix}/server/{iam_role_tags/Environment}/ancillary/{iam_role_tags/Service}:{iam_role_tags/Service}.\*
-- /{omat_prefix}/server/{iam_role_tags/Environment}/ancillary/{iam_role_tags/Service}/\*:{iam_role_tags/Service}.\*
- logs:DescribeLogGroups on all log groups in all accounts and regions

For example, given an `omat_prefix` of `myorg`, when this policy is attached to an IAM Role with the tags `Environment=development` and `Service=example`, the policy grants the following permissions
- logs:CreateLogStream and logs:DescribeLogStreams on log groups in all accounts and regions with the names
-- /myorg/server/development/ancillary/\*
-- /myorg/server/development/service/example
-- /myorg/server/development/service/example/\*
- logs:PutLogEvents on all log streams in all accounts and regions with the names
-- /myorg/server/development/ancillary/\*:example.\*
-- /myorg/server/development/service/example:example.\*
-- /myorg/server/development/service/example\*:example.\*
- logs:DescribeLogGroups on all log groups in all accounts and regions

### ConfigAccess

The `ConfigAccess` policy grants the following permissions
- appconfig:GetConfiguration on all AppConfig resources with a Service tag of the same value as {iam_role_tags/Service}
- appconfig:GetConfiguration on all AppConfig resources with a Service tag of "shared-infra"
- appconfig:GetConfiguration on all AppConfig resources with a SharedWith tag including "@{iam_role_tags/Service}@"

For example, when this policy is attached to an IAM Role with the tag `Service=example`, the politcy grants access to
- appconfig:GetConfiguration on all AppConfig resources with the tag `Service=example`
- appconfig:GetConfiguration on all AppConfig resources with the tag `Service=shared-infra`
- appconfig:GetConfiguration on all AppConfig resources with a SharedWith tag including `@example@`

If the `config_bucket_id` variable is set on the module, the `ConfigAccess` policy will additionally grant
- s3:GetObject on all objects in config_bucket_id with a Service tag of the same value as {iam_role_tags/Service}
- s3:GetObject on all objects in config_bucket_id with a Service tag of "shared-infra"
- s3:GetObject on all objects in config_bucket_id with a SharedWith tag including "@{iam_role_tags/Service}@"

For example, if `config_bucket_id` is set to `config-backup`, when this policy is attached to an IAM Role with the tag `Service=example`, the politcy grants access to
- s3:GetObject on all objects in the `config-backup` with the tag `Service=example`
- s3:GetObject on all objects in the `config-backup` with the tag `Service=shared-infra`
- s3:GetObject on all objects in the `config-backup` with a SharedWith tag including `@example@`
