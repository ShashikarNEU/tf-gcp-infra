resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = var.webapp_subnet_cidr

  # VMs have no external IPs, so they reach Google APIs (Pub/Sub, Logging,
  # Secret Manager) through Private Google Access.
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "db_subnet" {
  name                     = var.db_subnet_name
  region                   = var.region
  network                  = google_compute_network.vpc_network.self_link
  ip_cidr_range            = var.db_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_route" "webapp_route" {
  name             = var.tf_route_name
  network          = google_compute_network.vpc_network.self_link
  dest_range       = var.dest_range_route
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# Outbound-only internet access for private VMs and the VPC connector
# (AWS equivalent: NAT Gateway in a public subnet).
resource "google_compute_router" "nat_router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc_network.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Private Services Access: gives Cloud SQL a private IP inside this VPC.
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  address_type  = "INTERNAL"
  prefix_length = 16
  purpose       = "VPC_PEERING"
  network       = google_compute_network.vpc_network.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Global external HTTP(S) LB traffic and health checks both come from
# Google Front End ranges, so this is the only ingress the app needs.
# Only the app and health-check ports are opened, not every TCP port.
resource "google_compute_firewall" "allow_lb_and_health_checks" {
  name      = "fw-allow-lb-and-health-checks"
  network   = google_compute_network.vpc_network.self_link
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = distinct([tostring(var.named_port), var.port])
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = var.target_tags
}

# Lets the Cloud Function reach Cloud SQL's private IP.
resource "google_vpc_access_connector" "connector" {
  name          = var.google_vpc_access_connector_name
  ip_cidr_range = var.vpc_ip_cidr_range
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}
