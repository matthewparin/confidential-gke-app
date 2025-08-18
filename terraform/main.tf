terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Create a dedicated VPC network for the GKE cluster for isolation
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Create a subnetwork within the VPC
resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.cluster_name}-subnet"
  ip_cidr_range            = "10.10.0.0/24"
  network                  = google_compute_network.vpc.id
  region                   = var.region
  private_ip_google_access = true
}

# Define the GKE cluster resource
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Use the dedicated VPC and subnetwork
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # Remove the default node pool; we will create a custom one
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable security best practices
  enable_shielded_nodes = true

}

# Define the custom, confidential node pool for the cluster
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    # N2D machine types support AMD SEV for confidential computing.
    # This is a required machine series for this feature.
    machine_type = "n2d-standard-2"
    image_type   = "COS_CONTAINERD"

    # Standard OAuth scopes for GKE nodes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # The confidential_nodes block is defined here, at the node pool level.
    # This is the key change from earlier iterations, to fix the deployment error.
    confidential_nodes {
      enabled = true
    }
  }
}