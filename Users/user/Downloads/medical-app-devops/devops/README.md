# Medical App — AWS Deployment Guide
**Stack:** NestJS Backend · React/Vite Frontend · MySQL (RDS) · EKS · ECR · Terraform · GitHub Actions

---

## Prerequisites

Install these tools locally:
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/)
- [Helm](https://helm.sh/docs/intro/install/)

---

## Step 1 — Prepare Your Project

Copy the DevOps files into your project root:

```
your-project/
├── backend/          ← your NestJS app
│   └── Dockerfile    ← copy from devops/backend/Dockerfile
├── frontend/         ← your React app
│   ├── Dockerfile    ← copy from devops/frontend/Dockerfile
│   └── nginx.conf    ← copy from devops/frontend/nginx.conf
├── terraform/        ← copy entire terraform/ folder
├── k8s/              ← copy entire k8s/ folder
└── .github/
    └── workflows/
        └── deploy.yml  ← copy from devops/.github/workflows/deploy.yml
```

Add to your backend `src/app.controller.ts`:
```typescript
@Get('health')
health() { return { status: 'ok' }; }
```
(Required for K8s health checks.)

---

## Step 2 — Provision AWS Infrastructure

```bash
cd terraform

# Create S3 bucket for Terraform state (one-time)
aws s3 mb s3://medical-app-terraform-state --region us-east-1

# Set your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — add your db_password

terraform init
terraform plan     # review what will be created
terraform apply    # takes ~15 minutes
```

Note the outputs:
```bash
terraform output eks_cluster_name    # e.g. medical-app-cluster
terraform output ecr_backend_url     # e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/medical-app/backend
terraform output rds_endpoint        # e.g. medical-app-mysql.xxxx.us-east-1.rds.amazonaws.com:3306
```

---

## Step 3 — Configure kubectl

```bash
aws eks update-kubeconfig --name medical-app-cluster --region us-east-1
kubectl get nodes   # should show your worker nodes
```

---

## Step 4 — Install AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=medical-app-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller
```

---

## Step 5 — Create Kubernetes Secrets

Replace the RDS endpoint from Step 2:

```bash
kubectl create namespace medical-app

kubectl create secret generic medical-app-secrets \
  --namespace=medical-app \
  --from-literal=DB_HOST=<rds-endpoint-without-port> \
  --from-literal=DB_PORT=3306 \
  --from-literal=DB_USERNAME=admin \
  --from-literal=DB_PASSWORD=YourStrongPasswordHere123! \
  --from-literal=DB_DATABASE=medical \
  --from-literal=JWT_SECRET=your-strong-random-64-char-string \
  --from-literal=JWT_EXPIRES_IN=7d \
  --from-literal=JWT_REFRESH_SECRET=another-strong-random-64-char-string \
  --from-literal=JWT_REFRESH_EXPIRES_IN=30d
```

---

## Step 6 — Update Image URLs in K8s Manifests

Edit `k8s/01-backend.yaml` and `k8s/02-frontend.yaml`:
Replace `REPLACE_WITH_ECR_*_URL` with the actual ECR URLs from Step 2.

---

## Step 7 — Apply Kubernetes Manifests

```bash
kubectl apply -f k8s/00-namespace-secret.yaml
kubectl apply -f k8s/01-backend.yaml
kubectl apply -f k8s/02-frontend.yaml
kubectl apply -f k8s/03-ingress.yaml
kubectl apply -f k8s/04-hpa.yaml

# Watch pods start up
kubectl get pods -n medical-app -w
```

---

## Step 8 — Set Up CI/CD (GitHub Actions)

Add these secrets in GitHub → Settings → Secrets and Variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | From IAM user for CI/CD |
| `AWS_SECRET_ACCESS_KEY` | From IAM user for CI/CD |

Create an IAM user with these policies:
- `AmazonECR_FullAccess`
- `AmazonEKSClusterPolicy`

Now every push to `main` will:
1. Run tests
2. Build & push Docker images to ECR
3. Deploy to EKS with zero downtime

---

## Step 9 — Get Your App URL

```bash
kubectl get ingress -n medical-app
# Copy the ADDRESS column — this is your ALB DNS name
```

Your app will be at: `http://<alb-dns-name>`

---

## Useful Commands

```bash
# View logs
kubectl logs -n medical-app deployment/backend -f
kubectl logs -n medical-app deployment/frontend -f

# Scale manually
kubectl scale deployment backend -n medical-app --replicas=3

# Rollback a bad deployment
kubectl rollout undo deployment/backend -n medical-app

# SSH into a pod
kubectl exec -it -n medical-app deployment/backend -- sh
```

---

## Cost Estimate (us-east-1)

| Service | Type | ~Monthly Cost |
|---------|------|---------------|
| EKS Cluster | Control plane | $73 |
| EC2 Nodes | 2x t3.medium | $60 |
| RDS MySQL | db.t3.micro | $15 |
| NAT Gateway | 1x | $32 |
| ALB | per request | ~$20 |
| ECR | storage | ~$1 |
| **Total** | | **~$200/mo** |

> Tip: Use Spot instances for nodes to cut EC2 cost by 70%.
