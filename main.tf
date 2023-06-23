# Copyright 2023 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.22, < 6"

      configuration_aliases = [aws.meta]
    }
  }
}

data "aws_default_tags" "tags" {}

data "aws_ssm_parameter" "organization-prefix" {
  provider = aws.meta

  name = "/omat/organization_prefix"
}

locals {
  tags = { for key, value in var.tags : key => value if lookup(data.aws_default_tags.tags.tags, key, null) != value }

  organization_prefix = nonsensitive(data.aws_ssm_parameter.organization-prefix.value)

  config_bucket_id = toset(compact([var.config_bucket_id]))
}

data "aws_iam_policy_document" "log_access" {
  statement {
    sid    = "AllowDescribeCreateLogStreams"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/${local.organization_prefix}/server/&{aws:PrincipalTag/Environment}/ancillary/*",
      "arn:aws:logs:*:*:log-group:/${local.organization_prefix}/server/&{aws:PrincipalTag/Environment}/service/&{aws:PrincipalTag/Service}:*",
      "arn:aws:logs:*:*:log-group:/${local.organization_prefix}/server/&{aws:PrincipalTag/Environment}/service/&{aws:PrincipalTag/Service}/*"
    ]
  }

  statement {
    sid    = "AllowDescribeLogGroups"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:*",
    ]
  }

  statement {
    sid    = "AllowPutLogEvents"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/${local.organization_prefix}/server/&{aws:PrincipalTag/Environment}/ancillary/*:log-stream:&{aws:PrincipalTag/Service}.*",
      "arn:aws:logs:*:*:log-group:/${local.organization_prefix}/server/&{aws:PrincipalTag/Environment}/service/&{aws:PrincipalTag/Service}:log-stream:&{aws:PrincipalTag/Service}.*",
      "arn:aws:logs:*:*:log-group:/${local.organization_prefix}/server/&{aws:PrincipalTag/Environment}/service/&{aws:PrincipalTag/Service}/*:log-stream:&{aws:PrincipalTag/Service}.*"
    ]
  }
}

resource "aws_iam_policy" "log-access" {
  name   = "LogAccess"
  policy = data.aws_iam_policy_document.log_access.json

  tags = local.tags
}

data "aws_iam_policy_document" "app_config" {
  statement {
    sid    = "AllowGetServiceConfiguration"
    effect = "Allow"
    actions = [
      "appconfig:GetConfiguration",
    ]
    resources = [
      "arn:aws:appconfig:*:*:application/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Service"
      values = [
        "&{aws:PrincipalTag/Service}"
      ]
    }
  }

  statement {
    sid    = "AllowGetSharedServiceConfiguration"
    effect = "Allow"
    actions = [
      "appconfig:GetConfiguration",
    ]
    resources = [
      "arn:aws:appconfig:*:*:application/*",
    ]

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/SharedWith"
      values = [
        "*@&{aws:PrincipalTag/Service}@*"
      ]
    }
  }

  statement {
    sid    = "AllowGetSharedConfiguration"
    effect = "Allow"
    actions = [
      "appconfig:GetConfiguration",
    ]
    resources = [
      "arn:aws:appconfig:*:*:application/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Service"
      values = [
        "shared-infra"
      ]
    }
  }

  dynamic "statement" {
    for_each = local.config_bucket_id
    content {
      sid    = "AllowS3GetServiceConfiguration"
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "arn:aws:s3::*:${statement.key}/*"
      ]

      condition {
        test     = "StringEquals"
        variable = "s3:ExistingObjectTag/Service"
        values   = ["&{aws:PrincipalTag/Service}"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.config_bucket_id
    content {
      sid    = "AllowS3GetSharedServiceConfiguration"
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "arn:aws:s3::*:${statement.key}/*"
      ]

      condition {
        test     = "StringLike"
        variable = "s3:ExistingObjectTag/SharedWith"
        values   = ["*@&{aws:PrincipalTag/Service}@*"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.config_bucket_id
    content {
      sid    = "AllowS3GetSharedConfiguration"
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "arn:aws:s3::*:${statement.key}/*"
      ]

      condition {
        test     = "StringLike"
        variable = "s3:ExistingObjectTag/Service"
        values   = ["shared-infra"]
      }
    }
  }
}

resource "aws_iam_policy" "config-access" {
  name   = "ConfigAccess"
  policy = data.aws_iam_policy_document.app_config.json

  tags = local.tags
}
