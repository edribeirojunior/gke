data "google_compute_network" "gke_network" {
  provider = google

  name    = var.network
  project = local.network_project_id
}

data "google_compute_subnetwork" "gke_subnetwork" {
  provider = google

  name    = var.subnetwork
  region  = var.region
  project = local.network_project_id
}
