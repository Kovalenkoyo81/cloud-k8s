terraform {
  backend "oci" {
    bucket              = "cloud_k8s_tf_state"
    namespace           = "axv3eapfsamq"
    key                 = "bootstrap/terraform.tfstate"
    config_file_profile = "cloud-k8s"
  }
}
