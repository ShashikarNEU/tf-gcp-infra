resource "google_pubsub_topic" "verify_email" {
  name                       = var.pubsub_topic_name
  message_retention_duration = var.pubsub_topic_message_retention_duration
}

# Note: the Cloud Function does not read from this pull subscription. Its
# Eventarc trigger creates and manages its own push subscription on the topic,
# and function failures are retried per var.retry_policy and alerted on in
# monitoring.tf. This subscription only retains a copy of each message.
resource "google_pubsub_subscription" "verify_email_subscription" {
  name  = "verify_email_subscription"
  topic = google_pubsub_topic.verify_email.id
}
