module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

# This locals entry is used to store the IP addresses of all the machines.
# Autogenerated addresses example based in 10.0.0.0/24
# Iscsi server: 10.0.0.4
# Monitoring: 10.0.0.5
# Hana ips: 10.0.0.10, 10.0.0.11
# Hana cluster vip: 10.0.0.12
# Hana cluster vip secondary: 10.0.0.13
# DRBD ips: 10.0.0.20, 10.0.0.21
# DRBD cluster vip: 10.0.0.22
# Netweaver ips: 10.0.0.30, 10.0.0.31, 10.0.0.32, 10.0.0.33
# Netweaver virtual ips: 10.0.0.34, 10.0.0.35, 10.0.0.36, 10.0.0.37
# If the addresses are provided by the user they will always have preference
locals {
  iscsi_srv_ip      = var.iscsi_srv_ip != "" ? var.iscsi_srv_ip : cidrhost(local.subnet_address_range, 4)
  monitoring_srv_ip = var.monitoring_srv_ip != "" ? var.monitoring_srv_ip : cidrhost(local.subnet_address_range, 5)

  hana_ip_start = 10
  hana_ips      = length(var.hana_ips) != 0 ? var.hana_ips : [for ip_index in range(local.hana_ip_start, local.hana_ip_start + var.hana_count) : cidrhost(local.subnet_address_range, ip_index)]

  # Virtual IP addresses if a load balancer is used. In this case the virtual ip address belongs to the same subnet than the machines
  hana_cluster_vip_lb           = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(local.subnet_address_range, local.hana_ip_start + var.hana_count)
  hana_cluster_vip_secondary_lb = var.hana_cluster_vip_secondary != "" ? var.hana_cluster_vip_secondary : cidrhost(local.subnet_address_range, local.hana_ip_start + var.hana_count + 1)

  # Virtual IP addresses if a route is used. In this case the virtual ip address belongs to a different subnet than the machines
  hana_cluster_vip_route           = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + local.hana_ip_start + var.hana_count)
  hana_cluster_vip_secondary_route = var.hana_cluster_vip_secondary != "" ? var.hana_cluster_vip_secondary : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + local.hana_ip_start + var.hana_count + 1)

  # Select the final virtual ip address
  hana_cluster_vip           = var.hana_cluster_vip_mechanism == "load-balancer" ? local.hana_cluster_vip_lb : local.hana_cluster_vip_route
  hana_cluster_vip_secondary = var.hana_cluster_vip_mechanism == "load-balancer" ? local.hana_cluster_vip_secondary_lb : local.hana_cluster_vip_secondary_route

  # 2 is hardcoded for drbd because we always deploy 4 machines
  drbd_ip_start = 20
  drbd_ips      = length(var.drbd_ips) != 0 ? var.drbd_ips : [for ip_index in range(local.drbd_ip_start, local.drbd_ip_start + 2) : cidrhost(local.subnet_address_range, ip_index)]
  # Virtual IP addresses if a route is used. In this case the virtual ip address belongs to a different subnet than the machines
  drbd_cluster_vip_lb    = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(local.subnet_address_range, local.drbd_ip_start + 2)
  drbd_cluster_vip_route = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + local.drbd_ip_start + 2)
  drbd_cluster_vip       = var.drbd_cluster_vip_mechanism == "load-balancer" ? local.drbd_cluster_vip_lb : local.drbd_cluster_vip_route

  netweaver_xscs_server_count = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 2 : 1) : 0
  netweaver_count             = var.netweaver_enabled ? local.netweaver_xscs_server_count + var.netweaver_app_server_count : 0
  netweaver_virtual_ips_count = var.netweaver_ha_enabled ? max(local.netweaver_count, 3) : max(local.netweaver_count, 2) # We need at least 2 virtual ips, if ASCS and PAS are in the same machine

  netweaver_ip_start            = 30
  netweaver_ips                 = length(var.netweaver_ips) != 0 ? var.netweaver_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_count) : cidrhost(local.subnet_address_range, ip_index)]
  netweaver_virtual_ips_lb_xscs = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_xscs_server_count) : cidrhost(local.subnet_address_range, ip_index + 4)]                                                                                               # same subnet as netweaver hosts
  netweaver_virtual_ips_lb_app  = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start + local.netweaver_xscs_server_count, local.netweaver_ip_start + local.netweaver_xscs_server_count + var.netweaver_app_server_count) : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + ip_index + 4)] # different subnet as netweaver hosts
  netweaver_virtual_ips_route   = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_virtual_ips_count) : cidrhost(cidrsubnet(local.subnet_address_range, -8, 0), 256 + ip_index + 4)]                                                                      # different subnet as netweaver hosts
  netweaver_virtual_ips         = var.netweaver_cluster_vip_mechanism == "load-balancer" ? concat(local.netweaver_virtual_ips_lb_xscs, local.netweaver_virtual_ips_lb_app) : local.netweaver_virtual_ips_route

  # Check if iscsi server has to be created
  use_sbd       = var.hana_cluster_fencing_mechanism == "sbd" || var.drbd_cluster_fencing_mechanism == "sbd" || var.netweaver_cluster_fencing_mechanism == "sbd"
  iscsi_enabled = var.sbd_storage_type == "iscsi" && ((var.hana_count > 1 && var.hana_ha_enabled) || var.drbd_enabled || (local.netweaver_count > 1 && var.netweaver_ha_enabled)) && local.use_sbd ? true : false

  # Obtain machines os_image value
  hana_os_image       = var.hana_os_image != "" ? var.hana_os_image : var.os_image
  iscsi_os_image      = var.iscsi_os_image != "" ? var.iscsi_os_image : var.os_image
  monitoring_os_image = var.monitoring_os_image != "" ? var.monitoring_os_image : var.os_image
  drbd_os_image       = var.drbd_os_image != "" ? var.drbd_os_image : var.os_image
  netweaver_os_image  = var.netweaver_os_image != "" ? var.netweaver_os_image : var.os_image
  bastion_os_image    = var.bastion_os_image != "" ? var.bastion_os_image : var.os_image

  # Netweaver password checking
  # If Netweaver is not enabled, a dummy password is passed to pass the variable validation and not require
  # a password in this case
  # Otherwise, the validation will fail unless a correct password is provided
  netweaver_master_password = var.netweaver_enabled ? var.netweaver_master_password : "DummyPassword1234"
}

