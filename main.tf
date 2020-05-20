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
  function_name = "AskSac-HelloFunction"

  s3_bucket = aws_s3_bucket.lambda_pkgs_bucket.id
  s3_key    = "lambdas/hello.zip"
  source_code_hash = filebase64sha256("./dist/hello.zip")

  handler = "hello.handler"
  runtime = "nodejs12.x"

  role = aws_iam_role.asksac_services_lambda_exec_role.arn
  depends_on = [aws_iam_role_policy_attachment.lambda_exec_policy]
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

# Creates API Gateway and Resource Mapping

resource "aws_api_gateway_rest_api" "asksac_services_apig" {
  name          = "asksac-services-apig"
  description   = "AskSac Services REST API Gateway"
}

resource "aws_api_gateway_resource" "asksac_api_hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.asksac_services_apig.id
  parent_id   = aws_api_gateway_rest_api.asksac_services_apig.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_api_method" {
  rest_api_id = aws_api_gateway_rest_api.asksac_services_apig.id
  resource_id = aws_api_gateway_resource.asksac_api_hello_resource.id
  http_method = "GET"
  authorization = "NONE"
}

# Integrate API Gateway Resource with HelloFunction Lambda

resource "aws_api_gateway_integration" "lambda_api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.asksac_services_apig.id
  resource_id             = aws_api_gateway_resource.asksac_api_hello_resource.id
  http_method             = aws_api_gateway_method.hello_api_method.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_function_lambda.invoke_arn
  integration_http_method = "POST"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_function_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-east-1:229984062599:${aws_api_gateway_rest_api.asksac_services_apig.id}/*/${aws_api_gateway_method.hello_api_method.http_method}${aws_api_gateway_resource.asksac_api_hello_resource.path}"
}

# Creates an API Gateway Deployment

resource "aws_api_gateway_deployment" "hello_api_prod_deployment" {
  rest_api_id = aws_api_gateway_rest_api.asksac_services_apig.id
  stage_name = "api"
  depends_on = [
    aws_api_gateway_method.hello_api_method,
    aws_api_gateway_integration.lambda_api_integration
  ]
}

# Outputs 

output "url" {
  value = "${aws_api_gateway_deployment.hello_api_prod_deployment.invoke_url}${aws_api_gateway_resource.asksac_api_hello_resource.path}"
}
