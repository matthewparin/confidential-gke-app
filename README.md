# Demonstration of Confidential AI Workloads on Google Kubernetes Engine

This project demonstrates the end-to-end deployment of a containerized application onto a **secure, confidential** Google Kubernetes Engine (GKE) cluster. It showcases modern cloud‑native best practices—Infrastructure as Code (IaC), containerization, and declarative deployments—with a focus on the security and compliance needs of regulated industries.

---

## Strategic Context

Enterprises in regulated sectors (finance, healthcare, public sector) face hurdles adopting public cloud for their most sensitive workloads, especially in **AI**. Traditional encryption protects data **at rest** and **in transit**, but not **in use** while residing in memory.

**Confidential Computing** addresses this gap by using hardware-based **Trusted Execution Environments (TEEs)** to protect data during processing. This ensures sensitive information remains isolated from the cloud provider, privileged administrators, and other workloads.

This project implements a solution using **Confidential GKE Nodes**, built on Google Cloud’s Confidential VMs (AMD SEV). It demonstrates a practical, hands‑on approach to building a trusted cloud environment for high‑value AI workloads—directly aligned to platforms like NVIDIA DGX Cloud.

---

## Architecture

A modern DevOps workflow enables a repeatable, auditable, and secure deployment from local development to the cloud.

