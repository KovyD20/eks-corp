<a id="readme-top"></a>

<div align="center">
  <img src="assets/eks_corp_banner.png" alt="EKS Corp Banner" width="100%" />
  <br /><br />

  <a href="https://github.com/KovyD20/eks-corp/actions/workflows/ci.yml"><img src="https://github.com/KovyD20/eks-corp/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
</div>

**Status:** deployed and verified on AWS (eu-west-3), then torn down to avoid costs. The later fixes were checked with `terraform validate`, local tests and CI, but not re-applied on AWS.

---

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#architecture">Architecture</a></li>
    <li><a href="#built-with">Built With</a></li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#deployment">Deployment</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#design-decisions">Design Decisions</a></li>
    <li><a href="#known-limitations">Known Limitations</a></li>
    <li><a href="#cost-and-cleanup">Cost and Cleanup</a></li>
    <li><a href="#project-structure">Project Structure</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

---

## About The Project

EKS Corp is a production-style AWS infrastructure project that simulates a real company cloud environment. It provisions and manages a complete cloud stack using Terraform as Infrastructure as Code, covering networking, container orchestration, managed databases, object storage, and serverless automation.

**Key highlights:**
- Multi-AZ, highly available EKS cluster running a containerised Node.js backend
- Private ECR for container image storage
- RDS PostgreSQL with Multi-AZ failover, credentials managed via AWS Secrets Manager
- Company S3 bucket with folder-level IAM policies for uploads, documents, and reports
- Serverless Lambda automation that runs hourly health checks and saves reports to S3
- Remote Terraform state stored in S3 with DynamoDB locking
- All AWS permissions handled through Pod Identity — no static credentials

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Architecture

<div align="center">
  <img src="assets/eks_corp_architecture.png" alt="EKS Corp Architecture" width="90%" />
</div>
<br />

The infrastructure runs in `eu-west-3` (Paris) across 3 Availability Zones:

| Layer | Technology | Details |
|---|---|---|
| Networking | AWS VPC | 3 public + 3 private subnets, NAT Gateways per AZ |
| Container Orchestration | Amazon EKS 1.35 | t3.large nodes, node group with 2–6 scaling bounds (no cluster autoscaler), multi-AZ |
| Container Registry | Amazon ECR | Private, immutable tags, scan on push |
| Database | Amazon RDS PostgreSQL | Multi-AZ, db.t3.medium, Secrets Manager credentials |
| Object Storage | Amazon S3 | Company bucket (uploads/documents/reports) + Terraform state bucket |
| Automation | AWS Lambda + EventBridge | Hourly service check, saves JSON report to S3 |
| Load Balancing | AWS ALB | Managed by AWS Load Balancer Controller via Helm |
| IAM | Pod Identity | No static credentials — roles assumed per service account |
| State Management | S3 + DynamoDB | Remote Terraform backend with state locking |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Built With

