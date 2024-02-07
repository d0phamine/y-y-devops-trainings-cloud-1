terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "./tf_key.json"
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "my_network" {}

resource "yandex_vpc_subnet" "my_network_subnet" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my_network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_container_registry" "registry1" {
  name = "registry1"
}



locals {
  folder_id = "b1g665agp5589ntuqkr1"
  service-accounts = toset([
    "catgpt-sa",
  ])
  catgpt-sa-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-roles" {
  for_each  = local.catgpt-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["catgpt-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

resource "yandex_compute_instance" "catgpt-1" {
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["catgpt-sa"].id
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }
  scheduling_policy {
    preemptible = true
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.my_network_subnet.id
    nat       = true
  }
  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "30"
      image_id = data.yandex_compute_image.coi.id
    }
  }
  metadata = {
    docker-compose = file("${path.module}/docker-compose.yaml")
    ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "catgpt-2" {
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["catgpt-sa"].id
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }
  scheduling_policy {
    preemptible = true
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.my_network_subnet.id
    nat       = true
  }
  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "30"
      image_id = data.yandex_compute_image.coi.id
    }
  }
  metadata = {
    user-data      = file("${path.module}/cloud-config.yml")
    docker-compose = file("${path.module}/docker-compose.yaml")
    ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_lb_target_group" "lb_group" {
  name = "my-target-group"
  #  region_id = "${yandex_vpc_subnet.ysubnet.zone}"

  # target {
  #   subnet_id = yandex_vpc_subnet.my_network_subnet.id
  #   address   = yandex_compute_instance_group.catgpt-group.network_interface.0.ip_address
  # }

  target {
    subnet_id = yandex_vpc_subnet.my_network_subnet.id
    address   = yandex_compute_instance.catgpt-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.my_network_subnet.id
    address   = yandex_compute_instance.catgpt-2.network_interface.0.ip_address
  }
}


resource "yandex_lb_network_load_balancer" "catgpt-balancer" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.lb_group.id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}

# resource "yandex_compute_instance_group" "catgpt-group" {
#   name                = "catpgt-group"
#   folder_id           = local.folder_id
#   service_account_id  = yandex_iam_service_account.service-accounts["catgpt-sa"].id
#   deletion_protection = true
#   instance_template {
#     platform_id = "standard-v2"
#     resources {
#       cores         = 2
#       memory        = 1
#       core_fraction = 5
#     }
#     scheduling_policy {
#       preemptible = true
#     }
#     network_interface {
#       network_id = "${yandex_vpc_network.my_network.id}"
#       subnet_ids = ["${yandex_vpc_subnet.my_network_subnet.id}"]
#       nat        = true
#     }
#     boot_disk {
#       initialize_params {
#         type     = "network-hdd"
#         size     = "30"
#         image_id = data.yandex_compute_image.coi.id
#       }
#     }
#     labels = {
#       label1 = "label1-value"
#       label2 = "label2-value"
#     }
#     metadata = {
#       docker-compose = file("${path.module}/docker-compose.yaml")
#       ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
#     }
#   }
#   scale_policy {
#     fixed_scale {
#       size = 2
#     }
#   }

#   allocation_policy {
#     zones = ["ru-central1-a"]
#   }

#   deploy_policy {
#     max_unavailable = 2
#     max_creating    = 2
#     max_expansion   = 2
#     max_deleting    = 2
#   }
# }


