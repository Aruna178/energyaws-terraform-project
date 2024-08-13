# Create a CloudWatch Log Group for the Application
resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = 30
}

# Create CloudWatch Logs Metric Filter for Error Logs
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.app_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.app.name

  filter_pattern = "[ERROR]"

  metric_transformation {
    name      = var.metric_name
    namespace = var.namespace
    value     = "1"
  }
}

# Create CloudWatch Alarm for Application Errors
resource "aws_cloudwatch_metric_alarm" "app_error_alarm" {
  alarm_name          = "${var.app_name}-error-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = var.metric_name
  namespace           = var.namespace
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This alarm triggers when the error count is 5 or more within 1 minute."
  alarm_actions       = [var.sns_topic_arn]
}

output "application_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "application_error_alarm_name" {
  value = aws_cloudwatch_metric_alarm.app_error_alarm.alarm_name
}

