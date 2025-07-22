provider "aws" {
  region = var.region
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_dynamodb_table" "high_scores" {
  name         = "${var.project_name}-high-scores"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "game_id"
  range_key = "score"

  attribute {
    name = "game_id"
    type = "S"
  }

  attribute {
    name = "score"
    type = "N"
  }

  tags = {
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.high_scores.arn]
  }
}

resource "aws_iam_policy" "dynamodb_access" {
  name   = "${var.project_name}-dynamodb-access"
  policy = data.aws_iam_policy_document.dynamodb_policy.json
}

resource "aws_iam_role_policy_attachment" "dynamodb_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

resource "aws_lambda_function" "high_score_handler" {
  filename         = "${var.lambda_zip_filename}"
  function_name    = "${var.project_name}-handler"
  handler          = "lambda.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec.arn
  source_code_hash = filebase64sha256(var.lambda_zip_filename)
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.high_scores.name
    }
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.high_score_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = var.api_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://dantelore.com"]
    allow_methods = ["OPTIONS", "GET", "POST"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.high_score_handler.invoke_arn
}

resource "aws_apigatewayv2_route" "post_score" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /score"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_scores" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /score/{game_id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}