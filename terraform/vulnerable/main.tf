terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "eu-west-3"
}

data "aws_caller_identity" "current" {}
data "aws_vpc" "default" { default = true }

# FIX 1: bucket is private (all four Block Public Access settings on)
resource "aws_s3_bucket" "public" {
  bucket        = "secproj-public-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket                  = aws_s3_bucket.public.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# FIX 2: encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "public" {
  bucket = aws_s3_bucket.public.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# (the public bucket policy is removed)

resource "aws_s3_object" "dummy" {
  bucket  = aws_s3_bucket.public.id
  key     = "fake-customers.csv"
  content = "id,name\n1,test\n"
}

# FIX 3: no inbound rules at all (nothing needs SSH)
resource "aws_security_group" "open_ssh" {
  name        = "secproj-open-ssh"
  description = "VULNERABLE: SSH open to 0.0.0.0/0"
  vpc_id      = data.aws_vpc.default.id
  ingress     = []
}

# FIX 4: least-privilege role (read one bucket only, instead of Action * on Resource *)
resource "aws_iam_role" "overpowered" {
  name = "secproj-overpowered-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "admin_star" {
  name = "admin-star"
  role = aws_iam_role.overpowered.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.public.arn, "${aws_s3_bucket.public.arn}/*"]
    }]
  })
}