module "common_variables" {
  source                              = "../generic_modules/common_variables"
  provider_type                       = "gcp"
  region                              = var.region
  deployment_name                     = local.deployment_name
  deployment_name_in_hostname         = var.deployment_name_in_hostname
  reg_code                            = var.reg_code
  reg_email                           = var.reg_email
  reg_additional_modules              = var.reg_additional_modules
  ha_sap_deployment_repo              = var.ha_sap_deployment_repo
  additional_packages                 = var.additional_packages
  public_key                          = var.public_key
  private_key                         = var.private_key
  authorized_keys                     = var.authorized_keys
  authorized_user                     = "root"
  bastion_enabled                     = var.bastion_enabled
  bastion_public_key                  = var.bastion_public_key
  bastion_private_key                 = var.bastion_private_key
  provisioner                         = var.provisioner
  provisioning_log_level              = var.provisioning_log_level
  provisioning_output_colored         = var.provisioning_output_colored
  background                          = var.background
  monitoring_enabled                  = var.monitoring_enabled
  monitoring_srv_ip                   = var.monitoring_enabled ? local.monitoring_srv_ip : ""
  offline_mode                        = var.offline_mode
  hana_hwcct                          = var.hwcct
  hana_sid                            = var.hana_sid
  hana_instance_number                = var.hana_instance_number
  hana_cost_optimized_sid             = var.hana_cost_optimized_sid
  hana_cost_optimized_instance_number = var.hana_cost_optimized_instance_number
  hana_master_password                = var.hana_master_password
  hana_cost_optimized_master_password = var.hana_cost_optimized_master_password == "" ? var.hana_master_password : var.hana_cost_optimized_master_password
  hana_primary_site                   = var.hana_primary_site
  hana_secondary_site                 = var.hana_secondary_site
  hana_inst_master                    = var.hana_inst_master
  hana_inst_folder                    = var.hana_inst_folder
  hana_fstype                         = var.hana_fstype
  hana_platform_folder                = var.hana_platform_folder
  hana_sapcar_exe                     = var.hana_sapcar_exe
  hana_archive_file                   = var.hana_archive_file
  hana_extract_dir                    = var.hana_extract_dir
  hana_client_folder                  = var.hana_client_folder
  hana_client_archive_file            = var.hana_client_archive_file
  hana_client_extract_dir             = var.hana_client_extract_dir
  hana_scenario_type                  = var.scenario_type
  hana_cluster_vip_mechanism          = var.hana_cluster_vip_mechanism
  hana_cluster_vip                    = local.hana_cluster_vip
  hana_cluster_vip_secondary          = var.hana_active_active ? local.hana_cluster_vip_secondary : ""
  hana_ha_enabled                     = var.hana_ha_enabled
  hana_ignore_min_mem_check           = var.hana_ignore_min_mem_check
  hana_cluster_fencing_mechanism      = var.hana_cluster_fencing_mechanism
  hana_sbd_storage_type               = var.sbd_storage_type
  hana_scale_out_enabled              = var.hana_scale_out_enabled
  hana_scale_out_shared_storage_type  = var.hana_scale_out_shared_storage_type
  hana_scale_out_addhosts             = var.hana_scale_out_addhosts
  hana_scale_out_standby_count        = var.hana_scale_out_standby_count
  netweaver_sid                       = var.netweaver_sid
  netweaver_ascs_instance_number      = var.netweaver_ascs_instance_number
  netweaver_ers_instance_number       = var.netweaver_ers_instance_number
  netweaver_pas_instance_number       = var.netweaver_pas_instance_number
  netweaver_master_password           = local.netweaver_master_password
  netweaver_product_id                = var.netweaver_product_id
  netweaver_inst_folder               = var.netweaver_inst_folder
  netweaver_extract_dir               = var.netweaver_extract_dir
  netweaver_swpm_folder               = var.netweaver_swpm_folder
  netweaver_sapcar_exe                = var.netweaver_sapcar_exe
  netweaver_swpm_sar                  = var.netweaver_swpm_sar
  netweaver_sapexe_folder             = var.netweaver_sapexe_folder
  netweaver_additional_dvds           = var.netweaver_additional_dvds
  netweaver_nfs_share                 = var.drbd_enabled ? "${local.drbd_cluster_vip}:/${var.netweaver_sid}" : var.netweaver_nfs_share
  netweaver_sapmnt_path               = var.netweaver_sapmnt_path
  netweaver_hana_ip                   = var.hana_ha_enabled ? local.hana_cluster_vip : element(local.hana_ips, 0)
  netweaver_hana_sid                  = var.hana_sid
  netweaver_hana_instance_number      = var.hana_instance_number
  netweaver_hana_master_password      = var.hana_master_password
  netweaver_ha_enabled                = var.netweaver_ha_enabled
  netweaver_cluster_vip_mechanism     = var.netweaver_cluster_vip_mechanism
  netweaver_cluster_fencing_mechanism = var.netweaver_cluster_fencing_mechanism
  netweaver_sbd_storage_type          = var.sbd_storage_type
  netweaver_shared_storage_type       = var.netweaver_shared_storage_type
  monitoring_hana_targets             = local.hana_ips
  monitoring_hana_targets_ha          = var.hana_ha_enabled ? local.hana_ips : []
  monitoring_hana_targets_vip         = var.hana_ha_enabled ? [local.hana_cluster_vip] : [local.hana_ips[0]] # we use the vip for HA scenario and 1st hana machine for non HA to target the active hana instance
  monitoring_drbd_targets             = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_ha          = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_vip         = var.drbd_enabled ? [local.drbd_cluster_vip] : []
  monitoring_netweaver_targets        = var.netweaver_enabled ? local.netweaver_ips : []
  monitoring_netweaver_targets_ha     = var.netweaver_enabled && var.netweaver_ha_enabled ? [local.netweaver_ips[0], local.netweaver_ips[1]] : []
  monitoring_netweaver_targets_vip    = var.netweaver_enabled ? local.netweaver_virtual_ips : []
  drbd_cluster_vip                    = local.drbd_cluster_vip
  drbd_cluster_vip_mechanism          = var.drbd_cluster_vip_mechanism
  drbd_cluster_fencing_mechanism      = var.drbd_cluster_fencing_mechanism
  drbd_sbd_storage_type               = var.sbd_storage_type
}

