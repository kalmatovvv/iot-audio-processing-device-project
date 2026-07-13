# ==========================================
# 1. Local Variables & Identifiers
# ==========================================

locals {
  common_tags = {
    Environment = var.environment
    Project     = "CloudMicPresigned"
    ManagedBy   = "Terraform"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 6
}

# ==========================================
# 2. Private S3 Ingestion Bucket
# ==========================================

resource "aws_s3_bucket" "audio_bucket" {
  bucket        = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"
  force_destroy = true # Convenient for dev/testing environments

  tags = local.common_tags
}

# Block all public S3 access (least-privilege requirement)
resource "aws_s3_bucket_public_access_block" "audio_bucket_public_block" {
  bucket                  = aws_s3_bucket.audio_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Attach bucket policy to grant AWS Transcribe access to read wav and write JSON transcripts
resource "aws_s3_bucket_policy" "transcribe_access" {
  bucket = aws_s3_bucket.audio_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTranscribeAccess"
        Effect    = "Allow"
        Principal = {
          Service = "transcribe.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.audio_bucket.arn}/*"
        ]
      }
    ]
  })
}

# CORS Rule configuration (to facilitate testing from web browsers)
resource "aws_s3_bucket_cors_configuration" "audio_bucket_cors" {
  bucket = aws_s3_bucket.audio_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# 7-day expiration lifecycle policy to save storage costs
resource "aws_s3_bucket_lifecycle_configuration" "audio_bucket_lifecycle" {
  bucket = aws_s3_bucket.audio_bucket.id

  rule {
    id     = "expire-raw-after-7-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# DynamoDB Table to store conversation analysis results
resource "aws_dynamodb_table" "conversations_table" {
  name         = "${var.environment}-conversations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.common_tags
}


# ==========================================
# 3. ZIP Packaging & Lambda Function
# ==========================================

# Dynamically bundle the Python lambda handler
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/app.py"
  output_path = "${path.module}/lambda/app.zip"
}

# Create CloudWatch Log Group explicitly
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.environment}-presigned-url-generator"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_lambda_function" "presigned_url_generator" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "${var.environment}-presigned-url-generator"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.handler"
  runtime          = "python3.10"
  timeout          = 15

  environment {
    variables = {
      BUCKET_NAME    = aws_s3_bucket.audio_bucket.id
      DYNAMODB_TABLE = aws_dynamodb_table.conversations_table.name
      URL_EXPIRATION = var.url_expiration_seconds
    }
  }


  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group
  ]

  tags = local.common_tags
}

# ==========================================
# 4. API Gateway HTTP API (v2)
# ==========================================

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.environment}-audio-presigned-api"
  protocol_type = "HTTP"

  tags = local.common_tags
}

# Auto-deploy stage definition
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

# Lambda integration mapping (using Proxy v2 format)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presigned_url_generator.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Route definition for GET /presigned-url
resource "aws_apigatewayv2_route" "get_presigned_url" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /presigned-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Route definition for GET /conversations
resource "aws_apigatewayv2_route" "get_conversations" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /conversations"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}


# Grant permission to API Gateway v2 to invoke Lambda
resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url_generator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# ==========================================
# 5. Audio Converter ZIP & Lambda Function
# ==========================================

# Package the converter Lambda script
data "archive_file" "converter_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/converter.py"
  output_path = "${path.module}/lambda/converter.zip"
}

# Log Group for Converter Lambda
resource "aws_cloudwatch_log_group" "converter_log_group" {
  name              = "/aws/lambda/${var.environment}-audio-converter"
  retention_in_days = 7

  tags = local.common_tags
}

# Lambda function for raw-to-WAV conversion
resource "aws_lambda_function" "audio_converter" {
  filename         = data.archive_file.converter_zip.output_path
  source_code_hash = data.archive_file.converter_zip.output_base64sha256
  function_name    = "${var.environment}-audio-converter"
  role             = aws_iam_role.converter_lambda_role.arn
  handler          = "converter.handler"
  runtime          = "python3.10"
  timeout          = 30

  depends_on = [
    aws_cloudwatch_log_group.converter_log_group
  ]

  tags = local.common_tags
}

# ==========================================
# 6. AI Analysis Engine ZIP & Lambda Function
# ==========================================

# Package the analyzer Lambda script
data "archive_file" "analyzer_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/analyzer.py"
  output_path = "${path.module}/lambda/analyzer.zip"
}

# Log Group for Analyzer Lambda
resource "aws_cloudwatch_log_group" "analyzer_log_group" {
  name              = "/aws/lambda/${var.environment}-audio-analyzer"
  retention_in_days = 7

  tags = local.common_tags
}

# Lambda function for Bedrock analysis and Webhook forwarding
resource "aws_lambda_function" "audio_analyzer" {
  filename         = data.archive_file.analyzer_zip.output_path
  source_code_hash = data.archive_file.analyzer_zip.output_base64sha256
  function_name    = "${var.environment}-audio-analyzer"
  role             = aws_iam_role.analyzer_lambda_role.arn
  handler          = "analyzer.handler"
  runtime          = "python3.10"
  timeout          = 60 # Transcribe JSON download + Bedrock LLM invocation takes time

  environment {
    variables = {
      WEBHOOK_URL      = var.webhook_url
      BEDROCK_MODEL_ID = "meta.llama3-1-8b-instruct-v1:0"
      BEDROCK_REGION   = "us-west-2"
      DYNAMODB_TABLE   = aws_dynamodb_table.conversations_table.name
    }
  }




  depends_on = [
    aws_cloudwatch_log_group.analyzer_log_group
  ]

  tags = local.common_tags
}

# ==========================================
# 7. S3 Notification & Trigger Configuration
# ==========================================

# Allow S3 service to invoke the audio converter Lambda
resource "aws_lambda_permission" "allow_s3_to_invoke_converter" {
  statement_id  = "AllowExecutionFromS3BucketConverter"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audio_converter.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.audio_bucket.arn
}

# Allow S3 service to invoke the analysis engine Lambda
resource "aws_lambda_permission" "allow_s3_to_invoke_analyzer" {
  statement_id  = "AllowExecutionFromS3BucketAnalyzer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audio_analyzer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.audio_bucket.arn
}

# Configure S3 event notifications for both raw ingestion and transcription completion
resource "aws_s3_bucket_notification" "audio_upload_notification" {
  bucket = aws_s3_bucket.audio_bucket.id

  # 1. Trigger raw-to-WAV converter when a raw file is added
  lambda_function {
    lambda_function_arn = aws_lambda_function.audio_converter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".raw"
  }

  # 2. Trigger AI analysis engine when a Transcribe output JSON lands in S3
  lambda_function {
    lambda_function_arn = aws_lambda_function.audio_analyzer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "transcripts/"
    filter_suffix       = ".json"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_to_invoke_converter,
    aws_lambda_permission.allow_s3_to_invoke_analyzer
  ]
}
