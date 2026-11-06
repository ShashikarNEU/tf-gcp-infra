# Global external HTTPS load balancer:
# forwarding rule (anycast IP :443) -> HTTPS proxy (managed cert) -> URL map -> backend service -> MIG
# AWS equivalent: Route 53 alias -> ALB HTTPS listener (ACM cert) -> rules -> target group -> ASG

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "l7-xlb-forwarding-rule"
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = var.port_range
  target                = google_compute_target_https_proxy.default.id
}

resource "google_compute_target_https_proxy" "default" {
  name             = "l7-xlb-target-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_default.name]
}

resource "google_compute_url_map" "default" {
  name            = "l7-xlb-url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_backend_service" "default" {
  name                  = "l7-xlb-backend-service"
  protocol              = var.protocol
  port_name             = var.webapp_subnet_name
  load_balancing_scheme = var.load_balancing_scheme
  timeout_sec           = var.timeout_sec_backend_service
  health_checks         = [google_compute_health_check.http2-health-check.id]

  backend {
    group           = google_compute_region_instance_group_manager.grp_manager.instance_group
    balancing_mode  = var.balancing_mode
    capacity_scaler = var.capacity_scaler
  }

  log_config {
    enable = true
  }
}

resource "google_compute_managed_ssl_certificate" "lb_default" {
  name = "myservice-ssl-cert"

  managed {
    domains = [var.full_domain_name]
  }
}
