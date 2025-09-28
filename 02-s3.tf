// Create the S3 bucket with a unique name
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.bucket_name}-${random_id.bucket_id.hex}"
  tags = {
    Name        = "Cloud Front Static Website Bucket"
    Environment = "Dev"
  }

}

// Create a unique suffix for the S3 bucket name
resource "random_id" "bucket_id" {
  byte_length = 4
}

// Set the bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend.id
  // Set the ownership controls
  // BucketOwnerPreferred: Objects uploaded by other AWS accounts will be owned by the bucket owner
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

// Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

// Configure the bucket policy to allow CloudFront access
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for S3 ${aws_s3_bucket.frontend.bucket}"
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket     = aws_s3_bucket.frontend.id
  policy     = data.aws_iam_policy_document.s3_policy.json
  depends_on = [aws_s3_bucket_public_access_block.frontend_public_access]

}

// IAM policy to allow CloudFront to access the S3 bucket
data "aws_iam_policy_document" "s3_policy" {
  statement {
    # Allow CloudFront to access S3 objects
    actions = ["s3:GetObject"]
    # Specify the S3 bucket ARN
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    # Specify the CloudFront Origin Access Identity
    principals {
      # CloudFront OAI
      type = "AWS"
      # CloudFront OAI ARN
      identifiers = ["${aws_cloudfront_origin_access_identity.oai.iam_arn}"]
    }
  }
}

// Output the S3 bucket name
output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket
  description = "The name of the S3 bucket"
}