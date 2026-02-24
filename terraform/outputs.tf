# EC2 Instance Outputs
output "instance_id" {
  description = "ID of the VPN EC2 instance"
  value       = aws_instance.vpn.id
}

output "elastic_ip" {
  description = "Elastic IP address of the VPN server"
  value       = aws_eip.vpn.public_ip
}

# API Gateway Outputs
output "api_endpoint" {
  description = "Base URL for the instance control API"
  value       = aws_api_gateway_stage.instance_control.invoke_url
}

output "api_key" {
  description = "API key for instance control (keep secure!)"
  value       = aws_api_gateway_api_key.instance_control.value
  sensitive   = true
}

# Headscale Configuration
output "headscale_url" {
  description = "Headscale server URL for client configuration"
  value       = local.headscale_url
}

# CloudWatch Outputs
output "log_group_instance_control" {
  description = "CloudWatch log group for instance control Lambda"
  value       = aws_cloudwatch_log_group.instance_control.name
}

output "log_group_idle_monitor" {
  description = "CloudWatch log group for idle monitor Lambda"
  value       = aws_cloudwatch_log_group.idle_monitor.name
}

# Usage Instructions
output "usage_instructions" {
  description = "Quick start instructions"
  value = <<-EOT

    ===== Secret Tunnel VPN Setup Instructions =====

    1. Elastic IP: ${aws_eip.vpn.public_ip}
    2. Instance ID: ${aws_instance.vpn.id}
    3. API Endpoint: ${aws_api_gateway_stage.instance_control.invoke_url}

    To get your API key:
      terraform output -raw api_key

    Start the VPN instance:
      curl -X POST ${aws_api_gateway_stage.instance_control.invoke_url}/instance/start \
        -H "x-api-key: $(terraform output -raw api_key)"

    Check instance status:
      curl ${aws_api_gateway_stage.instance_control.invoke_url}/instance/status \
        -H "x-api-key: $(terraform output -raw api_key)"

    SSH to instance (after starting):
      ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_eip.vpn.public_ip}

    Configure Headscale client:
      headscale_url: ${local.headscale_url}

    View logs:
      aws logs tail ${aws_cloudwatch_log_group.instance_control.name} --follow
      aws logs tail ${aws_cloudwatch_log_group.idle_monitor.name} --follow

    ==========================================
  EOT
}
