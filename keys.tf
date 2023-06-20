locals {
  ssh_authorized_keys_loaded = [for key in var.ssh_authorized_keys : startswith(key, "/") || startswith(key, "~") ? file(key) : key]
  ssh_authorized_key         = local.ssh_authorized_keys_loaded[0]
  ssh_authorized_keys        = slice(local.ssh_authorized_keys_loaded, 1, length(local.ssh_authorized_keys_loaded))
}

resource "random_string" "rke2_token" {
  length = 64
}

resource "openstack_compute_keypair_v2" "key" {
  name       = "${var.name}-key"
  public_key = local.ssh_authorized_key
}

resource "null_resource" "write_kubeconfig" {
  count = var.ff_write_kubeconfig && length(local.ssh_cidr) > 0 ? 1 : 0

  triggers = {
    servers = join(",", flatten([for server in module.servers : server.id]))
  }

  depends_on = [
    module.servers[0].id
  ]

  connection {
    host  = local.external_ip
    user  = var.servers[0].system_user
    agent = true
  }

  provisioner "local-exec" {
    command = <<EOF
      ssh-keygen -R ${local.external_ip} >/dev/null 2>&1
      until rsync -e "ssh -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" --rsync-path="sudo rsync" ${var.servers[0].system_user}@${local.external_ip}:/etc/rancher/rke2/rke2.yaml rke2.yaml >/dev/null 2>&1; do echo Wait rke2.yaml generation && sleep 5; done \
      && sed -i 's/127.0.0.1/${local.external_ip}/g;s/default/${var.name}/g' rke2.yaml \
      && chmod go-r rke2.yaml \
      && mv rke2.yaml ${var.name}.rke2.yaml
    EOF
  }
}


resource "openstack_identity_application_credential_v3" "rke2" {
  name = "${var.name}-credentials"
}

