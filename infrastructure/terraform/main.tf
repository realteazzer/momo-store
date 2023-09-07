module "yc-vpc" {
  source              = "github.com/terraform-yc-modules/terraform-yc-vpc.git"
  network_name        = "momo-store-network"
  network_description = "network created with module"
  private_subnets = [{
    name           = "subnet-1"
    zone           = var.zone
    v4_cidr_blocks = ["10.10.0.0/24"]
  }
  ]
}

module "kube" {
  source     = "github.com/terraform-yc-modules/terraform-yc-kubernetes.git"
  network_id = "${module.yc-vpc.vpc_id}"

  master_locations  = [
   for s in module.yc-vpc.private_subnets:
      {
        zone      = s.zone,
        subnet_id = s.subnet_id
      }
    ]

  master_maintenance_windows = [
    {
      day        = "monday"
      start_time = "23:00"
      duration   = "3h"
    }
  ]

  node_groups = {
    "yc-k8s-ng-01"  = {
      description   = "Kubernetes nodes group 01"
      auto_scale    = {
        min         = 1
        max         = 2
        initial     = 1
      }
      node_labels   = {
        role        = "worker-01"
        environment = "prod"
      }

      max_expansion   = 1
      max_unavailable = 1
    }
  }
}