![Architecture Diagram Placeholder](https://i.imgur.com/your-diagram-url.png)
> Replace the placeholder with your actual architecture diagram (e.g., draw.io, Excalidraw, or Mermaid).

**Components**
- **Application**: Lightweight Python **Flask** service.
- **Containerization**: Packaged via **Docker** for portability.
- **Container Registry**: Images stored in **Google Artifact Registry** (private).
- **Infrastructure as Code**: **Terraform** declaratively manages the VPC, GKE cluster, and related resources.
- **Deployment**: **Kubernetes** manifests (`deployment.yaml`, `service.yaml`) manage rollout and scaling.

---

## Technology Stack

| Technology                | Purpose                 | Justification |
|--------------------------|-------------------------|---------------|
| Google Cloud (GCP)       | Cloud Provider          | Integrated Confidential Computing with Confidential GKE Nodes. |
| Confidential GKE Nodes   | Secure Compute          | Hardware-level memory encryption (AMD SEV) to protect data in use. |
| Docker                   | Containerization        | Industry standard for packaging apps and dependencies. |
| Terraform                | Infrastructure as Code  | Repeatable, auditable, version-controlled provisioning. |
| Kubernetes               | Orchestration           | Automated deployment, scaling, and management for containers. |
| Python / Flask           | Application Framework   | Simple, lightweight framework for a POC workload. |

---

## Key Features

- **Confidential Computing**: Workloads run on GKE nodes with hardware-level memory encryption, protecting data during processing.
- **Infrastructure as Code**: All cloud resources are defined in Terraform for auditability and repeatability.
- **Containerized Workload**: Docker ensures consistent builds and predictable runtime behavior.
- **Declarative Deployment**: Kubernetes manifests define desired state with self-healing and scaling.
- **Security Best Practices**: Shielded Nodes enabled; resources run in a dedicated VPC for isolation.

---

## Getting Started

### Prerequisites
- macOS development environment with **Homebrew**, **Docker**, **gcloud CLI**, **Terraform**, and **kubectl**.
- A Google Cloud **project** with an active **billing account**.

### 1) Clone the Repository
```bash
# Replace <your-repo-url> with your GitHub repo URL
git clone <your-repo-url>
cd confidential-gke-app
```

### 2) Configure GCP Project
```bash
# Set your unique Project ID (must be globally unique in GCP)
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export AR_REPO="confidential-repo"
export IMAGE_NAME="confidential-app"
export TAG="v1"

gcloud config set project "${PROJECT_ID}"

# (One-time) Link billing & enable core APIs as needed
# gcloud beta billing projects link "${PROJECT_ID}" --billing-account <BILLING_ACCOUNT_ID>
gcloud services enable   compute.googleapis.com   container.googleapis.com   artifactregistry.googleapis.com
```

### 3) Create Artifact Registry (if not already created)
```bash
gcloud artifacts repositories create "${AR_REPO}"   --project="${PROJECT_ID}"   --repository-format=docker   --location="${REGION}"   --description="Private repo for confidential app images" || true
```

### 4) Build & Push the Container Image
```bash
# Build (note the space before the final dot)
docker build -t "${IMAGE_NAME}:${TAG}" .

# Authenticate Docker to Artifact Registry
gcloud auth configure-docker "${REGION}-docker.pkg.dev"

# Tag & push
docker tag "${IMAGE_NAME}:${TAG}"   "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${TAG}"

docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${TAG}"
```

### 5) Provision Infrastructure with Terraform
```bash
cd terraform
terraform init
terraform apply -var="project_id=${PROJECT_ID}" -var="region=${REGION}"
# Outputs should include the cluster name/region
cd ..
```

### 6) Deploy the Application to GKE
```bash
# Configure kubectl against your cluster
gcloud container clusters get-credentials confidential-cluster --region "${REGION}" --project "${PROJECT_ID}"

# Ensure your Kubernetes manifests reference the correct image path:
#   ${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${TAG}

# Apply manifests
kubectl apply -f ./kubernetes/deployment.yaml
kubectl apply -f ./kubernetes/service.yaml
```

### 7) Access the Application
```bash
# Wait for an external IP to be assigned
kubectl get service confidential-app-service

# Capture external IP and test
export EXTERNAL_IP=$(kubectl get service confidential-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl "http://${EXTERNAL_IP}"
```

---

## Troubleshooting

### InvalidImageName
- Ensure the image follows:  
  `REGION-docker.pkg.dev/PROJECT_ID/REPO/IMAGE:TAG`  
  Example: `us-central1-docker.pkg.dev/my-project/confidential-repo/confidential-app:v1`
- No angle brackets (`< >`), no double slashes, and the **region** must match your Artifact Registry region.

### ErrImagePull / ImagePullBackOff
1. **Verify the tag exists:**
   ```bash
   gcloud artifacts docker images list      "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}"      --format='table(NAME,TAGS)'
   ```
2. **Grant GKE nodes permission to pull from Artifact Registry:**
   ```bash
   PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"

   # If using the default compute service account on nodes:
   gcloud projects add-iam-policy-binding "${PROJECT_ID}"      --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"      --role="roles/artifactregistry.reader"
   ```
   > If your cluster uses a **custom node service account**, grant the same role to that account instead.

3. **Force a new pull after fixing IAM/tag:**
   ```bash
   kubectl rollout restart deployment confidential-app-deployment
   ```

### Region Mismatch
- Your **cluster region** and **Artifact Registry repo region** don’t have to match, but cross‑region pulls add latency and can confuse setups. Prefer the same region (e.g., `us-central1`).

### Confidential Nodes
- On **GKE Autopilot** with Confidential Nodes enabled, all nodes are confidential without pod changes. On **GKE Standard**, ensure your node pool is created as confidential or target a confidential pool via labels/selectors.

---

## Publishing the Project to GitHub

1. **Create a New Repository on GitHub**
   - Go to GitHub → **New repository** → Name it (e.g., `confidential-gke-demo`) → Public → Create.

2. **Link the Local Repository**
   ```bash
   # From the project root (confidential-gke-app/)
   git init
   git remote add origin https://github.com/<your-user>/<your-repo>.git
   ```

3. **Commit and Push**
   ```bash
   git add .
   git commit -m "Initial commit: Confidential GKE application and infrastructure"
   git branch -M main
   git push -u origin main
   ```

---

## Conclusion & Executive Talking Points

**Project Summary**  
This project demonstrates deploying a containerized application onto GKE with **Confidential Computing** enabled. Using **Terraform**, **Docker**, and **Kubernetes**, it establishes a secure, repeatable, auditable workflow for sensitive workloads. The repository provides a practical foundation for leading discussions and initiatives focused on security and compliance—relevant to platforms such as **NVIDIA DGX Cloud**.

**Curated Talking Points**
- **On Infrastructure as Code:**  
  “I built this on **Terraform** because regulated environments require **auditable, repeatable, version‑controlled** infrastructure. IaC moves security from checklists to automated controls.”
- **On Confidential Computing:**  
  “I implemented **Confidential GKE Nodes** to protect customers’ most sensitive IP—their AI models and proprietary data—not just at rest or in transit, but **while in use**. This is a key enterprise trust driver.”
- **On Kubernetes and Cloud‑Native:**  
  “Using **Kubernetes** demonstrates how workloads are operated at scale, aligning with the cloud‑native ecosystem and shared responsibility model our customers expect.”
- **On Professionalism and Communication:**  
  “The repo is structured and documented with a clear README and separation of concerns—signaling my ability to communicate with engineering teams and uphold enterprise standards.”
- **On Strategic Tool Selection:**  
  “**Google Cloud** provides integrated Confidential GKE capabilities, highlighting how a strong ecosystem and ease of use accelerate adoption of advanced security features.”

---

## Notes

- Replace the architecture diagram link with your final diagram.
- Ensure `deployment.yaml` references:  
  `${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${TAG}`
- Consider adding CI/CD (GitHub Actions or Cloud Build) to automate build, scan, and deploy.
