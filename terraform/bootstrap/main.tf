data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

resource "oci_limits_quota" "always_free_compute" {
  compartment_id = var.tenancy_ocid
  name           = "always_free_compute"
  description    = "Allows to stay in free tier quotas"
  statements = [
    "zero compute-core quotas in tenancy",
    "zero compute-memory quotas in tenancy",
    "set compute-core quota standard-a1-core-regional-count to 2 in tenancy",
    "set compute-memory quota standard-a1-memory-regional-count to 12 in tenancy",
    "set compute-core quota standard-a1-core-count to 2 in tenancy",
    "set compute-memory quota standard-a1-memory-count to 12 in tenancy"
  ]
}

resource "oci_objectstorage_bucket" "tf_state" {
  compartment_id = var.compartment_ocid
  name           = "cloud_k8s_tf_state"
  namespace      = data.oci_objectstorage_namespace.this.namespace
  versioning     = "Enabled"

  lifecycle {
    prevent_destroy = true
  }
}