module "drbd_node" {
  source               = "./modules/drbd_node"
  common_variables     = module.common_variables.configuration
  name                 = var.drbd_name
  network_domain       = var.drbd_network_domain == "" ? var.network_domain : var.drbd_network_domain
  bastion_host         = module.bastion.public_ip
  drbd_count           = var.drbd_enabled == true ? 2 : 0
  machine_type         = var.drbd_machine_type
  compute_zones        = local.compute_zones
  network_name         = local.vpc_name
  network_subnet_name  = local.subnet_name
  os_image             = local.drbd_os_image
  drbd_data_disk_size  = var.drbd_data_disk_size
  drbd_data_disk_type  = var.drbd_data_disk_type
  gcp_credentials_file = var.gcp_credentials_file
  host_ips             = local.drbd_ips
  iscsi_srv_ip         = module.iscsi_server.iscsisrv_ip
  cluster_ssh_pub      = var.cluster_ssh_pub
  cluster_ssh_key      = var.cluster_ssh_key
  nfs_mounting_point   = var.drbd_nfs_mounting_point
  nfs_export_name      = var.netweaver_sid
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp,
    module.bastion
  ]
}

module "netweaver_node" {
  source                    = "./modules/netweaver_node"
  common_variables          = module.common_variables.configuration
  name                      = var.netweaver_name
  network_domain            = var.netweaver_network_domain == "" ? var.network_domain : var.netweaver_network_domain
  bastion_host              = module.bastion.public_ip
  xscs_server_count         = local.netweaver_xscs_server_count
  app_server_count          = var.netweaver_enabled ? var.netweaver_app_server_count : 0
  machine_type              = var.netweaver_machine_type
  compute_zones             = local.compute_zones
  network_name              = local.vpc_name
  network_subnet_name       = local.subnet_name
  os_image                  = local.netweaver_os_image
  gcp_credentials_file      = var.gcp_credentials_file
  host_ips                  = local.netweaver_ips
  iscsi_srv_ip              = module.iscsi_server.iscsisrv_ip
  cluster_ssh_pub           = var.cluster_ssh_pub
  cluster_ssh_key           = var.cluster_ssh_key
  netweaver_software_bucket = var.netweaver_software_bucket
  virtual_host_ips          = local.netweaver_virtual_ips
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp,
    module.bastion
  ]
}

