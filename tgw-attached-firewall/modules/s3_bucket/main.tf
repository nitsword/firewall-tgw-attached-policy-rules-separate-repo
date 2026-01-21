locals {
  # This picks the correct bucket name for the logging configuration
  # If existing_s3_bucket_name is empty, use the ID of the bucket we just created [0]
  final_bucket_name = var.existing_s3_bucket_name == "" ? aws_s3_bucket.this[0].id : var.existing_s3_bucket_name
}

##############################
# S3 Bucket Creation
##############################
resource "aws_s3_bucket" "this" {
  count         = var.existing_s3_bucket_name == "" ? 1 : 0
  bucket = "${var.application}-${var.env}-${var.bucket_name_segment}-bucket"
  force_destroy = true

  tags = merge(
    {
      Name                   = "${var.application}-${var.env}-${var.bucket_name_segment}-bucket"
      "Resource Type"        = "s3-bucket"
      "Creation Date"        = timestamp()
      "Environment"          = var.environment
      "Application"          = var.application
      "Created by"           = "Cloud Network Team"
      "breadthOfConsumption" = "Single"
      "dataSensitivity"      = "Internal"
      "dangerOfExploitation" = "INA"
    }, var.base_tags
  )
}

##############################
# Enable S3 Bucket Versioning (TMO Standard)
##############################
resource "aws_s3_bucket_versioning" "this" {
  count  = var.existing_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

##############################
# Block All Forms of Public Access (as per tmo standard)
##############################
resource "aws_s3_bucket_public_access_block" "this" {
  count                   = var.existing_s3_bucket_name == "" ? 1 : 0
  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

##############################
# S3 Bucket Policy Definition
##############################
data "aws_iam_policy_document" "bucket_policy" {
  count = var.existing_s3_bucket_name == "" ? 1 : 0

  # Allows Firewall for Log Delivery
  statement {
    sid    = "AllowNetworkFirewallLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = ["s3:PutObject", "s3:GetBucketAcl"]
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*"
    ]
    # Restrict log delivery to the same AWS account
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  # Deny access from untrusted IPs and principals
  statement {
    sid    = "RestrictAccessToTrustedIPs"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*"
    ]
    # Deny access if source IP is NOT from approved ranges
    condition {
      test     = "NotIpAddress"
      variable = "aws:SourceIp"
      values   = ["208.54.0.0/17", "206.29.160.0/19", "122.161.78.201/32"]
    }
    condition {
      test     = "Bool"
      variable = "aws:ViaAWSService"
      values   = ["false"]
    }

    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*"
      ]
    }

    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalServiceName"
      values   = ["delivery.logs.amazonaws.com"]
    }
  }

  # Deny non-TLS access
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this[0].arn, "${aws_s3_bucket.this[0].arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

##############################
# Attach Bucket Policy (as per TMO Standard)
##############################
resource "aws_s3_bucket_policy" "this" {
  count      = var.existing_s3_bucket_name == "" ? 1 : 0
  bucket     = aws_s3_bucket.this[0].id
  policy     = data.aws_iam_policy_document.bucket_policy[0].json
  depends_on = [aws_s3_bucket_public_access_block.this]
}

##############################
# Enforce Bucket Ownership Controls
##############################
resource "aws_s3_bucket_ownership_controls" "this" {
  count  = var.existing_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.this[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# --- S3 BUCKET LIFECYCLE RULE (180 Days) - as per TMO standard---
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.existing_s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.this[0].id

  rule {
    id     = "lifecycle rule"
    status = "Enabled"
    filter {}

    expiration {
      days = 180
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}