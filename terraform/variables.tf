variable "aws_region" {
  type        = string
  description = "The AWS region where resources will be deployed."
  default     = "us-west-1"
}

variable "environment" {
  type        = string
  description = "The environment name (e.g. dev, staging, prod)."
  default     = "dev"
}

variable "bucket_name_prefix" {
  type        = string
  description = "Prefix for the S3 bucket name. A random suffix will be appended to ensure global uniqueness."
  default     = "cloud-mic-recordings"
}

variable "url_expiration_seconds" {
  type        = number
  description = "The lifetime duration of the S3 presigned URL in seconds (default is 5 minutes)."
  default     = 300
}

variable "webhook_url" {
  type        = string
  description = "The target Webhook URL where the audio analysis payload is sent via HTTP POST."
  default     = "https://bin.webhookrelay.com/v1/webhooks/20117eb5-94e3-483c-92fa-f42fac0a516f"
}