[![Terraform][Terraform-badge]][Terraform-url]
[![AWS][AWS-badge]][AWS-url]
[![Kubernetes][K8s-badge]][K8s-url]
[![Node.js][Node-badge]][Node-url]
[![Docker][Docker-badge]][Docker-url]
[![PostgreSQL][Postgres-badge]][Postgres-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Getting Started

### Prerequisites

The following tools must be installed and configured before deploying:

- **AWS CLI** – configured with appropriate permissions
  ```sh
  aws configure
  ```
- **Terraform** >= 1.6.0
  ```sh
  terraform -version
  ```
- **kubectl**
  ```sh
  kubectl version --client
  ```
- **Helm** >= 3.0
  ```sh
  helm version
  ```
- **Docker** – for building and pushing backend images
  ```sh
  docker --version
  ```

### Bootstrap (one-time setup)

Before the first `terraform apply`, the remote state backend must be created manually via AWS CLI:

```sh
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket eks-corp-terraform-state \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3

aws s3api put-bucket-versioning \
  --bucket eks-corp-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket eks-corp-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name eks-corp-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-3
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Deployment

### 1. Clone the repository

```sh
git clone https://github.com/KovyD20/eks-corp.git
cd eks-corp
```

### 2. Deploy infrastructure

```sh
terraform -chdir=environments/prod init
terraform -chdir=environments/prod apply
```

`health_endpoint` in `environments/prod/terraform.tfvars` is the ALB hostname the Lambda checks. The ALB is only created in step 6, so on the first apply the old value is fine — it is updated in step 7.

### 3. Configure kubectl

```sh
aws eks update-kubeconfig \
  --name eks-corp-prod \
  --region eu-west-3
```

### 4. Install AWS Load Balancer Controller

```sh
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --version 3.6.1 \
  --set clusterName=eks-corp-prod \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller
```

The chart version matches the IAM policy in `modules/eks/policies/`. Upgrade them together.

### 5. Build and push backend image

```sh
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=$ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com

aws ecr get-login-password --region eu-west-3 | \
  docker login --username AWS --password-stdin $REGISTRY

docker build -t $REGISTRY/eks-corp-prod-backend:v2.1.0 backend
docker push $REGISTRY/eks-corp-prod-backend:v2.1.0
```

### 6. Deploy to Kubernetes

The ConfigMap and the API key are not stored in the repo — they are created from the Terraform outputs and a random value:

```sh
kubectl apply -f k8s/apps/backend/namespace.yaml

kubectl create configmap backend-config -n backend \
  --from-literal=db_secret_arn=$(terraform -chdir=environments/prod output -raw rds_secret_arn) \
  --from-literal=s3_bucket_name=$(terraform -chdir=environments/prod output -raw s3_bucket_name)

kubectl create secret generic backend-api-key -n backend \
  --from-literal=api_key=$(openssl rand -hex 24)
```

The manifests are applied with kustomize. The image is set in `k8s/apps/backend/kustomization.yaml`, with `<ACCOUNT_ID>` as a placeholder:

```sh
kubectl kustomize k8s/apps/backend | sed "s/<ACCOUNT_ID>/$ACCOUNT_ID/" | kubectl apply -f -
```

### 7. Verify deployment and connect the Lambda

```sh
kubectl get pods -n backend
kubectl get ingress -n backend
```

The ALB address from the ingress output is the public endpoint of the application. Copy it into `health_endpoint` in `environments/prod/terraform.tfvars` and run `terraform apply` again, so the Lambda checks the right URL.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Usage

### API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | API info and version |
| GET | `/livez` | Liveness check — the process is running (no DB) |
| GET | `/health` | Readiness check — verifies DB connectivity |
| POST | `/api/files/upload` | Upload a file to S3 (`uploads/` prefix, max 10 MB) |
| GET | `/api/files/download?key=uploads/file.pdf` | Download a file from S3 via the backend |
| GET | `/api/files/list?prefix=uploads/` | List files under an S3 prefix |

The `/api` endpoints require the `x-api-key` header.

### Example requests

```sh
API_KEY=$(kubectl get secret backend-api-key -n backend -o jsonpath='{.data.api_key}' | base64 -d)

# Health check
curl http://<ALB_URL>/health

# Upload a file
curl -H "x-api-key: $API_KEY" -F "file=@./document.pdf" http://<ALB_URL>/api/files/upload

# List uploaded files
curl -H "x-api-key: $API_KEY" "http://<ALB_URL>/api/files/list?prefix=uploads/"
```

### Lambda service check

The Lambda function runs automatically every hour via EventBridge. To trigger it manually:

```sh
aws lambda invoke \
  --function-name eks-corp-prod-service-check \
  --region eu-west-3 \
  output.json && cat output.json
```

Reports are saved to `s3://eks-corp-prod-company-<account_id>/reports/`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Design Decisions

- **Own modules, no third-party modules** — every resource is written out, so each one can be explained.
- **Pod Identity instead of IRSA** — no OIDC provider and no annotated ServiceAccounts, only one association per service account.
- **One NAT Gateway per AZ** — if one AZ goes down, the others can still reach the internet. It costs three times as much as a single NAT.
- **RDS allows the EKS cluster security group** — managed nodes without a launch template only get this security group.
- **DB credentials in Secrets Manager** — the pod reads them at startup, so they are never in Git or in the manifests.
- **Subnets and NAT Gateways keyed by AZ (`for_each`)** — removing an AZ only touches that AZ, not the ones after it.
- **Backend IAM in the root module** — the RDS and S3 modules only export policies; `backend-iam.tf` decides what the backend gets.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Known Limitations

- HTTP only — there is no domain, so no ACM certificate and no HTTPS.
- The API key is a simple shared secret, not real authentication.
- The connection to RDS is encrypted, but the server certificate is not verified.
- `health_endpoint` has to be updated by hand after the ALB is created.
- There is no cluster autoscaler; the node group only has min/max bounds.
- The Kubernetes side (Helm chart, manifests) is applied by hand, not by Terraform.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Cost and Cleanup

Running the full stack costs about 450 USD/month (rough estimate, on-demand prices in eu-west-3): EKS control plane, 3 NAT Gateways, 2 × t3.large nodes, Multi-AZ RDS and the ALB make up most of it.

Tear it down in this order — the ALB is created by the Load Balancer Controller, not by Terraform, so it has to be removed first or it blocks the VPC deletion:

```sh
kubectl delete -k k8s/apps/backend
helm uninstall aws-load-balancer-controller -n kube-system
terraform -chdir=environments/prod destroy
```

A few things to know before and after `destroy`:

- The company bucket is versioned and the Lambda writes a report every hour, so empty it (all object versions) first, otherwise `destroy` fails on it.
- RDS leaves a final snapshot (`eks-corp-prod-final-snapshot`). It keeps costing money until you delete it, and the next `destroy` fails while it exists.
- The DB secret is not deleted right away: it has a 7-day recovery window. Applying again within that week fails, unless you remove it for good with `aws secretsmanager delete-secret --secret-id eks-corp/prod/db-credentials --force-delete-without-recovery`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Project Structure

```
eks-corp/
├── .github/workflows/ci.yml   # fmt + validate, Docker build, kustomize render
├── backend/                   # Express API (index.js, Dockerfile)
├── environments/prod/         # root module: main.tf, backend-iam.tf, variables, tfvars
├── modules/                   # vpc, ecr, eks, rds, s3, lambda
├── k8s/apps/backend/          # Kubernetes manifests + kustomization.yaml
└── lambda/service_check/      # hourly health check Lambda
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Roadmap

- [x] VPC with multi-AZ networking
- [x] EKS cluster with a managed node group
- [x] Private ECR repositories
- [x] AWS Load Balancer Controller with Pod Identity
- [x] RDS PostgreSQL Multi-AZ with Secrets Manager
- [x] Company S3 bucket with folder-level IAM policies
- [x] S3 file upload/download via backend API
- [x] Remote Terraform state (S3 + DynamoDB)
- [x] Lambda service check automation with EventBridge
- [x] CI: Terraform fmt/validate, Docker build, kustomize render
- [ ] HTTPS with a domain and an ACM certificate
- [ ] Kubernetes side (Helm, manifests) managed by Terraform
- [ ] CloudFront + S3 static website
- [ ] HR management backend application with authentication
- [ ] Automated test suite

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Contact

Kövy Dániel - (Daniel Koevy) 

GitHub: https://github.com/KovyD20

LinkedIn: <https://www.linkedin.com/in/danielkovy>

E-mail: kovy.d20@gmail.com

Project Link: [https://github.com/KovyD20/eks-corp](https://github.com/KovyD20/eks-corp)



<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- MARKDOWN LINKS & IMAGES -->
[Terraform-badge]: https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white
[Terraform-url]: https://www.terraform.io/
[AWS-badge]: https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white
[AWS-url]: https://aws.amazon.com/
[K8s-badge]: https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white
[K8s-url]: https://kubernetes.io/
[Node-badge]: https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white
[Node-url]: https://nodejs.org/
[Docker-badge]: https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white
[Docker-url]: https://www.docker.com/
[Postgres-badge]: https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white
[Postgres-url]: https://www.postgresql.org/
