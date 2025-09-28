resource "aws_cloudfront_response_headers_policy" "security_headers_policy" {
  name = "security-headers-policy"

  security_headers_config {
    content_security_policy {
      override                = true
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-src 'none'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests;"
    }
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "no-referrer"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    xss_protection {
      mode_block = true
      override   = true
      protection = true
      report_uri = ""
    }
  }
}

resource "aws_cloudfront_cache_policy" "custom_cache_policy" {
  name = "custom-cache-policy"

  default_ttl = 600
  max_ttl     = 900
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }

}

resource "aws_cloudfront_distribution" "s3_distribution_frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-frontend-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  tags = {
    Name        = "CloudFront Distribution for S3 Frontend"
    Environment = "Dev"
  }
  enabled             = true
  is_ipv6_enabled     = false
  comment             = "CloudFront Distribution for S3 Frontend"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-frontend-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 600
    max_ttl                = 900
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  // Ordered cache behavior
  ordered_cache_behavior {
    path_pattern     = "app/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-frontend-origin"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 600
    max_ttl                = 900
    compress               = true

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers_policy.id
    cache_policy_id            = aws_cloudfront_cache_policy.custom_cache_policy.id

    // Add real-time logging for this path pattern
    realtime_log_config_arn = aws_cloudfront_realtime_log_config.realtime_log.arn

  }

  depends_on = [
    aws_s3_bucket_policy.frontend_policy,
    aws_cloudfront_response_headers_policy.security_headers_policy,
    aws_cloudfront_cache_policy.custom_cache_policy,
    aws_cloudfront_realtime_log_config.realtime_log
  ]
}


// Output cloudfront domain name
output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.s3_distribution_frontend.domain_name
  description = "The domain name of the CloudFront distribution"
}

