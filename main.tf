
terraform {
  required_version = "~> 0.12"
}

# ----------------------------------------------------------------------------------------------------------------------
# Locals
# ----------------------------------------------------------------------------------------------------------------------

locals {
  service_account = var.service_account != "" ? var.service_account : "${data.google_projects.project.projects.0.project_id}-compute@developer.gserviceaccount.com"
  location        = var.regional ? var.region : var.zones[0]
  // for regional cluster - use var.zones if provided, use available otherwise, for zonal cluster use var.zones with first element extracted
  node_locations = var.regional ? coalescelist(compact(var.zones), sort(random_shuffle.available_zones.result)) : slice(var.zones, 1, length(var.zones))
  // kuberentes version
  master_version_regional = var.kubernetes_version != "latest" ? var.kubernetes_version : data.google_container_engine_versions.region.latest_master_version
  master_version_zonal    = var.kubernetes_version != "latest" ? var.kubernetes_version : data.google_container_engine_versions.zone.latest_master_version
  node_version_regional   = var.node_version != "" && var.regional ? var.node_version : local.master_version_regional
  node_version_zonal      = var.node_version != "" && ! var.regional ? var.node_version : local.master_version_zonal
  master_version          = var.regional ? local.master_version_regional : local.master_version_zonal
  node_version            = var.regional ? local.node_version_regional : local.node_version_zonal

  custom_kube_dns_config      = length(keys(var.stub_domains)) > 0
  upstream_nameservers_config = length(var.upstream_nameservers) > 0
  network_project_id          = var.network_project_id != "" ? var.network_project_id : var.project_id
  zone_count                  = length(var.zones)
  cluster_type                = var.regional ? "regional" : "zonal"
  // auto upgrade by defaults only for regional cluster as long it has multiple masters versus zonal clusters have only have a single master so upgrades are more dangerous.
  default_auto_upgrade = var.regional ? true : false

  cluster_network_policy = var.network_policy ? [{
    enabled  = true
    provider = var.network_policy_provider
    }] : [{
    enabled  = false
    provider = null
  }]

  cluster_output_name           = google_container_cluster.primary.name
  cluster_output_location       = google_container_cluster.primary.location
  cluster_output_region         = google_container_cluster.primary.region
  cluster_output_regional_zones = google_container_cluster.primary.node_locations
  cluster_output_zonal_zones    = local.zone_count > 1 ? slice(var.zones, 1, local.zone_count) : []
  cluster_output_zones          = local.cluster_output_regional_zones

  cluster_output_endpoint = google_container_cluster.primary.endpoint

  cluster_output_master_auth                        = concat(google_container_cluster.primary.*.master_auth, [])
  cluster_output_master_version                     = google_container_cluster.primary.master_version
  cluster_output_min_master_version                 = google_container_cluster.primary.min_master_version
  cluster_output_logging_service                    = google_container_cluster.primary.logging_service
  cluster_output_monitoring_service                 = google_container_cluster.primary.monitoring_service
  cluster_output_network_policy_enabled             = google_container_cluster.primary.addons_config.0.network_policy_config.0.disabled
  cluster_output_http_load_balancing_enabled        = google_container_cluster.primary.addons_config.0.http_load_balancing.0.disabled
  cluster_output_horizontal_pod_autoscaling_enabled = google_container_cluster.primary.addons_config.0.horizontal_pod_autoscaling.0.disabled
  cluster_output_kubernetes_dashboard_enabled       = google_container_cluster.primary.addons_config.0.kubernetes_dashboard.0.disabled


  cluster_output_node_pools_names    = concat(google_container_node_pool.pools.*.name, [""])
  cluster_output_node_pools_versions = concat(google_container_node_pool.pools.*.version, [""])

  cluster_master_auth_list_layer1 = local.cluster_output_master_auth
  cluster_master_auth_list_layer2 = local.cluster_master_auth_list_layer1[0]
  cluster_master_auth_map         = local.cluster_master_auth_list_layer2[0]
  # cluster locals
  cluster_name                               = local.cluster_output_name
  cluster_location                           = local.cluster_output_location
  cluster_region                             = local.cluster_output_region
  cluster_zones                              = sort(local.cluster_output_zones)
  cluster_endpoint                           = local.cluster_output_endpoint
  cluster_ca_certificate                     = local.cluster_master_auth_map["cluster_ca_certificate"]
  cluster_master_version                     = local.cluster_output_master_version
  cluster_min_master_version                 = local.cluster_output_min_master_version
  cluster_logging_service                    = local.cluster_output_logging_service
  cluster_monitoring_service                 = local.cluster_output_monitoring_service
  cluster_node_pools_names                   = local.cluster_output_node_pools_names
  cluster_node_pools_versions                = local.cluster_output_node_pools_versions
  cluster_network_policy_enabled             = ! local.cluster_output_network_policy_enabled
  cluster_http_load_balancing_enabled        = ! local.cluster_output_http_load_balancing_enabled
  cluster_horizontal_pod_autoscaling_enabled = ! local.cluster_output_horizontal_pod_autoscaling_enabled
  cluster_kubernetes_dashboard_enabled       = ! local.cluster_output_kubernetes_dashboard_enabled

}

# ----------------------------------------------------------------------------------------------------------------------
# GKE
# ----------------------------------------------------------------------------------------------------------------------

resource "random_shuffle" "available_zones" {
  input        = data.google_compute_zones.available.names
  result_count = 3
}

