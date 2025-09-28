variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-2"
}


variable "bucket_name" {
  description = "The name of the S3 bucket to create"
  type        = string
  default     = "cloudfront-headers"
}

variable "env" {
  description = "The environment to deploy resources in"
  type        = string
  default     = "dev"
}