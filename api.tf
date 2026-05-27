# api.tf: everything for the drawing gallery feature
# bucket, lambda functions, api gateway, iam roles
# kept separate from the static site so this whole feature can grow (or be torn down) independently

# --- Gallery Bucket ---
# separate bucket from the website, drawings go here, not mixed with site files
# stays private, cloudfront will be the only way to serve images from it
resource "aws_s3_bucket" "gallery" {
  bucket = "aatu-gallery-2026"
}

# same pattern as the website bucket
# no direct public access, cloudfront gets in via OAC (added in cdn.tf)
resource "aws_s3_bucket_public_access_block" "gallery" {
  bucket = aws_s3_bucket.gallery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- IAM role for Lambda ---
# lambda needs an identity to run as, same concept as the github actions role
# AWS already trusts lambda
resource "aws_iam_role" "lambda_api_role" {
  name = "lambda-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# lets lambda write logs to cloudwatch so can debug it
# without this the function runs blind no output, no error messages
resource "aws_iam_role_policy_attachment" "lambda_api_policy" {
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# PutObject: upload a drawing, GetObject: read a drawing, ListBucket: list all drawings
# scoped to the gallery bucket only, not the whole account
resource "aws_iam_role_policy" "lambda_api_s3_policy" {
  name = "lambda-api-s3-policy"
  role = aws_iam_role.lambda_api_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # object-level actions need the /* path (they target files inside the bucket)
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.gallery.arn}/*"]
      },
      {
        # ListBucket targets the bucket itself, not the objects
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["${aws_s3_bucket.gallery.arn}"]
      }
    ]
  })
}

# --- Lambda: upload ---
# terraform zips the python file automatically before deploying
# source_code_hash means terraform re-deploys whenever upload.py changes (same idea as etag on s3 objects)
data "archive_file" "upload_zip" {
  type        = "zip"
  source_file = "lambda/upload.py"
  output_path = "lambda/upload.zip"
}

# receives a drawing from the browser, decodes it, stores it in the gallery bucket
# BUCKET_NAME passed as env var so the code never hardcodes which bucket it's talking to
resource "aws_lambda_function" "upload" {
  filename         = data.archive_file.upload_zip.output_path
  function_name    = "gallery-upload"
  role             = aws_iam_role.lambda_api_role.arn
  handler          = "upload.lambda_handler"
  source_code_hash = data.archive_file.upload_zip.output_base64sha256
  runtime          = "python3.12"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.gallery.id
    }
  }

  # 30s because lambda cold starts (first run spins up a fresh environment)
  # function was timing out before it could connect to S3
  timeout = 30
}

# --- Lambda: retrieve ---
data "archive_file" "retrieve_zip" {
  type        = "zip"
  source_file = "lambda/retrieve.py"
  output_path = "lambda/retrieve.zip"
}

# lists all drawings in the gallery bucket and returns their filenames
# the frontend uses those filenames to construct the cloudfront URLs for display
resource "aws_lambda_function" "retrieve" {
  filename         = data.archive_file.retrieve_zip.output_path
  function_name    = "gallery-retrieve"
  role             = aws_iam_role.lambda_api_role.arn
  handler          = "retrieve.lambda_handler"
  source_code_hash = data.archive_file.retrieve_zip.output_base64sha256
  runtime          = "python3.12"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.gallery.id
    }
  }

  timeout = 30
}

# --- API Gateway ---
# gives the lambda functions a public URL the browser can actually call
# without this there's no way to reach lambda from outside AWS
# CORS tells the browser "requests from our cloudfront domain are allowed"
# without CORS the browser silently blocks the request even if the API works fine
resource "aws_apigatewayv2_api" "gallery" {
  name          = "gallery-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://d2pyc1f7rxko9t.cloudfront.net"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

# integrations wire a route to a specific lambda function
# AWS_PROXY means the full request passes straight through to lambda, unmodified
resource "aws_apigatewayv2_integration" "upload" {
  api_id                 = aws_apigatewayv2_api.gallery.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "retrieve" {
  api_id                 = aws_apigatewayv2_api.gallery.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.retrieve.invoke_arn
  payload_format_version = "2.0"
}

# routes map HTTP method + path to an integration
# POST /upload -> upload lambda, GET /drawings -> retrieve lambda
resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.gallery.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

resource "aws_apigatewayv2_route" "retrieve" {
  api_id    = aws_apigatewayv2_api.gallery.id
  route_key = "GET /drawings"
  target    = "integrations/${aws_apigatewayv2_integration.retrieve.id}"
}

# the stage is what actually publishes the API and makes it reachable
# auto_deploy = true means changes go live immediately without a manual deploy step
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.gallery.id
  name        = "$default"
  auto_deploy = true
}

# API Gateway needs explicit permission to invoke each lambda function
# even though the integration points at them, AWS still requires this grant
# without it: API Gateway calls lambda, gets 403 forbidden back
resource "aws_lambda_permission" "upload" {
  statement_id  = "AllowAPIGatewayUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "retrieve" {
  statement_id  = "AllowAPIGatewayRetrieve"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieve.function_name
  principal     = "apigateway.amazonaws.com"
}
