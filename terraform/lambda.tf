# Package Lambda functions
data "archive_file" "instance_control" {
  type        = "zip"
  source_file = "${path.module}/files/lambda_instance_control.py"
  output_path = "${path.module}/.terraform/lambda_instance_control.zip"
}

data "archive_file" "idle_monitor" {
  type        = "zip"
  source_file = "${path.module}/files/lambda_idle_monitor.py"
  output_path = "${path.module}/.terraform/lambda_idle_monitor.zip"
}

# Instance Control Lambda Function
resource "aws_lambda_function" "instance_control" {
  filename         = data.archive_file.instance_control.output_path
  function_name    = "${var.project_name}-instance-control"
  role             = aws_iam_role.instance_control_lambda.arn
  handler          = "lambda_instance_control.lambda_handler"
  source_code_hash = data.archive_file.instance_control.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      INSTANCE_ID = aws_instance.vpn.id
    }
  }

  tags = {
    Name = "${var.project_name}-instance-control"
  }
}

# Idle Monitor Lambda Function
resource "aws_lambda_function" "idle_monitor" {
  filename         = data.archive_file.idle_monitor.output_path
  function_name    = "${var.project_name}-idle-monitor"
  role             = aws_iam_role.idle_monitor_lambda.arn
  handler          = "lambda_idle_monitor.lambda_handler"
  source_code_hash = data.archive_file.idle_monitor.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      INSTANCE_ID            = aws_instance.vpn.id
      HEADSCALE_URL          = local.headscale_url
      IDLE_TIMEOUT_MINUTES   = var.idle_timeout_minutes
      CLOUDWATCH_NAMESPACE   = var.project_name
    }
  }

  tags = {
    Name = "${var.project_name}-idle-monitor"
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "instance_control" {
  name        = "${var.project_name}-instance-control-api"
  description = "API for controlling VPN instance lifecycle"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-instance-control-api"
  }
}

# API Gateway Resource: /instance
resource "aws_api_gateway_resource" "instance" {
  rest_api_id = aws_api_gateway_rest_api.instance_control.id
  parent_id   = aws_api_gateway_rest_api.instance_control.root_resource_id
  path_part   = "instance"
}

# API Gateway Resource: /instance/start
resource "aws_api_gateway_resource" "start" {
  rest_api_id = aws_api_gateway_rest_api.instance_control.id
  parent_id   = aws_api_gateway_resource.instance.id
  path_part   = "start"
}

# API Gateway Resource: /instance/stop
resource "aws_api_gateway_resource" "stop" {
  rest_api_id = aws_api_gateway_rest_api.instance_control.id
  parent_id   = aws_api_gateway_resource.instance.id
  path_part   = "stop"
}

# API Gateway Resource: /instance/status
resource "aws_api_gateway_resource" "status" {
  rest_api_id = aws_api_gateway_rest_api.instance_control.id
  parent_id   = aws_api_gateway_resource.instance.id
  path_part   = "status"
}

# API Gateway Method: POST /instance/start
resource "aws_api_gateway_method" "start" {
  rest_api_id      = aws_api_gateway_rest_api.instance_control.id
  resource_id      = aws_api_gateway_resource.start.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

# API Gateway Method: POST /instance/stop
resource "aws_api_gateway_method" "stop" {
  rest_api_id      = aws_api_gateway_rest_api.instance_control.id
  resource_id      = aws_api_gateway_resource.stop.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

# API Gateway Method: GET /instance/status
resource "aws_api_gateway_method" "status" {
  rest_api_id      = aws_api_gateway_rest_api.instance_control.id
  resource_id      = aws_api_gateway_resource.status.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

# Lambda Integration: start
resource "aws_api_gateway_integration" "start" {
  rest_api_id             = aws_api_gateway_rest_api.instance_control.id
  resource_id             = aws_api_gateway_resource.start.id
  http_method             = aws_api_gateway_method.start.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.instance_control.invoke_arn
}

# Lambda Integration: stop
resource "aws_api_gateway_integration" "stop" {
  rest_api_id             = aws_api_gateway_rest_api.instance_control.id
  resource_id             = aws_api_gateway_resource.stop.id
  http_method             = aws_api_gateway_method.stop.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.instance_control.invoke_arn
}

# Lambda Integration: status
resource "aws_api_gateway_integration" "status" {
  rest_api_id             = aws_api_gateway_rest_api.instance_control.id
  resource_id             = aws_api_gateway_resource.status.id
  http_method             = aws_api_gateway_method.status.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.instance_control.invoke_arn
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.instance_control.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.instance_control.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "instance_control" {
  rest_api_id = aws_api_gateway_rest_api.instance_control.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.instance.id,
      aws_api_gateway_method.start.id,
      aws_api_gateway_method.stop.id,
      aws_api_gateway_method.status.id,
      aws_api_gateway_integration.start.id,
      aws_api_gateway_integration.stop.id,
      aws_api_gateway_integration.status.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "instance_control" {
  deployment_id = aws_api_gateway_deployment.instance_control.id
  rest_api_id   = aws_api_gateway_rest_api.instance_control.id
  stage_name    = var.environment

  tags = {
    Name = "${var.project_name}-api-stage"
  }
}

# API Key
resource "aws_api_gateway_api_key" "instance_control" {
  name    = "${var.project_name}-api-key"
  enabled = true

  tags = {
    Name = "${var.project_name}-api-key"
  }
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "instance_control" {
  name = "${var.project_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.instance_control.id
    stage  = aws_api_gateway_stage.instance_control.stage_name
  }

  throttle_settings {
    rate_limit  = var.api_throttle_rate_limit
    burst_limit = var.api_throttle_burst_limit
  }

  tags = {
    Name = "${var.project_name}-usage-plan"
  }
}

# Associate API Key with Usage Plan
resource "aws_api_gateway_usage_plan_key" "instance_control" {
  key_id        = aws_api_gateway_api_key.instance_control.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.instance_control.id
}

# EventBridge Rule for Idle Monitor
resource "aws_cloudwatch_event_rule" "idle_monitor" {
  name                = "${var.project_name}-idle-monitor-schedule"
  description         = "Trigger idle monitor Lambda every ${var.idle_check_rate_minutes} minutes"
  schedule_expression = "rate(${var.idle_check_rate_minutes} minutes)"

  tags = {
    Name = "${var.project_name}-idle-monitor-schedule"
  }
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "idle_monitor" {
  rule      = aws_cloudwatch_event_rule.idle_monitor.name
  target_id = "IdleMonitorLambda"
  arn       = aws_lambda_function.idle_monitor.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "idle_monitor_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.idle_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.idle_monitor.arn
}
