module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

module "iscsi_server" {
  source                 = "./modules/iscsi_server"
  aws_region             = var.aws_region
  availability_zones     = data.aws_availability_zones.available.names
  subnet_ids             = aws_subnet.hana-subnet.*.id
  iscsi_srv_images       = var.iscsi_srv
  iscsi_instancetype     = var.iscsi_instancetype
  min_instancetype       = var.min_instancetype
  key_name               = aws_key_pair.hana-key-pair.key_name
  security_group_id      = aws_security_group.secgroup.id
  private_key_location   = var.private_key_location
  iscsi_srv_ip           = var.iscsi_srv_ip
  iscsidev               = var.iscsidev
  iscsi_disks            = var.iscsi_disks
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  additional_packages    = var.additional_packages
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  provisioner            = var.provisioner
  background             = var.background
  qa_mode                = var.qa_mode
  on_destroy_dependencies = [
    aws_route_table_association.hana-subnet-route-association,
    aws_route.public,
    aws_security_group_rule.ssh,
    aws_security_group_rule.outall
  ]
}

module "netweaver_node" {
  source                     = "./modules/netweaver_node"
  netweaver_count            = var.netweaver_enabled == true ? 4 : 0
  instancetype               = var.netweaver_instancetype
  name                       = "netweaver"
  aws_region                 = var.aws_region
  availability_zones         = data.aws_availability_zones.available.names
  sles4sap_images            = var.sles4sap
  vpc_id                     = aws_vpc.vpc.id
  vpc_cidr_block             = aws_vpc.vpc.cidr_block
  key_name                   = aws_key_pair.hana-key-pair.key_name
  security_group_id          = aws_security_group.secgroup.id
  route_table_id             = aws_route_table.route-table.id
  efs_performance_mode       = var.netweaver_efs_performance_mode
  aws_credentials            = var.aws_credentials
  aws_access_key_id          = var.aws_access_key_id
  aws_secret_access_key      = var.aws_secret_access_key
  s3_bucket                  = var.netweaver_s3_bucket
  netweaver_product_id       = var.netweaver_product_id
  netweaver_swpm_folder      = var.netweaver_swpm_folder
  netweaver_sapcar_exe       = var.netweaver_sapcar_exe
  netweaver_swpm_sar         = var.netweaver_swpm_sar
  netweaver_swpm_extract_dir = var.netweaver_swpm_extract_dir
  netweaver_sapexe_folder    = var.netweaver_sapexe_folder
  netweaver_additional_dvds  = var.netweaver_additional_dvds
  hana_ip                    = var.hana_cluster_vip
  host_ips                   = var.netweaver_ips
  virtual_host_ips           = var.netweaver_virtual_ips
  public_key_location        = var.public_key_location
  private_key_location       = var.private_key_location
  iscsi_srv_ip               = module.iscsi_server.iscsisrv_ip
  cluster_ssh_pub            = var.cluster_ssh_pub
  cluster_ssh_key            = var.cluster_ssh_key
  reg_code                   = var.reg_code
  reg_email                  = var.reg_email
  reg_additional_modules     = var.reg_additional_modules
  ha_sap_deployment_repo     = var.ha_sap_deployment_repo
  devel_mode                 = var.devel_mode
  provisioner                = var.provisioner
  background                 = var.background
  monitoring_enabled         = var.monitoring_enabled
  on_destroy_dependencies = [
    aws_route.public,
    aws_security_group_rule.ssh,
    aws_security_group_rule.outall
  ]
}
