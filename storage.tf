
# ---- THE BUCKET ----
# The storage box itself.
resource "aws_s3_bucket" "site" {
  bucket = "aatu-portfolio-2026"
}

# ---- WEBSITE CONFIG ----
# Tells the bucket serve as website, index.html as the home page
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

# ---- PUBLIC ACCESS BLOCK ----
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- FILES IN THE BUCKET ----
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")
}

resource "aws_s3_object" "photo" {
  bucket       = aws_s3_bucket.site.id
  key          = "aatu.jpg"
  source       = "aatu.jpg"
  content_type = "image/jpeg"
  etag         = filemd5("aatu.jpg")
}