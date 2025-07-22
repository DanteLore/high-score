variable "region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-west-1"
}

variable "table_name" {
  description = "Name of the DynamoDB table for storing high scores"
  type        = string
  default     = "highscores"
}

variable "ddb_read_capacity" {
  description = "Provisioned read capacity units for the DynamoDB table"
  type        = number
  default     = 1
}

variable "ddb_write_capacity" {
  description = "Provisioned write capacity units for the DynamoDB table"
  type        = number
  default     = 1
}

variable "lambda_handler" {
  description = "Lambda function handler (file_name.exported_function)"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.9"
}

variable "lambda_source_path" {
  description = "Path to the directory containing Lambda source code"
  type        = string
  default     = "./lambda"
}

variable "api_name" {
  description = "Name of the API Gateway HTTP API"
  type        = string
  default     = "highscore-api"
}

variable "project_name" {
  description = "Highscore as a service"
  type        = string
  default     = "high-score"
}

variable "lambda_zip_filename" {
  description = "The ZIP file with the lambda in it"
  type        = string
  default     = "lambda.zip"
}
