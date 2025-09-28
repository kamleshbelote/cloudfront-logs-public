// CloudFront invalidations
resource "null_resource" "cloudfront_invalidation" {
  triggers = {
    invalidations_time = timestamp()
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
        echo "Creating CloudFront invalidation..."
        aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.s3_distribution_frontend.id} --paths '/*'
        EOT        
  }

  depends_on = [aws_cloudfront_distribution.s3_distribution_frontend]
}