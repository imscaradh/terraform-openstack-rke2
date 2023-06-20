module "rke2" {
  # source = "zifeo/rke2/openstack"
  source = "./../.."

  # must be true for single-server cluster or only on first run for HA cluster
  bootstrap                 = true
  name                      = "k8s"
  #ssh_public_key_file      = "~/.ssh/id_rsa.pub"
  floating_pool             = "ext-floating1"

  # should be restricted to a secure bastion
  rules_ssh_cidr            = "0.0.0.0/0"
  rules_k8s_cidr            = "0.0.0.0/0"
  # auto load manifest form a folder (https://docs.rke2.io/advanced#auto-deploying-manifests)
  manifests_folder          = "./manifests"

  servers = [{
    name             = "server"

    flavor_name      = "a4-ram8-disk50-perf1"
    image_name       = "Ubuntu 22.04 LTS Jammy Jellyfish"
    system_user      = "ubuntu"
    boot_volume_size = 4

    rke2_version     = "v1.26.4+rke2r1"
    rke2_volume_size = 6
    # https://docs.rke2.io/install/install_options/server_config/
    rke2_config = <<EOF
etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 20

control-plane-resource-requests: kube-apiserver-cpu=75m,kube-apiserver-memory=128M,kube-scheduler-cpu=75m,kube-scheduler-memory=128M,kube-controller-manager-cpu=75m,kube-controller-manager-memory=128M,etcd-cpu=75m,etcd-memory=128M
  EOF
  }]

  agents = [
    {
      name             = "pool-a"
      nodes_count      = 1

      flavor_name      = "a4-ram8-disk50-perf1"
      image_name       = "Ubuntu 22.04 LTS Jammy Jellyfish"
      system_user      = "ubuntu"
      boot_volume_size = 4

      rke2_version     = "v1.26.4+rke2r1"
      rke2_volume_size = 6
    }
  ]

  # enable automatically agent removal of the cluster
  ff_autoremove_agent = true
  # rewrite kubeconfig
  ff_write_kubeconfig = true
  # deploy etcd backup
  ff_native_backup = true

  identity_endpoint     = "https://api.pub1.infomaniak.cloud/identity"
  object_store_endpoint = "s3.pub1.infomaniak.cloud"
}

variable "project" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type = string
}

provider "openstack" {
  tenant_name = var.project
  user_name   = var.username
  # checkov:skip=CKV_OPENSTACK_1
  password = var.password
  auth_url = "https://api.pub1.infomaniak.cloud/identity"
  region   = "dc3-a"
}

terraform {
  required_version = ">= 0.14.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
  }
}
