# Demonstration of Confidential AI Workloads on Google Kubernetes Engine

This project demonstrates the end-to-end deployment of a containerized application onto a **secure, confidential** Google Kubernetes Engine (GKE) cluster. It showcases modern cloud‑native best practices—Infrastructure as Code (IaC), containerization, and declarative deployments—and does so using a security and compliance-centric pattern that should come to dominate regulated industries and large research consortiums worldwide. 

---

## Strategic Context

Enterprises in regulated sectors (finance, healthcare, public sector) face hurdles adopting public cloud for their most sensitive workloads, including in **AI**. Traditional encryption protects data **at rest** and **in transit**, but not **in use** while residing in memory. More and more, organizations and regulators judge it is critical to close this gap.

**Confidential Computing** addresses this gap by using hardware-based **Trusted Execution Environments (TEEs)** to protect data, models, weights and even code during processing. This ensures sensitive information remains isolated from the cloud provider, privileged administrators, and other workloads.

This project shows a walking skeleton running on **Confidential GKE Nodes**, built on Google Cloud’s Confidential VMs (AMD SEV). It demonstrates a practical, hands‑on approach to building a trusted cloud environment for high‑value AI workloads.

Porting this project to NVIDIA DGX Cloud is achievable by using DGX GPU clusters and toggling on confidential compute mode, more details in [NVIDIA documentation](https://docs.nvidia.com/cc-deployment-guide-snp.pdf). In practice, this change makes is possible to run fine-tuning and inference inside the TEE, with checkpoints and outputs written to encrypted storage so plaintext data, models, weights, and code never leave the secure boundary.

---

## Architecture

A modern DevOps workflow enables a repeatable, auditable, and secure deployment from local development to the cloud.

**Components**
- **Application**: Lightweight Python **Flask** service.
- **Containerization**: Packaged via **Docker** for portability.
- **Container Registry**: Images stored in **Google Artifact Registry** (private).
- **Infrastructure as Code**: **Terraform** declaratively manages the VPC, GKE cluster, and related resources.
- **Deployment**: **Kubernetes** manifests (`deployment.yaml`, `service.yaml`) manage rollout and scaling.

---

## Technology Stack

| Technology               | Purpose                 | Justification |
|--------------------------|-------------------------|---------------|
| Google Cloud (GCP)       | Cloud Provider          | Integrated Confidential Computing with Confidential GKE Nodes. |
| Confidential GKE Nodes   | Secure Compute          | Hardware-level memory encryption (AMD SEV) to protect data in use. |
| Docker                   | Containerization        | Industry standard for packaging apps and dependencies. |
| Terraform                | Infrastructure as Code  | Repeatable, auditable, version-controlled provisioning. |
| Kubernetes               | Orchestration           | Automated deployment, scaling, and management for containers. |
| Python / Flask           | Application Framework   | Simple, lightweight framework for a POC workload. |

---

## Key Features

- **Confidential Computing**: This application workload runs on GKE nodes with hardware-level memory encryption of data during processing.
- **Infrastructure as Code**: All cloud resources are defined declaratively in Terraform, providing an auditable and repeatable deployment process critical for regulated environments.
- **Containerized Workload**: The application is packaged with Docker, ensuring consistency across development and production environments.
- **Declarative Deployment**: Kubernetes manifests define the desired state of the application, leveraging the self-healing and scalable nature of the Google Cloud platform.
- **Security Best Practices**: The Google Kubernetes Engine (GKE) cluster is provisioned with Shielded Nodes enabled and runs within a dedicated VPC for network isolation.

---

## Getting Started

### Prerequisites
- macOS development environment with **Homebrew**, **Docker**, **gcloud CLI**, **Terraform**, and **kubectl**.
- A Google Cloud **account** with billing enabled.

### Step-by-Step Deployment Process

This project follows a comprehensive 15-step deployment process to ensure everything works correctly:

#### **Step 0: Prerequisites Check**
```bash
# Check all requirements before starting
./scripts/check-prerequisites.sh
```

#### **Step 1: Clone the Repository**
```bash
git clone
cd confidential-gke-app
```

#### **Step 2: Configure GCP Project**
The project uses a dynamic configuration system that automatically manages your GCP project ID.

**First time setup:**
```bash
./scripts/setup-gke.sh
```

This script will:
1. **Check for Google Cloud Account** and authenticate CLI
2. **Create a new project** (or use existing)
3. **Check billing enablement** and prompt if needed
4. **Enable all necessary APIs** for the project
5. **Configure project ID** for the session

**View current configuration:**
```bash
./scripts/show-config.sh
```

**Change project ID:**
```bash
rm .project-config
./scripts/setup-gke.sh
```

#### **Step 3: Deploy the Application**
```bash
./scripts/deploy.sh
```

This script will:
6. **Containerize the Python application** with Docker
7. **Build the image** and verify it works locally
8. **Create Google Artifact Registry Repository** and configure Docker authentication
9. **Verify fully-qualified image name** (registry location, projectID, repository name, image name)
10. **Push the image** to Google Artifact Registry
11. **Define infrastructure requirements** in Terraform (if available)
12. **Plan and deploy Terraform** (or use gcloud for infrastructure)
13. **Deploy containerized application** with Kubernetes to create pods
14. **Apply the service** to create the load balancer
15. **Get external IP** and test the application with curl

### 4) Access the Application
The deployment script will automatically provide you with the external IP and test the application. You can also manually check:

```bash
# Get the external IP
kubectl get service confidential-app-service

# Test the application
export EXTERNAL_IP=$(kubectl get service confidential-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl "http://${EXTERNAL_IP}/api/v1/health"
```

### 5) Clean Up
```bash
# Complete teardown of all resources
./scripts/teardown.sh
```

This script will:
- Delete all Kubernetes resources (deployments, services, service accounts)
- Remove Docker images (both local and remote)
- Delete the GKE cluster
- Remove the service account
- Delete the Artifact Registry repository
- Clean up local configuration files
- Verify all resources have been removed

**⚠️ Warning:** This will permanently delete all resources created by this project.

---

## Troubleshooting

### Common Issues

#### Prerequisites Not Met
If the prerequisites check fails:
```bash
# Run the prerequisites check
./scripts/check-prerequisites.sh

# Install missing tools
# macOS with Homebrew:
brew install google-cloud-sdk docker kubectl terraform

# Authenticate to GCP
gcloud auth login
gcloud auth application-default login
```

#### Project Creation Issues
If project creation fails:
- **Permissions**: Ensure you have the 'Project Creator' role in your GCP organization
- **Unique ID**: Project ID must be globally unique across all GCP projects
- **Format**: Project ID must follow GCP naming rules (6-30 chars, lowercase, no consecutive hyphens)
- **Billing**: Verify billing is enabled for your account
- **Organization**: Check if you're in the correct GCP organization

**Common solutions:**
```bash
# Check your current account and organization
gcloud config get-value account
gcloud organizations list

# List your existing projects
gcloud projects list

# Use an existing project instead
rm .project-config
./scripts/setup-gke.sh
```

#### Billing Issues
If billing is not enabled:
```bash
# List available billing accounts
gcloud billing accounts list

# Link billing account to project
gcloud billing projects link PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

#### InvalidImageName
- The project ID is automatically configured during setup
- Ensure the image follows:  
  `REGION-docker.pkg.dev/PROJECT_ID/REPO/IMAGE:TAG`  
  Example: `us-central1-docker.pkg.dev/my-project/confidential-repo/confidential-app:v1`
- No angle brackets (`< >`), no double slashes, and the **region** must match your Artifact Registry region.

### ErrImagePull / ImagePullBackOff
1. **Verify the tag exists:**
   ```bash
   # Get the current project ID
   PROJECT_ID=$(cat .project-config 2>/dev/null || echo "not-configured")
   gcloud artifacts docker images list "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}" --format='table(NAME,TAGS)'
   ```
2. **Check service account configuration:**
   ```bash
   # Verify the service account exists and has proper permissions
   kubectl get serviceaccount confidential-app-sa
   kubectl describe serviceaccount confidential-app-sa
   ```
3. **Grant GKE nodes permission to pull from Artifact Registry:**
   ```bash
   # Get the current project ID
   PROJECT_ID=$(cat .project-config 2>/dev/null || echo "not-configured")
   PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"

   # If using the default compute service account on nodes:
   gcloud projects add-iam-policy-binding "${PROJECT_ID}"      --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"      --role="roles/artifactregistry.reader"
   ```
   > If your cluster uses a **custom node service account**, grant the same role to that account instead.

4. **Force a new pull after fixing IAM/tag:**
   ```bash
   kubectl rollout restart deployment confidential-app-deployment
   ```

### Region Mismatch
- Your **cluster region** and **Artifact Registry repo region** don’t have to match, but cross‑region pulls add latency and can confuse setups. Prefer the same region (e.g., `us-central1`).

### Confidential Nodes
- On **GKE Autopilot** with Confidential Nodes enabled, all nodes are confidential without pod changes. On **GKE Standard**, ensure your node pool is created as confidential or target a confidential pool via labels/selectors.

---

## Conclusion

**Project Summary**  
This project demonstrates deploying a containerized application onto GKE with **Confidential Nodes** enabled. Using **Terraform**, **Docker**, and **Kubernetes**, it establishes a secure, repeatable, auditable workflow for sensitive workloads. The repository provides a practical foundation for leading discussions and initiatives focused on building scalable environments to generate foundational and fine-tuned models and inference on platforms such as **NVIDIA DGX Cloud**.

**Curated FAQs**
- **On Infrastructure as Code:**  
  “This project leverages **Terraform** because regulated environments almost certainly require **auditable, repeatable, version‑controlled** infrastructure. IaC moves security from checklists to automated controls, defined in code.”
- **On Confidential Computing:**  
  “This project leverages **Confidential GKE Nodes** to protect a customers’ most sensitive intellectual property—their AI models and proprietary data—not just at rest or in transit, but also **in use**. This is an emerging state-level and enterprise trust driver.”
- **On Kubernetes and Cloud‑Native:**  
  “Using **Kubernetes** demonstrates how workloads are operated at scale, aligning with the cloud‑native ecosystem and shared responsibility model state-level and enterprise customers expect.”
- **On Strategic Tool Selection:**  
  “**Google Cloud** provides integrated Confidential GKE capabilities, highlighting how a strong ecosystem and ease of use accelerate adoption of advanced security features.”

---

## Notes
- Ensure `deployment.yaml` references:  
  `${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${TAG}`
- Consider adding CI/CD (GitHub Actions or Cloud Build) to automate build, scan, and deploy.
