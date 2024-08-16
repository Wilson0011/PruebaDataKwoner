# Configurar el proveedor de AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Variables
variable "region" {
  default = "us-east-1"
}

variable "bucket_name" {
  description = "Nombre del bucket S3 donde está almacenado lambda_function.zip"
}

variable "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
}

# Crear un rol para la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# Asignar permisos al rol de Lambda para leer la tabla DynamoDB
resource "aws_iam_policy" "dynamodb_read_policy" {
  name = "dynamodb_read_policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:${var.region}:*:table/${var.dynamodb_table_name}"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "dynamodb_read_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_read_policy.arn
}

# Crear la función Lambda
resource "aws_lambda_function" "lambda_function" {
  function_name = "lambda_function"
  s3_bucket     = var.bucket_name
  s3_key        = "lambda_function.zip"
  handler       = "index.handler"  # Ajustar según el archivo zip
  runtime       = "python3.9"      # Ajustar según la versión de Python utilizada
  role          = aws_iam_role.lambda_role.arn
}

# Crear API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "my_api"
  description = "API Gateway para leer datos de DynamoDB"
}

# Crear recurso para la API
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "data"
}

# Crear método GET para el recurso
resource "aws_api_gateway_method" "get_method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = "GET"
  authorization = "NONE"
}

# Integrar la función Lambda con API Gateway
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "aws_proxy"
  integration_type        = "aws_proxy"
  integration_uri         = aws_lambda_function.lambda_function.invoke_arn
}

# Desplegar la API
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

# Permisos para que API Gateway pueda invocar la función Lambda
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/${aws_api_gateway_method.get_method.http_method}${aws_api_gateway_resource.proxy.path}"
}

output "api_invoke_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_resource.proxy.path}"
}