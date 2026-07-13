output "s3_bucket_name" {
  value       = aws_s3_bucket.audio_bucket.id
  description = "The name of the private S3 bucket created for audio upload."
}

output "api_gateway_presigned_url_endpoint" {
  value       = "${aws_apigatewayv2_stage.default.invoke_url}presigned-url"
  description = "The HTTP API Gateway endpoint GET route URL to trigger the presigned S3 upload URL generator."
}

output "converter_lambda_name" {
  value       = aws_lambda_function.audio_converter.function_name
  description = "The name of the S3-triggered raw-to-WAV converter Lambda function."
}

output "converter_lambda_arn" {
  value       = aws_lambda_function.audio_converter.arn
  description = "The ARN of the S3-triggered raw-to-WAV converter Lambda function."
}

output "analyzer_lambda_name" {
  value       = aws_lambda_function.audio_analyzer.function_name
  description = "The name of the S3-triggered AI analysis engine Lambda function."
}

output "analyzer_lambda_arn" {
  value       = aws_lambda_function.audio_analyzer.arn
  description = "The ARN of the S3-triggered AI analysis engine Lambda function."
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.conversations_table.name
  description = "The name of the DynamoDB table storing analyzed conversations."
}

output "api_gateway_conversations_endpoint" {
  value       = "${aws_apigatewayv2_stage.default.invoke_url}conversations"
  description = "The HTTP API Gateway endpoint GET route URL to retrieve analyzed conversations from DynamoDB."
}



