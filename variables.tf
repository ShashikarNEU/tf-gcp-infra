variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "region" {
  description = "The region for the resources"
  type        = string
}

variable "zone" {
  description = "The zone for the resources"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "webapp_subnet_cidr" {
  description = "The CIDR range for the webapp subnet"
  type        = string
}

variable "db_subnet_cidr" {
  description = "The CIDR range for the db subnet"
  type        = string
}

variable "dest_range_route" {
  description = "The destination range for the route"
  type        = string
}

variable "webapp_subnet_name" {
  description = "The name of the webapp subnet"
  type        = string
}

variable "db_subnet_name" {
  description = "The name of the db subnet"
  type        = string
}

variable "tf_route_name" {
  description = "route name"
  type        = string
}

variable "routing_mode" {
  description = "routing mode"
  type        = string
}

variable "email" {
  type = string
}

variable "scopes" {
  type = list(string)
}

variable "interface" {
  type = string
}

variable "image" {
  type = string
}

variable "type" {
  type = string
}

variable "size" {
  type = number
}

variable "name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "ports" {
  type = list(string)
}

variable "source_tags" {
  type = list(string)
}

variable "source_ranges" {
  type = list(string)
}

variable "firewall_allow_name" {
  type = string
}

variable "firewall_deny_name" {
  type = string
}

variable "target_tags" {
  type = list(string)
}

variable "database_version" {
  type = string
}

variable "sql_tier" {
  type = string
}

variable "sql_disk_type" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "ttl" {
  type = number
}

variable "dns_type" {
  type = string
}

variable "db_name" {
  type = string
}

variable "retry_policy" {
  type = string
}

variable "event_type" {
  type = string
}

variable "vpc_connector_egress_settings" {
  type = string
}

variable "entry_point" {
  type = string
}

variable "runtime" {
  type = string
}
variable "vpc_ip_cidr_range" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "bucket_source" {
  type = string
}

variable "bucket_location" {
  type = string
}

variable "pubsub_topic_name" {
  type = string
}

variable "pubsub_topic_message_retention_duration" {
  type = string
}

variable "google_vpc_access_connector_name" {
  type = string
}

variable "cloud_function_name" {
  type = string
}

variable "email_workflow" {
  type = string
}

variable "timeout_sec" {
  type = number
}

variable "check_interval_sec" {
  type = number
}

variable "healthy_threshold" {
  type = number
}

variable "unhealthy_threshold" {
  type = number
}

variable "port" {
  type = string
}

variable "request_path" {
  type = string
}

variable "named_port" {
  type = number
}

variable "initial_delay_sec" {
  type = number
}

variable "max_replicas" {
  type = number
}

variable "min_replicas" {
  type = number
}

variable "cooldown_period" {
  type = number
}

variable "cpu_utilization_target" {
  type = number
}

variable "load_balancing_scheme" {
  type = string
}

variable "port_range" {
  type = string
}

variable "protocol" {
  type = string
}

variable "full_domain_name" {
  type = string
}

variable "balancing_mode" {
  type = string
}

variable "capacity_scaler" {
  type = number
}

variable "timeout_sec_backend_service" {
  type = number
}

variable "email_ce_service_agent" {
  type = string
}