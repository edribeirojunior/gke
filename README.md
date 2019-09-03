# Módulo Terraform - GCP - GKE

<!-- TODO: revisar concordância e sentido da frase abaixo. -->
Módulo do Terraform para provisionamento de recursos do Google Kubernetes Engine (GKE).

## Uso

```hcl
module "gke" {
  source = "git::ssh://git@gitlab.com/mandic-labs/terraform/modules/google/gke.git?ref=master"

  project_id                 = "<PROJECT ID>"
  name                       = "gke-test-1"
  region                     = "southamerica-east1"
  zones                      = ["southamerica-east1-a", "southamerica-east1-b", "southamerica-east1-c"]
  network                    = "vpc-01"
  subnetwork                 = "subnet-vpc-01"
  ip_range_pods              = "southamerica-east1-01-gke-01-pods"
  ip_range_services          = "southamerica-east1-01-gke-01-services"
  http_load_balancing        = false
  horizontal_pod_autoscaling = true
  kubernetes_dashboard       = true
  network_policy             = true

  node_pools = [
    {
      name               = "default-node-pool"
      machine_type       = "n1-standard-2"
      min_count          = 1
      max_count          = 100
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = "project-service-account@<PROJECT ID>.iam.gserviceaccount.com"
      preemptible        = false
      initial_node_count = 80
    },
  ]

  node_pools_oauth_scopes = {
    all = []

    default-node-pool = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    all = {}

    default-node-pool = {
      default-node-pool = true
    }
  }

  node_pools_metadata = {
    all = {}

    default-node-pool = {
      node-pool-metadata-custom-value = "my-node-pool"
    }
  }

  node_pools_taints = {
    all = []

    default-node-pool = [
      {
        key    = "default-node-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      },
    ]
  }

  node_pools_tags = {
    all = []

    default-node-pool = [
      "default-node-pool",
    ]
  }
}
```

## Recursos provisionados

<!-- TODO: alterar lista de recursos provisionados pelo módulo. -->
- Instância GKE


## Customizações

<!-- TODO: ajustar exemplo de customização conforme necessário. -->


## Exemplos

<!-- TODO: alterar título e link abaixo conforme diretório de exemplo criado. -->
- [Exemplo simples](examples/simple-example/)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Licença

Copyright © 2019 Mandic Cloud Solutions. Todos os direitos reservados.
