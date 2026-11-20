output "namespace" {
  value = data.oci_objectstorage_namespace.this.namespace
}

output "state_bucket_name" {
  value = oci_objectstorage_bucket.tf_state.name
}
