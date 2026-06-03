data "aws_partition" "current" {}

resource "aws_securityhub_account" "main" {
  enable_default_standards = var.enable_default_standards
}

resource "aws_securityhub_standards_subscription" "foundational" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [
    aws_securityhub_account.main,
  ]
}

resource "aws_sns_topic" "incidents" {
  name = "${local.name_prefix}-incidents"
}

data "aws_iam_policy_document" "sns_events" {
  statement {
    sid = "AllowEventBridgePublish"

    actions = [
      "sns:Publish",
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.incidents.arn,
    ]
  }
}

resource "aws_sns_topic_policy" "incidents" {
  arn    = aws_sns_topic.incidents.arn
  policy = data.aws_iam_policy_document.sns_events.json
}

resource "aws_cloudwatch_event_rule" "securityhub_high_severity" {
  name        = "${local.name_prefix}-high-severity-findings"
  description = "Routes new high and critical Security Hub findings to the incident notification topic."

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_sns" {
  rule      = aws_cloudwatch_event_rule.securityhub_high_severity.name
  target_id = "securityhub-incident-topic"
  arn       = aws_sns_topic.incidents.arn

  depends_on = [
    aws_sns_topic_policy.incidents,
  ]
}

resource "aws_ssmincidents_replication_set" "main" {
  region {
    name = var.aws_region
  }
}

resource "aws_ssmincidents_response_plan" "main" {
  name         = local.response_plan_name
  display_name = "FA01HC Security Incident Response"
  chat_channel = [aws_sns_topic.incidents.arn]

  incident_template {
    title   = "SecurityHub high severity finding"
    impact  = "3"
    summary = "Triage high or critical Security Hub findings and coordinate response actions."

    notification_target {
      sns_topic_arn = aws_sns_topic.incidents.arn
    }
  }

  depends_on = [
    aws_ssmincidents_replication_set.main,
  ]
}
