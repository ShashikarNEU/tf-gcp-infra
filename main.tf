provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = var.db_subnet_cidr
}

resource "google_compute_route" "webapp_route" {
  name             = var.tf_route_name
  network          = google_compute_network.vpc_network.self_link
  dest_range       = var.dest_range_route
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}



