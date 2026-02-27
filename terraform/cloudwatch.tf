# CloudWatch Log Group for Instance Control Lambda
resource "aws_cloudwatch_log_group" "instance_control" {
  name              = "/aws/lambda/${var.project_name}-instance-control"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-instance-control-logs"
  }
}

# CloudWatch Log Group for Idle Monitor Lambda
resource "aws_cloudwatch_log_group" "idle_monitor" {
  name              = "/aws/lambda/${var.project_name}-idle-monitor"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-idle-monitor-logs"
  }
}

# CloudWatch Metric Alarm: Instance State
resource "aws_cloudwatch_metric_alarm" "instance_running" {
  alarm_name          = "${var.project_name}-instance-running"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "InstanceState"
  namespace           = var.project_name
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "This metric monitors VPN instance running state"
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "${var.project_name}-instance-running-alarm"
  }
}

# CloudWatch Metric Alarm: Active Connections
resource "aws_cloudwatch_metric_alarm" "active_connections" {
  alarm_name          = "${var.project_name}-active-connections"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 12
  metric_name         = "ActiveConnections"
  namespace           = var.project_name
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alert when no active connections for extended period"
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "${var.project_name}-active-connections-alarm"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "vpn" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Instance State"
          metrics = [["${var.project_name}", "InstanceState"]]
          period  = 300
          stat    = "Maximum"
          region  = var.aws_region
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Active Connections"
          metrics = [["${var.project_name}", "ActiveConnections"]]
          period  = 300
          stat    = "Maximum"
          region  = var.aws_region
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Utilization"
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.vpn.id]]
          period = 300
          stat   = "Average"
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Network Traffic"
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.vpn.id],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.vpn.id]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Instance Control Logs"
          query  = "SOURCE '${aws_cloudwatch_log_group.instance_control.name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region = var.aws_region
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Idle Monitor Logs"
          query  = "SOURCE '${aws_cloudwatch_log_group.idle_monitor.name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region = var.aws_region
          view   = "table"
        }
      }
    ]
  })
}
