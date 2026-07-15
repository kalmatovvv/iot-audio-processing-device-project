resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-presigned-url-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.environment}-presigned-url-lambda-policy"
  description = "Provides least-privilege permissions: logging to CloudWatch, s3:PutObject to the raw audio bucket path, and scanning DynamoDB."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.audio_bucket.arn}/raw/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.conversations_table.arn
        ]
      }

    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role" "converter_lambda_role" {
  name = "${var.environment}-audio-converter-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "converter_lambda_policy" {
  name        = "${var.environment}-audio-converter-lambda-policy"
  description = "Allows audio converter Lambda to log, read/write raw/wav files, and trigger Transcribe jobs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.audio_bucket.arn}/raw/*",
          "${aws_s3_bucket.audio_bucket.arn}/transcripts/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "transcribe:StartTranscriptionJob"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "converter_policy_attach" {
  role       = aws_iam_role.converter_lambda_role.name
  policy_arn = aws_iam_policy.converter_lambda_policy.arn
}

resource "aws_iam_role" "analyzer_lambda_role" {
  name = "${var.environment}-audio-analyzer-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "analyzer_lambda_policy" {
  name        = "${var.environment}-audio-analyzer-lambda-policy"
  description = "Allows analyzer Lambda to write CloudWatch logs, read/write S3 objects, invoke Amazon Bedrock models, and write to DynamoDB."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.audio_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-*",
          "arn:aws:bedrock:*::foundation-model/meta.llama3-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = [
          aws_dynamodb_table.conversations_table.arn
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "analyzer_policy_attach" {
  role       = aws_iam_role.analyzer_lambda_role.name
  policy_arn = aws_iam_policy.analyzer_lambda_policy.arn
}

