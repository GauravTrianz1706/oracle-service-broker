#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy oracle-service-broker to GCP GKE
# ============================================================

APP_NAME="oracle-service-broker"
NAMESPACE="oracle-service-broker"

echo "============================================================"
echo " Deploy to GCP GKE"
echo " Application: $APP_NAME"
echo " Namespace:   $NAMESPACE"
echo "============================================================"
echo ""

# Prompt for GCP configuration
read -p "Enter GCP Project ID: " GCP_PROJECT
if [ -z "$GCP_PROJECT" ]; then
  echo "ERROR: GCP Project ID is required."
  exit 1
fi

read -p "Enter GCP Zone (e.g., us-central1-a): " GCP_ZONE
if [ -z "$GCP_ZONE" ]; then
  echo "ERROR: GCP Zone is required."
  exit 1
fi

read -p "Enter GKE Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: GKE Cluster Name is required."
  exit 1
fi

read -p "Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/my-repo/oracle-service-broker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "Collecting application environment configuration..."
echo "(Press Enter to skip any optional value)"
echo ""

read -p "Enter SPRING_DATASOURCE_URL (Oracle JDBC URL): " SPRING_DATASOURCE_URL
read -p "Enter SPRING_DATASOURCE_USERNAME (Oracle DB username): " SPRING_DATASOURCE_USERNAME
read -s -p "Enter SPRING_DATASOURCE_PASSWORD (Oracle DB password): " SPRING_DATASOURCE_PASSWORD
echo ""
read -p "Enter SPRING_JPA_HIBERNATE_DDL_AUTO (default: update): " SPRING_JPA_HIBERNATE_DDL_AUTO_INPUT
SPRING_JPA_HIBERNATE_DDL_AUTO="${SPRING_JPA_HIBERNATE_DDL_AUTO_INPUT:-update}"
read -p "Enter ORACLE_TABLESPACENAME (default: CF_TABLESPACE): " ORACLE_TABLESPACENAME_INPUT
ORACLE_TABLESPACENAME="${ORACLE_TABLESPACENAME_INPUT:-CF_TABLESPACE}"
read -p "Enter ORACLE_TEMPTABLESPACENAME (default: TEMP): " ORACLE_TEMPTABLESPACENAME_INPUT
ORACLE_TEMPTABLESPACENAME="${ORACLE_TEMPTABLESPACENAME_INPUT:-TEMP}"
read -p "Enter SECURITY_USER_NAME (default: user): " SECURITY_USER_NAME_INPUT
SECURITY_USER_NAME="${SECURITY_USER_NAME_INPUT:-user}"
read -s -p "Enter SECURITY_USER_PASSWORD (default: password): " SECURITY_USER_PASSWORD_INPUT
echo ""
SECURITY_USER_PASSWORD="${SECURITY_USER_PASSWORD_INPUT:-password}"

echo ""
echo "============================================================"
echo " Configuring kubectl for GKE cluster..."
echo "============================================================"

gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get GKE cluster credentials."
  exit 1
fi

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || exit 1

echo ""
echo "============================================================"
echo " Updating Kubernetes manifests with deployment values..."
echo "============================================================"

# Work on copies of manifests to avoid modifying originals
DEPLOY_DIR="kubernetes"

# Update deployment.yaml with actual values using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{SPRING_DATASOURCE_URL}}|${SPRING_DATASOURCE_URL}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{SPRING_DATASOURCE_USERNAME}}|${SPRING_DATASOURCE_USERNAME}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{SPRING_DATASOURCE_PASSWORD}}|${SPRING_DATASOURCE_PASSWORD}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{SPRING_JPA_HIBERNATE_DDL_AUTO}}|${SPRING_JPA_HIBERNATE_DDL_AUTO}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{ORACLE_TABLESPACENAME}}|${ORACLE_TABLESPACENAME}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{ORACLE_TEMPTABLESPACENAME}}|${ORACLE_TEMPTABLESPACENAME}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{SECURITY_USER_NAME}}|${SECURITY_USER_NAME}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{SECURITY_USER_PASSWORD}}|${SECURITY_USER_PASSWORD}|g" "${DEPLOY_DIR}/deployment.yaml"

echo ""
echo "============================================================"
echo " Applying Kubernetes manifests..."
echo "============================================================"

echo "Applying namespace..."
kubectl apply -f "${DEPLOY_DIR}/namespace.yaml"

echo "Applying deployment..."
kubectl apply -f "${DEPLOY_DIR}/deployment.yaml"

echo "Applying service..."
kubectl apply -f "${DEPLOY_DIR}/service.yaml"

echo "Applying ingress..."
kubectl apply -f "${DEPLOY_DIR}/ingress.yaml"

echo ""
echo "============================================================"
echo " Waiting for deployment rollout..."
echo "============================================================"
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed. Initiating rollback..."
  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}
  echo "Rollback initiated. Check pod status with:"
  echo "  kubectl get pods -n ${NAMESPACE}"
  exit 1
fi

echo ""
echo "============================================================"
echo " Verifying deployed resources..."
echo "============================================================"
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "============================================================"
echo " Retrieving application access URL..."
echo "============================================================"
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$INGRESS_IP" = "pending" ] || [ -z "$INGRESS_IP" ]; then
  echo "Ingress IP is still being provisioned. Check later with:"
  echo "  kubectl get ingress -n ${NAMESPACE}"
else
  echo "Application is accessible at: http://${INGRESS_IP}"
fi

echo ""
echo "============================================================"
echo " Deployment completed successfully!"
echo "============================================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl describe deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}  # Rollback"
