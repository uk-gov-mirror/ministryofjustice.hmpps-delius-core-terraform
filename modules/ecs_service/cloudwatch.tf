resource "aws_cloudwatch_log_group" "log_group" {
  count             = local.create_log_group ? 1 : 0
  name              = "${var.environment_name}/${var.service_name}"
  retention_in_days = var.log_retention_in_days
  tags              = merge(var.tags, { Name = "${var.environment_name}/${var.service_name}" })
}

# CloudWatch Logs Alarms
resource "aws_cloudwatch_log_metric_filter" "log_error_filter" {
  count          = var.log_error_pattern != "" && local.create_log_group ? 1 : 0
  log_group_name = aws_cloudwatch_log_group.log_group.0.name
  name           = "${var.environment_name}-${var.service_name}-logged-errors"
  pattern        = var.log_error_pattern
  metric_transformation {
    name          = "LoggedErrors"
    namespace     = "${var.environment_name}/${var.service_name}"
    value         = 1
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "log_error_warning_alarm" {
  count               = var.log_error_pattern != "" && local.create_log_group && var.notification_arn != "" ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-logged-errors-cwa--warning"
  alarm_description   = "Error messages were detected in the `${var.service_name}` logs."
  comparison_operator = "GreaterThanUpperThreshold"
  threshold_metric_id = "ad1"
  evaluation_periods  = 2
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  actions_enabled     = false # Disabled initially, while anomaly detection models are trained

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1)"
    label       = "${aws_cloudwatch_log_metric_filter.log_error_filter.0.metric_transformation.0.name} (expected)"
    return_data = true
  }

  metric_query {
    id          = "m1"
    label       = aws_cloudwatch_log_metric_filter.log_error_filter.0.metric_transformation.0.name
    return_data = true
    metric {
      namespace   = aws_cloudwatch_log_metric_filter.log_error_filter.0.metric_transformation.0.namespace
      metric_name = aws_cloudwatch_log_metric_filter.log_error_filter.0.metric_transformation.0.name
      period      = 300
      stat        = "Sum"
    }
  }
}

# Healthy host count alarms
resource "aws_cloudwatch_metric_alarm" "healthy_hosts_warning_alarm" {
  count               = var.create_lb_alarms && var.enable_healthy_host_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-healthy-hosts-cwa--warning"
  alarm_description   = "One or more `${var.service_name}` instances stopped responding."
  namespace           = "AWS/ApplicationELB"
  statistic           = "Minimum"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 2
  period              = 60
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  dimensions = {
    LoadBalancer = data.aws_lb.lb.0.arn_suffix
    TargetGroup  = aws_lb_target_group.target_group.0.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "healthy_hosts_fatal_alarm" {
  count               = var.create_lb_alarms && var.enable_healthy_host_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-healthy-hosts-cwa--fatal"
  alarm_description   = "All `${var.service_name}` instances stopped responding."
  namespace           = "AWS/ApplicationELB"
  statistic           = "Minimum"
  metric_name         = "HealthyHostCount"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  evaluation_periods  = 2
  period              = 60
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  dimensions = {
    LoadBalancer = data.aws_lb.lb.0.arn_suffix
    TargetGroup  = aws_lb_target_group.target_group.0.arn_suffix
  }
}

# Response time alarms
resource "aws_cloudwatch_metric_alarm" "response_time_warning_alarm" {
  count               = var.create_lb_alarms && var.enable_response_time_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-response-time-cwa--warning"
  alarm_description   = "Average response time for the `${var.service_name}` service exceeded 1 second."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 1
  period              = 300
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  dimensions = {
    LoadBalancer = data.aws_lb.lb.0.arn_suffix
    TargetGroup  = aws_lb_target_group.target_group.0.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "response_time_critical_alarm" {
  count               = var.create_lb_alarms && var.enable_response_time_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-response-time-cwa--critical"
  alarm_description   = "Average response time for the `${var.service_name}` service exceeded 5 seconds."
  namespace           = "AWS/ApplicationELB"
  statistic           = "Average"
  metric_name         = "TargetResponseTime"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  evaluation_periods  = 1
  period              = 300
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  dimensions = {
    LoadBalancer = data.aws_lb.lb.0.arn_suffix
    TargetGroup  = aws_lb_target_group.target_group.0.arn_suffix
  }
}

# Response code alarms
resource "aws_cloudwatch_metric_alarm" "response_code_5xx_warning_alarm" {
  count               = var.create_lb_alarms && var.enable_response_code_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-5xx-response-cwa--warning"
  alarm_description   = "The `${var.service_name}` service responded with 5xx errors."
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  metric_name         = "HTTPCode_Target_5XX_Count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 2
  period              = 60
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  dimensions = {
    LoadBalancer = data.aws_lb.lb.0.arn_suffix
    TargetGroup  = aws_lb_target_group.target_group.0.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "response_code_5xx_critical_alarm" {
  count               = var.create_lb_alarms && var.enable_response_code_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-${var.service_name}-5xx-response-cwa--critical"
  alarm_description   = "The `${var.service_name}` service responded with 5xx errors at an elevated rate (over 10/minute)."
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  metric_name         = "HTTPCode_Target_5XX_Count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 10
  evaluation_periods  = 2
  period              = 60
  alarm_actions       = [var.notification_arn]
  ok_actions          = [var.notification_arn]
  dimensions = {
    LoadBalancer = data.aws_lb.lb.0.arn_suffix
    TargetGroup  = aws_lb_target_group.target_group.0.arn_suffix
  }
}
