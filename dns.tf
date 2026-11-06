# The managed zone is created once outside Terraform (it holds the registrar NS records).
data "google_dns_managed_zone" "env_dns_zone" {
  name = var.domain_name
}

resource "google_dns_record_set" "default" {
  name         = data.google_dns_managed_zone.env_dns_zone.dns_name
  managed_zone = data.google_dns_managed_zone.env_dns_zone.name
  type         = var.dns_type
  ttl          = var.ttl
  rrdatas      = [google_compute_global_forwarding_rule.default.ip_address]
}
