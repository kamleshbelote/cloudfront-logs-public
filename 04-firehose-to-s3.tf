// Terraform configuration for Kinesis Data Firehose to deliver CloudFront real-time logs to S3
// IAM Role for Firehose to S3 Delivery
resource "aws_iam_role" "firehose_to_s3_role" {
  name = "firehose-to-s3-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "firehose.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

// IAM Policy for Firehose to Access S3 and Kinesis
resource "aws_iam_role_policy" "firehose_to_s3_policy" {
  name = "firehose-to-s3-policy-${var.env}"
  role = aws_iam_role.firehose_to_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListStreams"
        ]
        Resource = aws_kinesis_stream.cloudfront_streams.arn
      }
    ]
  })
}

// Kinesis Data Firehose delivery stream to push logs to S3
resource "aws_kinesis_firehose_delivery_stream" "cloudfront_to_s3" {
  name        = "cloudfront-realtime-logs-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.cloudfront_streams.arn
    role_arn           = aws_iam_role.firehose_to_s3_role.arn
  }
  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_to_s3_role.arn
    bucket_arn          = aws_s3_bucket.frontend.arn
    prefix              = "cloudfront-realtime-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "cloudfront-realtime-logs-errors/"
    buffering_interval  = 300 # 5 minutes
    buffering_size      = 5   # 5 MB
    compression_format  = "GZIP"
  }

  tags = {
    Name = "CloudFront Real-time Logs to S3"
  }
}


// Output S3 location where logs will be stored
output "cloudfront_logs_s3_location" {
  value       = "s3://${aws_s3_bucket.frontend.bucket}/cloudfront-realtime-logs/"
  description = "S3 location where CloudFront real-time logs are stored"
}