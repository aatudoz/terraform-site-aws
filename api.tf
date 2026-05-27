# This Terraform configuration sets up an AWS S3 bucket for a gallery application, 
# along with two AWS Lambda functions for uploading and retrieving images. 
# It also defines the necessary IAM roles and policies to allow the Lambda functions to interact with the S3 bucket securely.

# --- Gallery Bucket ---
resource "aws_s3_bucket" "gallery" {
  bucket = "aatu-gallery-2026"
}

# ---- PUBLIC ACCESS BLOCK ----
resource "aws_s3_bucket_public_access_block" "gallery" {
  bucket = aws_s3_bucket.gallery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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

resource "aws_iam_role_policy_attachment" "lambda_api_policy" {
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_api_s3_policy" {
  name = "lambda-api-s3-policy"
  role = aws_iam_role.lambda_api_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.gallery.arn}/*"]
      },
      {
      Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = ["${aws_s3_bucket.gallery.arn}"]
      }
    ]
  })
}



# ---- ZIP THE LAMBDA CODE ----

data "archive_file" "upload_zip" {
  type        = "zip"
  source_file = "lambda/upload.py"
  output_path = "lambda/upload.zip"
}

# ---- LAMBDA FUNCTION - UPLOAD ----

resource "aws_lambda_function" "upload" {
  filename      = data.archive_file.upload_zip.output_path
  function_name = "gallery-upload"
  role          = aws_iam_role.lambda_api_role.arn
  handler       = "upload.lambda_handler"
  source_code_hash   = data.archive_file.upload_zip.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
        #From upload.py:
      BUCKET_NAME = aws_s3_bucket.gallery.id
    }
  }
}



# --- ZIP RETRIEVE THE LAMBDA CODE ---

data "archive_file" "retrieve_zip" {
  type        = "zip"
  source_file = "lambda/retrieve.py"
  output_path = "lambda/retrieve.zip"
}

# ---- LAMBDA FUNCTION - RETRIEVE ----

resource "aws_lambda_function" "retrieve" {
  filename      = data.archive_file.retrieve_zip.output_path
  function_name = "gallery-retrieve"
  role          = aws_iam_role.lambda_api_role.arn
  handler       = "retrieve.lambda_handler"
  source_code_hash   = data.archive_file.retrieve_zip.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
        #From retrieve.py:
      BUCKET_NAME = aws_s3_bucket.gallery.id
    }
  }
}



# ---- API GATEWAY ---

resource "aws_apigatewayv2_api" "gallery" {
  name          = "gallery-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["https://d2pyc1f7rxko9t.cloudfront.net"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}




# ---- API GATEWAY INTEGRATION WITH LAMBDA UPLOAD ----

resource "aws_apigatewayv2_integration" "upload" {
  api_id = aws_apigatewayv2_api.gallery.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.upload.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "retrieve" {
  api_id = aws_apigatewayv2_api.gallery.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.retrieve.invoke_arn
  payload_format_version = "2.0"
}



# ---- API GATEWAY ROUTES ----

resource "aws_apigatewayv2_route" "upload" {
    api_id = aws_apigatewayv2_api.gallery.id
    route_key = "POST /upload"
    target = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

resource "aws_apigatewayv2_route" "retrieve" {
    api_id = aws_apigatewayv2_api.gallery.id
    route_key = "GET /drawings"
    target = "integrations/${aws_apigatewayv2_integration.retrieve.id}"
}



# ---- LAMBDA API STAGE ----

resource "aws_apigatewayv2_stage" "default" {
    api_id = aws_apigatewayv2_api.gallery.id
    name = "$default"
    auto_deploy = true
}


# --- LAMBDA PERSMISSIONS TO API GATEWAY ---

resource "aws_lambda_permission" "upload" {
    statement_id = "AllowAPIGatewayUpload"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.upload.function_name
    principal = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "retrieve" {
    statement_id = "AllowAPIGatewayRetrieve"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.retrieve.function_name
    principal = "apigateway.amazonaws.com"
}