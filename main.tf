provider "aws" {
  profile = "terraform"
  region = "us-east-1"
}

# Create S3 bucket for storing Lambda packages

resource "aws_s3_bucket" "lambda_pkgs_bucket" {
  bucket = "asksac-services-lambdas"
  acl    = "private"

  tags = {
    App        = "asksac-services"
  }
}

# Creates HelloFunction Lambda

resource "aws_s3_bucket_object" "upload_hello_to_s3" {
  bucket = aws_s3_bucket.lambda_pkgs_bucket.id
  key    = "lambdas/hello.zip"
  source = "./dist/hello.zip"
  etag = filemd5("./dist/hello.zip")
}

resource "aws_lambda_function" "hello_function_lambda" {
  function_name = "AskSacHelloFunction"

  s3_bucket = aws_s3_bucket.lambda_pkgs_bucket.id
  s3_key    = "lambdas/hello.zip"
  source_code_hash = filebase64sha256("./dist/hello.zip")

  handler = "hello.handler"
  runtime = "nodejs12.x"

  role = aws_iam_role.asksac_services_lambda_exec_role.arn
  depends_on = [aws_iam_role_policy_attachment.lambda_exec_policy]

  tags = {
    App        = "asksac-services"
  }
}

# Creates EchoFunction Lambda

resource "aws_s3_bucket_object" "upload_echo_to_s3" {
  bucket = aws_s3_bucket.lambda_pkgs_bucket.id
  key    = "lambdas/echo.zip"
  source = "./dist/echo.zip"
  etag = filemd5("./dist/echo.zip")
}

resource "aws_lambda_function" "echo_function_lambda" {
  function_name = "AskSacEchoFunction"

  s3_bucket = aws_s3_bucket.lambda_pkgs_bucket.id
  s3_key    = "lambdas/echo.zip"
  source_code_hash = filebase64sha256("./dist/echo.zip")

  handler = "echo.handler"
  runtime = "nodejs12.x"

  role = aws_iam_role.asksac_services_lambda_exec_role.arn
  depends_on = [aws_iam_role_policy_attachment.lambda_exec_policy]

  tags = {
    App        = "asksac-services"
  }
}

# Create Lambda execution IAM role, giving permissions to access other AWS services

resource "aws_iam_role" "asksac_services_lambda_exec_role" {
  name = "asksac_services_lambda_exec_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
      "Action": [
        "sts:AssumeRole"
      ],
      "Principal": {
          "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "LambdaAssumeRolePolicy"
      }
  ]
}
EOF
}

resource "aws_iam_policy" "asksac_services_lambda_policy" {
  name        = "asksac_services_lambda_policy"
  path        = "/"
  description = "IAM policy with basic permissions for Lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }, 
    {
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.asksac_services_lambda_exec_role.name
  policy_arn = aws_iam_policy.asksac_services_lambda_policy.arn
}

# Creates API Gateway 

resource "aws_apigatewayv2_api" "asksac_services_apig" {
  name          = "asksac-services-apig"
  protocol_type = "HTTP"
  description   = "AskSac Services HTTP API Gateway"

  tags = {
    App        = "asksac-services"
  }
}

resource "aws_apigatewayv2_stage" "asksac_services_default_stage" {
  api_id      = aws_apigatewayv2_api.asksac_services_apig.id
  name        = "$default"
  auto_deploy = true

  depends_on = [aws_apigatewayv2_route.asksac_services_hello_route, aws_apigatewayv2_route.asksac_services_echo_route]

  lifecycle {
    ignore_changes = [deployment_id, default_route_settings]
  }

#  route_settings {
#    route_key = aws_apigatewayv2_route.asksac_services_route.route_key
#    detailed_metrics_enabled  = true
#  }
}

# Creates Integration and Route for Hello Lambda Function

resource "aws_apigatewayv2_integration" "asksac_services_hello_integration" {
  api_id                    = aws_apigatewayv2_api.asksac_services_apig.id
  integration_type          = "AWS_PROXY"
  description               = "Hello Function Lambda Integration"

  connection_type           = "INTERNET"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.hello_function_lambda.invoke_arn
  payload_format_version    = "2.0"
}

resource "aws_apigatewayv2_route" "asksac_services_hello_route" {
  api_id    = aws_apigatewayv2_api.asksac_services_apig.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.asksac_services_hello_integration.id}"
  depends_on = [aws_apigatewayv2_integration.asksac_services_hello_integration]
}

resource "aws_lambda_permission" "apigw_lambda_hello" {
  statement_id  = "AllowExecutionHelloLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_function_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_apigatewayv2_api.asksac_services_apig.execution_arn}/*/*/*"
}

# Creates Integration and Route for Echo Lambda Function

resource "aws_apigatewayv2_integration" "asksac_services_echo_integration" {
  api_id                    = aws_apigatewayv2_api.asksac_services_apig.id
  integration_type          = "AWS_PROXY"
  description               = "Echo Function Lambda Integration"

  connection_type           = "INTERNET"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.echo_function_lambda.invoke_arn
  payload_format_version    = "2.0"
}

resource "aws_apigatewayv2_route" "asksac_services_echo_route" {
  api_id    = aws_apigatewayv2_api.asksac_services_apig.id
  route_key = "GET /echo"
  target    = "integrations/${aws_apigatewayv2_integration.asksac_services_echo_integration.id}"
  depends_on = [aws_apigatewayv2_integration.asksac_services_echo_integration]
}

resource "aws_lambda_permission" "apigw_lambda_echo" {
  statement_id  = "AllowExecutionEchoLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.echo_function_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_apigatewayv2_api.asksac_services_apig.execution_arn}/*/*/*"
}

# Outputs 

output "url" {
  value = "${aws_apigatewayv2_api.asksac_services_apig.api_endpoint}"
}

output "api_exec_arn" {
  value = "${aws_apigatewayv2_api.asksac_services_apig.execution_arn}"
}