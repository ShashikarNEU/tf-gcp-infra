provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  count                           = var.number_of_vpc
  name                            = var.number_of_vpc == 1 ? var.vpc_name : "${var.vpc_name}-${count.index + 1}"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  count         = var.number_of_vpc
  name          = var.number_of_vpc == 1 ? var.webapp_subnet_name : "${var.webapp_subnet_name}-${count.index + 1}"
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

resource "google_compute_subnetwork" "db_subnet" {
  count         = var.number_of_vpc
  name          = var.number_of_vpc == 1 ? var.db_subnet_name : "${var.db_subnet_name}-${count.index + 1}"
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].self_link
  ip_cidr_range = var.db_subnet_cidr
}

resource "google_compute_route" "webapp_route" {
  count            = var.number_of_vpc
  name             = var.number_of_vpc == 1 ? var.tf_route_name : "${var.tf_route_name}-${count.index + 1}"
  network          = google_compute_network.vpc_network[count.index].self_link
  dest_range       = var.dest_range_route
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}



