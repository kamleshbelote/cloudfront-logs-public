// IAM Role for Kinesis
resource "aws_iam_role" "cloudfront_kinesis_role" {
  name = "cloudfront-kinesis-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "cloudfront.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

// IAM Policy for Kinesis Role
resource "aws_kinesis_stream" "cloudfront_streams" {
  name = "cloudfront-stream-${var.env}"
  // Shards determine the capacity of the stream
  shard_count = 1
  // Retention period in hours (default is 24 hours)
  retention_period = 24
  tags = {
    Name = "CloudFront Kinesis Stream - ${var.env}"
  }
}

resource "aws_iam_role_policy" "kinesis_policy" {
  name = "cloudfront-kinesis-policy-${var.env}"
  role = aws_iam_role.cloudfront_kinesis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Action = [
        "kninesis:DescribeStream",
        "kinesis:PutRecord",
        "kinesis:PutRecords"
      ],
      Resource = aws_kinesis_stream.cloudfront_streams.arn
    }]
  })
}



// Real-time log configuration for CloudFront
resource "aws_cloudfront_realtime_log_config" "realtime_log" {
  name = "realtime-log-config-${var.env}"

  endpoint {
    stream_type = "Kinesis"
    kinesis_stream_config {
      role_arn   = aws_iam_role.cloudfront_kinesis_role.arn
      stream_arn = aws_kinesis_stream.cloudfront_streams.arn
    }
  }

  sampling_rate = 100
  // How to get IP address of the viewer
  // ClientIP: The IP address of the viewer that made the request
  // X-Forwarded-For: The value of the X-Forwarded-For HTTP header
  // All: Both ClientIP and X-Forwarded-For
  // Default is ClientIP
  // For more details, see: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/real-time-logs.html#real-time-logs-fields
  //viewer_ip
  // Add unique ID of request
  
  fields = [
    "timestamp",
    "c-ip",
    "cs-method",
    "cs-uri-stem",
    "sc-status",
    "x-edge-location",
    "x-edge-response-result-type",
    "x-edge-request-id",
    "x-host-header",
    "cs-protocol",
    "cs-bytes",
    "sc-bytes",
    "time-taken",
    "cs-user-agent" // Browser information
  ]

}