provider "google" {
  version = "~> 2.12.0"
  region = var.region
}

locals {
  cluster_type = "shared-vpc"
}


# ----------------------------------------------------------------------------------------------------------------------
# GKE
# ----------------------------------------------------------------------------------------------------------------------

module "gke" {
  source = "../../"

  project_id             = var.project_id
  name                   = "${local.cluster_type}-cluster${var.cluster_name_suffix}"
  region                 = var.region
  network                = var.network
  network_project_id     = var.network_project_id
  subnetwork             = var.subnetwork
  ip_range_pods          = var.ip_range_pods
  ip_range_services      = var.ip_range_services
  create_service_account = false
  service_account        = var.compute_engine_service_account
}
