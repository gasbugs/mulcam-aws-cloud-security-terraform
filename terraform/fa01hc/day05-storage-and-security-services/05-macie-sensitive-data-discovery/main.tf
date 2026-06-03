data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_macie2_account" "main" {
  finding_publishing_frequency = var.finding_publishing_frequency
  status                       = "ENABLED"
}

resource "aws_s3_bucket" "sample" {
  bucket = "${local.name_prefix}-sample-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "sample" {
  bucket = aws_s3_bucket.sample.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sample" {
  bucket = aws_s3_bucket.sample.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "sample" {
  bucket = aws_s3_bucket.sample.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_macie2_classification_job" "sample" {
  job_type            = "ONE_TIME"
  name                = "${local.name_prefix}-sample-discovery"
  sampling_percentage = 100

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.sample.bucket]
    }
  }

  depends_on = [
    aws_macie2_account.main,
  ]
}
