# ---- BUCKET POLICY (NEW WITH CLOUDFRONT) ----

resource "aws_s3_bucket_policy" "site" {
   bucket     = aws_s3_bucket.site.id

   policy = jsonencode({
     Version = "2012-10-17"
     Statement = [
       {
         Sid       = "GetObjectForCloudFrontOnly"
         Effect    = "Allow"
         Principal = {
              "Service" = "cloudfront.amazonaws.com"
            }
         Action    = "s3:GetObject"
         Resource  = "${aws_s3_bucket.site.arn}/*"
         Condition = {
            StringEquals = {
              "aws:SourceArn" = "${aws_cloudfront_distribution.site.arn}"
            }
         }
       }
     ]
   })
 }

# ---- OAC (Origin Access Control) ----
# Lets CloudFront prove its identity to the private
# S3 bucket so it is allowed to read the files.
# Gets connected to the bucket inside the CloudFront distribution.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "portfolio-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


# ---- CLOUDFRONT DISTRIBUTION ----
# The CDN. It will pull files from the S3 bucket and serve them to visitors.

resource "aws_cloudfront_distribution" "site" {
  enabled = true
  default_root_object = "index.html"

  # Where cloudfront pulls files from.. s3
  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "s3-portfolio"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # Basic rules
  default_cache_behavior {
    target_origin_id = "s3-portfolio"
    viewer_protocol_policy = "redirect-to-https" #Forces HTTPS
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Caches based on URL only (no cookies, headers, etc).
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Actual HTTPS certificate.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
