variable "project_id" {
  description = "The ID of the Google Cloud project."
  type        = string
  default     = "cc-demo-1755288433-mwp"  # Replace with your actual project ID
}

variable "region" {
  description = "The GCP region to deploy resources in."
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name for the GKE cluster."
  type        = string
  default     = "confidential-cluster"
}