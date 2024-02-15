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
