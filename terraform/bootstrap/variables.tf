variable "tenancy_ocid" {
  type        = string
  description = "OCID of the Oracle tenancy (account). From the tenancy= line in ~/.oci/config"
}

variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment for project resources (cloud-k8s). Console: Identity > Compartments"
}
