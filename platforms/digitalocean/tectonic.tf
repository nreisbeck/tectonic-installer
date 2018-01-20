data "template_file" "etcd_hostname_list" {
  count    = "${var.tectonic_etcd_count > 0 ? var.tectonic_etcd_count : 3}"
  template = "${var.tectonic_cluster_name}-etcd-${count.index}.${var.tectonic_base_domain}"
}

module "bootkube" {
  source = "../../modules/bootkube"

  cloud_provider        = ""
  cluster_name          = "${var.tectonic_cluster_name}"
  kube_apiserver_url    = "https://${module.masters.cluster_fqdn}:443"
  oidc_issuer_url       = "https://${module.masters.console_fqdn}/identity"
  apiserver_secure_port = 443

  # Platform-independent variables wiring, do not modify.
  container_images          = "${var.tectonic_container_images}"
  versions                  = "${var.tectonic_versions}"
  service_cidr              = "${var.tectonic_service_cidr}"
  cluster_cidr              = "${var.tectonic_cluster_cidr}"
  advertise_address         = "0.0.0.0"
  anonymous_auth            = "false"
  oidc_username_claim       = "email"
  oidc_groups_claim         = "groups"
  oidc_client_id            = "tectonic-kubectl"
  oidc_ca_cert              = "${module.ingress_certs.ca_cert_pem}"
  pull_secret_path          = "${pathexpand(var.tectonic_pull_secret_path)}"
  apiserver_cert_pem        = "${module.kube_certs.apiserver_cert_pem}"
  apiserver_key_pem         = "${module.kube_certs.apiserver_key_pem}"
  etcd_ca_cert_pem          = "${module.etcd_certs.etcd_ca_crt_pem}"
  etcd_client_cert_pem      = "${module.etcd_certs.etcd_client_crt_pem}"
  etcd_client_key_pem       = "${module.etcd_certs.etcd_client_key_pem}"
  etcd_peer_cert_pem        = "${module.etcd_certs.etcd_peer_crt_pem}"
  etcd_peer_key_pem         = "${module.etcd_certs.etcd_peer_key_pem}"
  etcd_server_cert_pem      = "${module.etcd_certs.etcd_server_crt_pem}"
  etcd_server_key_pem       = "${module.etcd_certs.etcd_server_key_pem}"
  kube_ca_cert_pem          = "${module.kube_certs.ca_cert_pem}"
  kubelet_cert_pem          = "${module.kube_certs.kubelet_cert_pem}"
  kubelet_key_pem           = "${module.kube_certs.kubelet_key_pem}"
  etcd_backup_size          = "${var.tectonic_etcd_backup_size}"
  etcd_backup_storage_class = "${var.tectonic_etcd_backup_storage_class}"
  etcd_endpoints            = "${module.etcd.endpoints}"
  master_count              = 1
  cloud_config_path         = ""
  tectonic_networking       = "${var.tectonic_networking}"
  calico_mtu                = "1480"
}

module "tectonic" {
  source = "../../modules/tectonic"

  platform           = "digitalocean"
  cluster_name       = "${var.tectonic_cluster_name}"
  base_address       = "${module.masters.console_fqdn}"
  kube_apiserver_url = "https://${module.masters.cluster_fqdn}:443"
  service_cidr       = "${var.tectonic_service_cidr}"

  # Platform-independent variables wiring, do not modify.
  container_images         = "${var.tectonic_container_images}"
  container_base_images    = "${var.tectonic_container_base_images}"
  versions                 = "${var.tectonic_versions}"
  license_path             = "${pathexpand(var.tectonic_license_path)}"
  pull_secret_path         = "${pathexpand(var.tectonic_pull_secret_path)}"
  admin_email              = "${var.tectonic_admin_email}"
  admin_password           = "${var.tectonic_admin_password}"
  update_channel           = "${var.tectonic_update_channel}"
  update_app_id            = "${var.tectonic_update_app_id}"
  update_server            = "${var.tectonic_update_server}"
  ca_generated             = "${var.tectonic_ca_cert == "" ? false : true}"
  ca_cert                  = "${module.kube_certs.ca_cert_pem}"
  ingress_ca_cert_pem      = "${module.ingress_certs.ca_cert_pem}"
  ingress_cert_pem         = "${module.ingress_certs.cert_pem}"
  ingress_key_pem          = "${module.ingress_certs.key_pem}"
  identity_client_cert_pem = "${module.identity_certs.client_cert_pem}"
  identity_client_key_pem  = "${module.identity_certs.client_key_pem}"
  identity_server_cert_pem = "${module.identity_certs.server_cert_pem}"
  identity_server_key_pem  = "${module.identity_certs.server_key_pem}"
  console_client_id        = "tectonic-console"
  kubectl_client_id        = "tectonic-kubectl"
  ingress_kind             = "NodePort"
  master_count             = 1
  stats_url                = "${var.tectonic_stats_url}"
  image_re                 = "${var.tectonic_image_re}"
  tectonic_networking      = "${var.tectonic_networking}"
  calico_mtu               = "1480"
  cluster_cidr             = "${var.tectonic_cluster_cidr}"
}

data "archive_file" "assets" {
  type       = "zip"
  source_dir = "./generated/"

  # Because the archive_file provider is a data source, depends_on can't be
  # used to guarantee that the tectonic/bootkube modules have generated
  # all the assets on disk before trying to archive them. Instead, we use their
  # ID outputs, that are only computed once the assets have actually been
  # written to disk. We re-hash the IDs (or dedicated module outputs, like module.bootkube.content_hash)
  # to make the filename shorter, since there is no security nor collision risk anyways.
  #
  # Additionally, data sources do not support managing any lifecycle whatsoever,
  # and therefore, the archive is never deleted. To avoid cluttering the module
  # folder, we write it in the Terraform managed hidden folder `.terraform`.
  output_path = "./.terraform/generated_${sha1("${module.etcd_certs.id} ${module.tectonic.id} ${module.bootkube.id}")}.zip"
}