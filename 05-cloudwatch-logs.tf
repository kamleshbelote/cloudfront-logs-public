# resource "aws_cloudwatch_log_group" "cloudfront_logs" {
#   name              = "/aws/cloudfront/distribution/${aws_cloudfront_distribution.s3_distribution_frontend.id}"
#   retention_in_days = 7

#   tags = {
#     Name = "CloudFront Distribution Logs"
#   }

# }


// CloudWatch Log Group for real-time logs
resource "aws_cloudwatch_log_group" "cloudfront_realtime_logs" {
  name              = "/aws/cloudfront/realtime-logs"
  retention_in_days = 7

  tags = {
    Name = "CloudFront Real-time Logs"
  }
}


resource "aws_iam_role" "lambda_kinesis_to_cloudwatch_role" {
  name = "lambda-kinesis-to-cloudwatch-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

// IAM Policy for Lambda to write to CloudWatch Logs
resource "aws_iam_role_policy" "lambda_kinesis_to_cloudwatch_policy" {
  name = "lambda-kinesis-to-cloudwatch-policy-${var.env}"
  role = aws_iam_role.lambda_kinesis_to_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.cloudfront_realtime_logs.arn}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ],
        Resource = aws_kinesis_stream.cloudfront_streams.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

// Lambda function to process Kinesis stream and write to CloudWatch Logs
resource "aws_lambda_function" "kinesis_to_cloudwatch" {
  filename         = "lambda/kinesis_to_cloudwatch.zip"
  function_name    = "kinesis-to-cloudwatch-${var.env}"
  role             = aws_iam_role.lambda_kinesis_to_cloudwatch_role.arn
  handler          = "kinesis_to_cloudwatch.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.kinesis_to_cloudwatch_zip.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      LOG_GROUP_NAME = aws_cloudwatch_log_group.cloudfront_realtime_logs.name
    }
  }


  depends_on = [
    aws_iam_role_policy.lambda_kinesis_to_cloudwatch_policy,
    data.archive_file.kinesis_to_cloudwatch_zip
  ]
}


data "archive_file" "kinesis_to_cloudwatch_zip" {
  type        = "zip"
  output_path = "lambda/kinesis_to_cloudwatch.zip"
  source_file = "lambda/kinesis_to_cloudwatch.py"
}

// Lambda event source mapping to trigger on Kinesis stream
resource "aws_lambda_event_source_mapping" "kinesis_event" {
  event_source_arn  = aws_kinesis_stream.cloudfront_streams.arn
  function_name     = aws_lambda_function.kinesis_to_cloudwatch.arn
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
  depends_on = [aws_kinesis_stream.cloudfront_streams,
    aws_lambda_function.kinesis_to_cloudwatch
  ]
}