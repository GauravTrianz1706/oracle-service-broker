# Deployment Guide: oracle-service-broker on GCP GKE

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Local Development with Docker Compose](#local-development-with-docker-compose)
5. [Building and Pushing the Docker Image](#building-and-pushing-the-docker-image)
6. [GCP GKE Deployment](#gcp-gke-deployment)
7. [Kubernetes Manifest Descriptions](#kubernetes-manifest-descriptions)
8. [Configuration Management](#configuration-management)
9. [Scaling and Management](#scaling-and-management)
10. [Troubleshooting](#troubleshooting)
11. [Security Considerations](#security-considerations)
12. [Java-Specific Notes](#java-specific-notes)

---

## Overview

**Application**: oracle-service-broker  
**Description**: Oracle Service Broker for Cloud Foundry (PCF) - manages Oracle database user provisioning  
**Technology Stack**: Java 8, Spring Boot 1.5.6, Maven  
**Target Platform**: GCP GKE (Google Kubernetes Engine)  
**Application Port**: 8080  
**Health Endpoint**: `/health` (Spring Boot 1.x Actuator)

---

## Prerequisites

### Local Development
- Docker Desktop 20.10+
- Docker Compose 2.x
- Java 8 JDK (for local builds)
- Maven 3.8+ (for local builds)
- Access to an Oracle Database instance

### GCP GKE Deployment
- Google Cloud SDK (`gcloud`) installed and authenticated
- `kubectl` CLI installed (v1.24+)
- GCP Project with billing enabled
- GKE cluster created and running
- Google Artifact Registry or Docker Hub account
- Oracle Database accessible from the GKE cluster

### Install Google Cloud SDK
```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Windows
# Download installer from: https://cloud.google.com/sdk/docs/install
```

### Install kubectl
```bash
# Via gcloud
gcloud components install kubectl

# Via package manager (macOS)
brew install kubectl

# Verify installation
kubectl version --client
```

---

## Project Structure

```
BE/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build configuration
├── src/
│   └── main/
│       ├── java/                 # Java source code
│       └── resources/
│           └── application.yml   # Application configuration
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Kubernetes deployment
│   ├── service.yaml              # Kubernetes service (ClusterIP)
│   └── ingress.yaml              # Kubernetes ingress (GCE)
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push script
│   ├── build-push.bat            # Windows build & push script
│   ├── deploy-image.sh           # Linux/macOS GKE deploy script
│   └── deploy-image.bat          # Windows GKE deploy script
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development with Docker Compose

### Step 1: Configure Environment Variables

Create a `.env` file in the project root (never commit this file):

```env
SPRING_DATASOURCE_URL=jdbc:oracle:thin:@//your-oracle-host:1521/orcl
SPRING_DATASOURCE_USERNAME=system
SPRING_DATASOURCE_PASSWORD=your_oracle_password
SPRING_JPA_HIBERNATE_DDL_AUTO=update
ORACLE_TABLESPACENAME=CF_TABLESPACE
ORACLE_TEMPTABLESPACENAME=TEMP
SECURITY_USER_NAME=user
SECURITY_USER_PASSWORD=your_broker_password
```

### Step 2: Build and Start the Application

```bash
# Build the Docker image
docker build -t oracle-service-broker:latest .

# Start the application
docker-compose up -d

# View logs
docker-compose logs -f oracle-service-broker

# Stop the application
docker-compose down
```

### Step 3: Verify the Application

```bash
# Check health endpoint
curl http://localhost:8080/health

# Check application info
curl http://localhost:8080/info

# Check service broker catalog
curl -u user:password http://localhost:8080/v2/catalog
```

---

## Building and Pushing the Docker Image

### Linux/macOS

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run from project root
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (defaults to `latest`)
2. Select registry type (Google Artifact Registry or Docker Hub)
3. Provide registry credentials and details

### Windows

```cmd
# Run from project root
scripts\build-push.bat
```

### Manual Build and Push (Google Artifact Registry)

```bash
# Authenticate
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/oracle-service-broker:latest .

# Push
docker push us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/oracle-service-broker:latest
```

### Manual Build and Push (Docker Hub)

```bash
# Login
docker login

# Build
docker build -t YOUR_USERNAME/oracle-service-broker:latest .

# Push
docker push YOUR_USERNAME/oracle-service-broker:latest
```

---

## GCP GKE Deployment

### Step 1: Set Up GCP Project

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Authenticate
gcloud auth login
```

### Step 2: Create GKE Cluster (if not existing)

```bash
# Create a standard GKE cluster
gcloud container clusters create oracle-service-broker-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type e2-standard-2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 5

# Get credentials
gcloud container clusters get-credentials oracle-service-broker-cluster \
  --zone us-central1-a \
  --project YOUR_PROJECT_ID
```

### Step 3: Create Artifact Registry Repository (if using GAR)

```bash
gcloud artifacts repositories create oracle-service-broker-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Oracle Service Broker Docker images"
```

### Step 4: Build and Push the Image

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

### Step 5: Deploy to GKE

```bash
# Linux/macOS
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh

# Windows
scripts\deploy-image.bat
```

The deploy script will:
1. Prompt for GCP project, zone, and cluster name
2. Prompt for the Docker image URI
3. Prompt for Oracle database connection details
4. Configure kubectl with cluster credentials
5. Apply all Kubernetes manifests in order
6. Wait for deployment rollout
7. Display the application URL

### Step 6: Verify Deployment

```bash
# Check all resources in the namespace
kubectl get all -n oracle-service-broker

# Check pod status
kubectl get pods -n oracle-service-broker

# View pod logs
kubectl logs -f deployment/oracle-service-broker -n oracle-service-broker

# Check ingress
kubectl get ingress -n oracle-service-broker
```

---

## Kubernetes Manifest Descriptions

### namespace.yaml
Creates the `oracle-service-broker` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (for high availability)
- **Image**: Pulled from your configured registry
- **Resources**: 
  - Requests: 250m CPU, 512Mi memory
  - Limits: 500m CPU, 1Gi memory
- **Health Probes**:
  - Liveness: `GET /health` (initial delay: 60s, period: 30s)
  - Readiness: `GET /health` (initial delay: 30s, period: 15s)
- **JVM Options**: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`

### service.yaml
- **Type**: ClusterIP (internal cluster access)
- **Port**: 80 → 8080 (container port)
- Exposes the application within the cluster

### ingress.yaml
- **Class**: GCE (Google Cloud Load Balancer)
- **Host**: `oracle-service-broker.example.com` (update to your domain)
- Routes external traffic to the service

---

## Configuration Management

### Environment Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `SPRING_DATASOURCE_URL` | Oracle JDBC connection URL | Required |
| `SPRING_DATASOURCE_USERNAME` | Oracle database username | Required |
| `SPRING_DATASOURCE_PASSWORD` | Oracle database password | Required |
| `SPRING_JPA_HIBERNATE_DDL_AUTO` | Hibernate DDL mode | `update` |
| `ORACLE_TABLESPACENAME` | Oracle tablespace for new users | `CF_TABLESPACE` |
| `ORACLE_TEMPTABLESPACENAME` | Oracle temp tablespace | `TEMP` |
| `SECURITY_USER_NAME` | Service broker API username | `user` |
| `SECURITY_USER_PASSWORD` | Service broker API password | Required |
| `SPRING_PROFILES_ACTIVE` | Active Spring profile | `docker` |
| `JAVA_OPTS` | JVM options | See Dockerfile |
| `TZ` | Timezone | `UTC` |

### Using Kubernetes Secrets (Recommended for Production)

```bash
# Create a secret for sensitive values
kubectl create secret generic oracle-service-broker-secrets \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:oracle:thin:@//oracle-host:1521/orcl" \
  --from-literal=SPRING_DATASOURCE_USERNAME="system" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="your_password" \
  --from-literal=SECURITY_USER_PASSWORD="your_broker_password" \
  -n oracle-service-broker
```

Then reference in deployment.yaml:
```yaml
env:
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: oracle-service-broker-secrets
        key: SPRING_DATASOURCE_PASSWORD
```

---

## Scaling and Management

### Manual Scaling

```bash
# Scale up
kubectl scale deployment oracle-service-broker --replicas=3 -n oracle-service-broker

# Scale down
kubectl scale deployment oracle-service-broker --replicas=1 -n oracle-service-broker
```

### Horizontal Pod Autoscaler (HPA)

```bash
kubectl autoscale deployment oracle-service-broker \
  --cpu-percent=70 \
  --min=2 \
  --max=5 \
  -n oracle-service-broker
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/oracle-service-broker \
  oracle-service-broker=NEW_IMAGE_URI \
  -n oracle-service-broker

# Monitor rollout
kubectl rollout status deployment/oracle-service-broker -n oracle-service-broker
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/oracle-service-broker -n oracle-service-broker

# Rollback to specific revision
kubectl rollout history deployment/oracle-service-broker -n oracle-service-broker
kubectl rollout undo deployment/oracle-service-broker --to-revision=2 -n oracle-service-broker
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n oracle-service-broker

# Describe pod for events
kubectl describe pod POD_NAME -n oracle-service-broker

# Check logs
kubectl logs POD_NAME -n oracle-service-broker
kubectl logs POD_NAME -n oracle-service-broker --previous  # Previous container logs
```

### Common Issues

**1. OOMKilled (Out of Memory)**
```bash
# Increase memory limits in deployment.yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "1Gi"
```

**2. Oracle Connection Refused**
- Verify `SPRING_DATASOURCE_URL` is correct and reachable from GKE
- Check Oracle firewall rules allow connections from GKE node IPs
- Verify Oracle listener is running on the specified port

**3. CrashLoopBackOff**
```bash
# Check logs for startup errors
kubectl logs POD_NAME -n oracle-service-broker

# Common causes:
# - Invalid Oracle JDBC URL
# - Wrong database credentials
# - Oracle tablespace does not exist
```

**4. Liveness Probe Failing**
- Spring Boot 1.x uses `/health` endpoint (not `/actuator/health`)
- Increase `initialDelaySeconds` if JVM startup is slow
- Check if Oracle connection is causing slow startup

**5. Ingress Not Getting External IP**
```bash
# Check ingress status
kubectl describe ingress oracle-service-broker-ingress -n oracle-service-broker

# Ensure GKE has HTTP Load Balancing enabled
gcloud container clusters describe CLUSTER_NAME --zone ZONE | grep httpLoadBalancing
```

**6. ImagePullBackOff**
```bash
# Check image URI is correct
kubectl describe pod POD_NAME -n oracle-service-broker

# Ensure GKE has access to the registry
# For Artifact Registry, ensure Workload Identity or service account is configured
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

---

## Security Considerations

1. **Never commit secrets** to version control - use Kubernetes Secrets or GCP Secret Manager
2. **Use non-root user** - the Dockerfile already creates and uses `appuser`
3. **Network policies** - consider adding Kubernetes NetworkPolicy to restrict pod communication
4. **RBAC** - apply least-privilege RBAC for service accounts
5. **Image scanning** - enable vulnerability scanning in Artifact Registry
6. **TLS/HTTPS** - configure TLS termination at the Ingress level using a managed certificate:

```yaml
# Add to ingress.yaml annotations
annotations:
  networking.gke.io/managed-certificates: oracle-service-broker-cert
  kubernetes.io/ingress.allow-http: "false"
```

7. **Rotate credentials** - regularly rotate Oracle database passwords and broker API credentials
8. **Audit logging** - enable GKE audit logging for compliance

---

## Java-Specific Notes

### JVM Configuration
The application uses the following JVM flags optimized for containers:
- `-Xmx512m` - Maximum heap size
- `-Xms256m` - Initial heap size
- `-XX:+UseContainerSupport` - Enables container-aware memory management
- `-XX:MaxRAMPercentage=75.0` - Use up to 75% of container memory for heap
- `-Djava.security.egd=file:/dev/./urandom` - Faster random number generation

### Spring Boot 1.x Actuator
This application uses Spring Boot 1.5.x which has different actuator endpoint paths:
- Health: `GET /health` (not `/actuator/health`)
- Info: `GET /info`
- Metrics: `GET /metrics`

### Oracle JDBC Driver
The application uses `ojdbc11` (version 23.4.0.24.05). Ensure your Oracle database version is compatible with this driver.

### Service Broker API
The application implements the Cloud Foundry Service Broker API v2. The catalog endpoint is:
```
GET /v2/catalog
Authorization: Basic <base64(username:password)>
```

### Startup Time
Spring Boot 1.x with Oracle JDBC connection may take 30-60 seconds to start. The liveness probe is configured with a 60-second initial delay to accommodate this.
