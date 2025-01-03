// Live

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.80.0"
      configuration_aliases = [aws.secondary]
    }
    pf = {
      source  = "panfactum/pf"
      version = "0.0.7"
    }
  }
}

locals {
  # We omit some tags that change frequently from node group
  # replicas b/c changing these tags take a very long time to update
  replica_tags = {
    for k, v in data.pf_aws_tags.secondary_tags.tags : k => v if !contains([
      "panfactum.com/stack-commit",
      "panfactum.com/stack-version"
    ], k)
  }
}

data "aws_region" "primary" {}
data "aws_region" "secondary" {
  provider = aws.secondary
}

data "pf_aws_tags" "tags" {
  module = "aws_kms_encrypt_key"
}

data "pf_aws_tags" "secondary_tags" {
  module          = "aws_kms_encrypt_key"
  region_override = data.aws_region.secondary.name
}

###########################################################################
## Access policy
###########################################################################

data "aws_iam_roles" "superuser" {
  name_regex  = "AWSReservedSSO_Superuser.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "admin" {
  name_regex  = "AWSReservedSSO_Admin.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "reader" {
  name_regex  = "AWSReservedSSO_Reader.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "restricted_reader" {
  name_regex  = "AWSReservedSSO_RestrictedReader.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}


data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "key" {
  statement {
    effect = "Allow"
    principals {
      identifiers = tolist(toset(concat(
        [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        ],
        var.superuser_iam_arns,
        tolist(data.aws_iam_roles.superuser.arns)
      )))
      type = "AWS"
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    principals {
      identifiers = tolist(toset(concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.superuser_iam_arns,
        var.admin_iam_arns,
        var.reader_iam_arns,
        tolist(data.aws_iam_roles.superuser.arns),
        tolist(data.aws_iam_roles.admin.arns),
        tolist(data.aws_iam_roles.reader.arns)
      )))
      type = "AWS"
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.log_delivery_enabled ? ["enabled"] : []
    content {
      effect = "Allow"
      principals {
        identifiers = ["delivery.logs.amazonaws.com"]
        type        = "Service"
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  }

  statement {
    effect = "Allow"
    principals {
      identifiers = tolist(toset(concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.superuser_iam_arns,
        var.admin_iam_arns,
        var.reader_iam_arns,
        tolist(data.aws_iam_roles.superuser.arns),
        tolist(data.aws_iam_roles.admin.arns),
        tolist(data.aws_iam_roles.reader.arns)
      )))
      type = "AWS"
    }
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      values   = ["true"]
      variable = "kms:GrantIsForAWSResource"
    }
  }

  statement {
    effect = "Allow"
    principals {
      identifiers = tolist(toset(concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.superuser_iam_arns,
        var.admin_iam_arns,
        var.reader_iam_arns,
        var.restricted_reader_iam_arns,
        tolist(data.aws_iam_roles.superuser.arns),
        tolist(data.aws_iam_roles.admin.arns),
        tolist(data.aws_iam_roles.reader.arns),
        tolist(data.aws_iam_roles.restricted_reader.arns)
      )))
      type = "AWS"
    }
    actions = [
      "kms:Get*",
      "kms:List*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

###########################################################################
## Primary Key
###########################################################################

resource "aws_kms_key" "key" {
  description              = var.description
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 30
  is_enabled               = true
  multi_region             = true
  policy                   = data.aws_iam_policy_document.key.json

  tags = data.pf_aws_tags.tags.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "alias" {
  target_key_id = aws_kms_key.key.key_id
  name          = "alias/${var.name}"
}

###########################################################################
## Replica Key
###########################################################################

moved {
  from = aws_kms_replica_key.replica
  to   = aws_kms_replica_key.replica[0]
}

resource "aws_kms_replica_key" "replica" {
  count                   = var.replication_enabled ? 1 : 0
  provider                = aws.secondary
  primary_key_arn         = aws_kms_key.key.arn
  description             = var.description
  deletion_window_in_days = 30
  enabled                 = true
  policy                  = data.aws_iam_policy_document.key.json

  tags = local.replica_tags

  lifecycle {
    prevent_destroy = true
  }
}

moved {
  from = aws_kms_alias.replica_alias
  to   = aws_kms_alias.replica_alias[0]
}

resource "aws_kms_alias" "replica_alias" {
  count         = var.replication_enabled ? 1 : 0
  provider      = aws.secondary
  target_key_id = aws_kms_replica_key.replica[0].key_id
  name          = "alias/${var.name}"
}