module "hana_node" {
  source                = "./modules/hana_node"
  common_variables      = module.common_variables.configuration
  name                  = var.hana_name
  network_domain        = var.hana_network_domain == "" ? var.network_domain : var.hana_network_domain
  bastion_host          = module.bastion.public_ip
  hana_count            = var.hana_count
  machine_type          = var.machine_type
  compute_zones         = local.compute_zones
  network_name          = local.vpc_name
  network_subnet_name   = local.subnet_name
  os_image              = local.hana_os_image
  gcp_credentials_file  = var.gcp_credentials_file
  host_ips              = local.hana_ips
  iscsi_srv_ip          = module.iscsi_server.iscsisrv_ip
  hana_data_disk_type   = var.hana_data_disk_type
  hana_data_disk_size   = var.hana_data_disk_size
  hana_backup_disk_type = var.hana_backup_disk_type
  hana_backup_disk_size = var.hana_backup_disk_size
  cluster_ssh_pub       = var.cluster_ssh_pub
  cluster_ssh_key       = var.cluster_ssh_key
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp,
    google_compute_router_nat.nat,
    module.bastion
  ]
}

module "monitoring" {
  source              = "./modules/monitoring"
  common_variables    = module.common_variables.configuration
  name                = var.monitoring_name
  network_domain      = var.monitoring_network_domain == "" ? var.network_domain : var.monitoring_network_domain
  bastion_host        = module.bastion.public_ip
  monitoring_enabled  = var.monitoring_enabled
  compute_zones       = local.compute_zones
  network_subnet_name = local.subnet_name
  os_image            = local.monitoring_os_image
  monitoring_srv_ip   = local.monitoring_srv_ip
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp,
    google_compute_router_nat.nat,
    module.bastion
  ]
}

module "iscsi_server" {
  source              = "./modules/iscsi_server"
  common_variables    = module.common_variables.configuration
  name                = var.iscsi_name
  network_domain      = var.iscsi_network_domain == "" ? var.network_domain : var.iscsi_network_domain
  bastion_host        = module.bastion.public_ip
  iscsi_count         = local.iscsi_enabled == true ? 1 : 0
  machine_type        = var.machine_type_iscsi_server
  compute_zones       = local.compute_zones
  network_subnet_name = local.subnet_name
  os_image            = local.iscsi_os_image
  host_ips            = [local.iscsi_srv_ip]
  lun_count           = var.iscsi_lun_count
  iscsi_disk_size     = var.iscsi_disk_size
  on_destroy_dependencies = [
    google_compute_firewall.ha_firewall_allow_tcp,
    module.bastion
  ]
}
