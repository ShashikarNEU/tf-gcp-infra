# Alerting on the golden signals: errors, latency, saturation.
# AWS equivalent: CloudWatch alarms -> SNS topic -> email.

resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email == "" ? 0 : 1
  display_name = "Webapp alerts"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

locals {
  alert_channels = google_monitoring_notification_channel.email[*].name
}

resource "google_monitoring_alert_policy" "lb_5xx" {
  display_name          = "Webapp: load balancer 5xx responses"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "5xx rate > 1/s for 5 min"

    condition_threshold {
      filter          = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/request_count\" AND metric.label.response_code_class = 500"
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "lb_latency" {
  display_name          = "Webapp: p99 latency high"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "p99 total latency > 2s for 5 min"

    condition_threshold {
      filter          = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/total_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = 2000 # ms
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "fleet_cpu" {
  display_name          = "Webapp: fleet CPU saturated"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "Average CPU > 85% for 10 min (autoscaler at max?)"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\" AND metric.label.instance_name = starts_with(\"app-\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      duration        = "600s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }
}

# 2nd-gen Cloud Functions run on Cloud Run, so failed invocations show up as 5xx requests.
resource "google_monitoring_alert_policy" "function_errors" {
  display_name          = "Verify-email function failing"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "Function 5xx responses for 5 min"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.label.service_name = \"${var.cloud_function_name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.label.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
}
