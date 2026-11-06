resource "google_service_account" "custom-service-account" {
  account_id   = "custom-service-account"
  display_name = "csa"
}

resource "google_compute_region_instance_template" "instance_template" {
  name_prefix  = "instance-template-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = var.image
    disk_type    = var.type
    disk_size_gb = var.size
    auto_delete  = true

    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.key_vm.id
    }
  }

  # No access_config block = no external IP. Ingress comes only through the
  # load balancer; egress goes through Cloud NAT / Private Google Access.
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
  }

  metadata_startup_script = templatefile("${path.module}/scripts/startup.sh.tftpl", {
    project_id = var.project_id
  })

  service_account {
    email  = var.email
    scopes = var.scopes # must include cloud-platform so the VM can read Secret Manager
  }

  tags = var.target_tags

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_kms_crypto_key_iam_binding.crypto_key_vm,
    google_secret_manager_secret_version.app,
    google_secret_manager_secret_iam_member.app_accessor,
  ]
}

resource "google_compute_health_check" "http2-health-check" {
  name        = "http2-health-check"
  description = "Health check via http2"

  timeout_sec         = var.timeout_sec
  check_interval_sec  = var.check_interval_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port         = var.port
    request_path = var.request_path
  }
}

resource "google_compute_region_instance_group_manager" "grp_manager" {
  name               = "appserver-igm"
  base_instance_name = "app"
  region             = var.region

  version {
    instance_template = google_compute_region_instance_template.instance_template.id
  }

  named_port {
    name = var.webapp_subnet_name
    port = var.named_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http2-health-check.id
    initial_delay_sec = var.initial_delay_sec
  }

  # CI rolls out new templates with gcloud; don't let Terraform roll them back.
  lifecycle {
    ignore_changes = [version]
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "my-region-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.grp_manager.id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.cooldown_period

    cpu_utilization {
      target = var.cpu_utilization_target
    }
  }
}
