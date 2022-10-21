resource "oci_core_instance" "server_1" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad_3.name
  display_name        = "k3s-server-1.${var.custom_domain}"
  shape               = local.server_instance_config.shape_id
  source_details {
    source_id   = local.server_instance_config.source_id
    source_type = local.server_instance_config.source_type
  }
  shape_config {
    memory_in_gbs = local.server_instance_config.ram
    ocpus         = local.server_instance_config.ocpus
  }
  create_vnic_details {
    subnet_id  = var.cluster_subnet_id
    private_ip = local.server_instance_config.server_ip_1
    nsg_ids    = [var.permit_rules_nsg_id]
    skip_source_dest_check = true
  }
  metadata = {
    "ssh_authorized_keys" = local.server_instance_config.metadata.ssh_authorized_keys
    "user_data" = base64encode(
      templatefile("${path.module}/templates/server_user_data.sh",
        {
          server_1_ip    = local.server_instance_config.server_ip_1,
          host_name      = "k3s-server-1.${var.custom_domain}",
          ssh_public_key = var.ssh_authorized_keys[0],
          token          = random_string.cluster_token.result,
          email_address  = var.email_address,
          custom_domain  = var.custom_domain,
          k3s_version    = var.k3s_version,
          nlb_private_ip = var.nlb_private_ip,
          nlb_public_ip  = var.nlb_public_ip
      })
    )
  }
}

resource "oci_core_instance" "worker" {
  count               = 0
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad_3.name
  display_name        = "k3s-worker-${count.index + 1}"
  shape               = local.worker_instance_config.shape_id
  source_details {
    source_id   = local.worker_instance_config.source_id
    source_type = local.worker_instance_config.source_type
  }
  shape_config {
    memory_in_gbs = local.worker_instance_config.ram
    ocpus         = local.worker_instance_config.ocpus
  }
  create_vnic_details {
    subnet_id = var.cluster_subnet_id
    private_ip = "10.0.0.2${count.index +3}"
    nsg_ids   = [var.permit_rules_nsg_id]
    skip_source_dest_check = "true"
  }
  metadata = {
    "ssh_authorized_keys" = local.worker_instance_config.metadata.ssh_authorized_keys
    "user_data" = base64encode(
      templatefile("${path.module}/templates/worker_user_data.sh",
        {
          server_1_ip    = local.server_instance_config.server_ip_1,
          host_name      = "k3s-worker-${count.index + 1}",
          ssh_public_key = var.ssh_authorized_keys[0],
          token          = random_string.cluster_token.result,
          email_address  = var.email_address,
          k3s_version    = var.k3s_version,
          nlb_private_ip = var.nlb_private_ip,
          nlb_public_ip  = var.nlb_public_ip
    }))
  }
  depends_on = [oci_core_instance.server_1]
}
resource "oci_core_instance" "worker2" {
  count               = 2
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad_1.name
  display_name        = "k3s-worker-${count.index + 2}.${var.custom_domain}"
  shape               = local.worker_instance_config2.shape_id
  source_details {
    source_id   = local.worker_instance_config2.source_id
    source_type = local.worker_instance_config2.source_type
  }
  shape_config {
    memory_in_gbs = local.worker_instance_config2.ram
    ocpus         = local.worker_instance_config2.ocpus
  }
  create_vnic_details {
    subnet_id = var.cluster_subnet_id
    private_ip = "10.0.0.2${count.index +2}"
    nsg_ids   = [var.permit_rules_nsg_id]
    skip_source_dest_check = true
  }
  metadata = {
    "ssh_authorized_keys" = local.worker_instance_config2.metadata.ssh_authorized_keys
    "user_data" = base64encode(
      templatefile("${path.module}/templates/worker_user_data.sh",
        {
          server_1_ip    = local.server_instance_config.server_ip_1,
          host_name      = "k3s-worker-${count.index + 2}.${var.custom_domain}",
          ssh_public_key = var.ssh_authorized_keys[0],
          token          = random_string.cluster_token.result,
          email_address  = var.email_address,
          k3s_version    = var.k3s_version,
          nlb_private_ip = var.nlb_private_ip,
          nlb_public_ip  = var.nlb_public_ip
    }))
  }
  depends_on = [oci_core_instance.server_1]
}