resource "google_container_cluster" "primary" {
  provider = google

  name            = var.name
  description     = var.description
  project         = var.project_id
  resource_labels = var.cluster_resource_labels

  location          = local.location
  node_locations    = local.node_locations
  cluster_ipv4_cidr = var.cluster_ipv4_cidr
  network           = data.google_compute_network.gke_network.self_link

  dynamic "network_policy" {
    for_each = local.cluster_network_policy

    content {
      enabled  = network_policy.value.enabled
      provider = network_policy.value.provider
    }
  }

  subnetwork         = data.google_compute_subnetwork.gke_subnetwork.self_link
  min_master_version = local.master_version

  logging_service    = var.logging_service
  monitoring_service = var.monitoring_service

  dynamic "master_authorized_networks_config" {
    for_each = var.master_authorized_networks_config
    content {
      dynamic "cidr_blocks" {
        for_each = master_authorized_networks_config.value.cidr_blocks
        content {
          cidr_block   = lookup(cidr_blocks.value, "cidr_block", "")
          display_name = lookup(cidr_blocks.value, "display_name", "")
        }
      }
    }
  }

  master_auth {
    username = var.basic_auth_username
    password = var.basic_auth_password

    client_certificate_config {
      issue_client_certificate = var.issue_client_certificate
    }
  }

  addons_config {
    http_load_balancing {
      disabled = ! var.http_load_balancing
    }

    horizontal_pod_autoscaling {
      disabled = ! var.horizontal_pod_autoscaling
    }

    kubernetes_dashboard {
      disabled = ! var.kubernetes_dashboard
    }

    network_policy_config {
      disabled = ! var.network_policy
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.ip_range_pods
    services_secondary_range_name = var.ip_range_services
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  lifecycle {
    ignore_changes = [node_pool]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  node_pool {
    name               = "default-pool"
    initial_node_count = var.initial_node_count

    node_config {
      service_account = lookup(var.node_pools[0], "service_account", local.service_account)
    }
  }


  remove_default_node_pool = var.remove_default_node_pool
}

resource "google_container_node_pool" "pools" {
  provider = google-beta
  count    = length(var.node_pools)
  name     = var.node_pools[count.index]["name"]
  project  = var.project_id
  max_pods_per_node = var.max_node_pods
  location = local.location
  cluster  = google_container_cluster.primary.name
  version = lookup(var.node_pools[count.index], "auto_upgrade", false) ? "" : lookup(
    var.node_pools[count.index],
    "version",
    local.node_version,
  )
  initial_node_count = lookup(
    var.node_pools[count.index],
    "initial_node_count",
    lookup(var.node_pools[count.index], "min_count", 1),
  )

  autoscaling {
    min_node_count = lookup(var.node_pools[count.index], "min_count", 1)
    max_node_count = lookup(var.node_pools[count.index], "max_count", 100)
  }

  management {
    auto_repair  = lookup(var.node_pools[count.index], "auto_repair", true)
    auto_upgrade = lookup(var.node_pools[count.index], "auto_upgrade", local.default_auto_upgrade)
  }

  node_config {
    image_type   = lookup(var.node_pools[count.index], "image_type", "COS")
    machine_type = lookup(var.node_pools[count.index], "machine_type", "n1-standard-2")
    labels = merge(
      {
        "cluster_name" = var.name
      },
      {
        "node_pool" = var.node_pools[count.index]["name"]
      },
      var.node_pools_labels["all"],
      var.node_pools_labels[var.node_pools[count.index]["name"]],
    )
    metadata = merge(
      {
        "cluster_name" = var.name
      },
      {
        "node_pool" = var.node_pools[count.index]["name"]
      },
      var.node_pools_metadata["all"],
      var.node_pools_metadata[var.node_pools[count.index]["name"]],
      {
        "disable-legacy-endpoints" = var.disable_legacy_metadata_endpoints
      },
    )
    dynamic "taint" {
      for_each = concat(
        var.node_pools_taints["all"],
        var.node_pools_taints[var.node_pools[count.index]["name"]],
      )
      content {
        effect = taint.value.effect
        key    = taint.value.key
        value  = taint.value.value
      }
    }
    tags = concat(
      ["gke-${var.name}"],
      ["gke-${var.name}-${var.node_pools[count.index]["name"]}"],
      var.node_pools_tags["all"],
      var.node_pools_tags[var.node_pools[count.index]["name"]],
    )

    disk_size_gb = lookup(var.node_pools[count.index], "disk_size_gb", 100)
    disk_type    = lookup(var.node_pools[count.index], "disk_type", "pd-standard")
    service_account = lookup(
      var.node_pools[count.index],
      "service_account",
      local.service_account,
    )
    preemptible = lookup(var.node_pools[count.index], "preemptible", false)

    oauth_scopes = concat(
      var.node_pools_oauth_scopes["all"],
      var.node_pools_oauth_scopes[var.node_pools[count.index]["name"]],
    )

    guest_accelerator = [
      for guest_accelerator in lookup(var.node_pools[count.index], "accelerator_count", 0) > 0 ? [{
        type  = lookup(var.node_pools[count.index], "accelerator_type", "")
        count = lookup(var.node_pools[count.index], "accelerator_count", 0)
        }] : [] : {
        type  = guest_accelerator["type"]
        count = guest_accelerator["count"]
      }
    ]
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
