@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy oracle-service-broker to GCP GKE
REM ============================================================

set APP_NAME=oracle-service-broker
set NAMESPACE=oracle-service-broker

echo ============================================================
echo  Deploy to GCP GKE
echo  Application: %APP_NAME%
echo  Namespace:   %NAMESPACE%
echo ============================================================
echo.

REM Prompt for GCP configuration
set /p GCP_PROJECT="Enter GCP Project ID: "
if "!GCP_PROJECT!"=="" (
    echo ERROR: GCP Project ID is required.
    exit /b 1
)

set /p GCP_ZONE="Enter GCP Zone (e.g., us-central1-a): "
if "!GCP_ZONE!"=="" (
    echo ERROR: GCP Zone is required.
    exit /b 1
)

set /p CLUSTER_NAME="Enter GKE Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: GKE Cluster Name is required.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/my-repo/oracle-service-broker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo Collecting application environment configuration...
echo (Press Enter to skip any optional value)
echo.

set /p SPRING_DATASOURCE_URL="Enter SPRING_DATASOURCE_URL (Oracle JDBC URL): "
set /p SPRING_DATASOURCE_USERNAME="Enter SPRING_DATASOURCE_USERNAME (Oracle DB username): "
set /p SPRING_DATASOURCE_PASSWORD="Enter SPRING_DATASOURCE_PASSWORD (Oracle DB password): "
set /p SPRING_JPA_HIBERNATE_DDL_AUTO_INPUT="Enter SPRING_JPA_HIBERNATE_DDL_AUTO (default: update): "
if "!SPRING_JPA_HIBERNATE_DDL_AUTO_INPUT!"=="" (
    set SPRING_JPA_HIBERNATE_DDL_AUTO=update
) else (
    set SPRING_JPA_HIBERNATE_DDL_AUTO=!SPRING_JPA_HIBERNATE_DDL_AUTO_INPUT!
)
set /p ORACLE_TABLESPACENAME_INPUT="Enter ORACLE_TABLESPACENAME (default: CF_TABLESPACE): "
if "!ORACLE_TABLESPACENAME_INPUT!"=="" (
    set ORACLE_TABLESPACENAME=CF_TABLESPACE
) else (
    set ORACLE_TABLESPACENAME=!ORACLE_TABLESPACENAME_INPUT!
)
set /p ORACLE_TEMPTABLESPACENAME_INPUT="Enter ORACLE_TEMPTABLESPACENAME (default: TEMP): "
if "!ORACLE_TEMPTABLESPACENAME_INPUT!"=="" (
    set ORACLE_TEMPTABLESPACENAME=TEMP
) else (
    set ORACLE_TEMPTABLESPACENAME=!ORACLE_TEMPTABLESPACENAME_INPUT!
)
set /p SECURITY_USER_NAME_INPUT="Enter SECURITY_USER_NAME (default: user): "
if "!SECURITY_USER_NAME_INPUT!"=="" (
    set SECURITY_USER_NAME=user
) else (
    set SECURITY_USER_NAME=!SECURITY_USER_NAME_INPUT!
)
set /p SECURITY_USER_PASSWORD_INPUT="Enter SECURITY_USER_PASSWORD (default: password): "
if "!SECURITY_USER_PASSWORD_INPUT!"=="" (
    set SECURITY_USER_PASSWORD=password
) else (
    set SECURITY_USER_PASSWORD=!SECURITY_USER_PASSWORD_INPUT!
)

echo.
echo ============================================================
echo  Configuring kubectl for GKE cluster...
echo ============================================================

gcloud container clusters get-credentials !CLUSTER_NAME! --zone !GCP_ZONE! --project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get GKE cluster credentials.
    exit /b 1
)

echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to cluster.
    exit /b 1
)

echo.
echo ============================================================
echo  Updating Kubernetes manifests with deployment values...
echo ============================================================

set DEPLOY_DIR=kubernetes

REM Update deployment.yaml placeholders using PowerShell
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{SPRING_DATASOURCE_URL}}', '!SPRING_DATASOURCE_URL!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{SPRING_DATASOURCE_USERNAME}}', '!SPRING_DATASOURCE_USERNAME!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{SPRING_DATASOURCE_PASSWORD}}', '!SPRING_DATASOURCE_PASSWORD!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{SPRING_JPA_HIBERNATE_DDL_AUTO}}', '!SPRING_JPA_HIBERNATE_DDL_AUTO!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{ORACLE_TABLESPACENAME}}', '!ORACLE_TABLESPACENAME!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{ORACLE_TEMPTABLESPACENAME}}', '!ORACLE_TEMPTABLESPACENAME!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{SECURITY_USER_NAME}}', '!SECURITY_USER_NAME!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"
powershell -Command "(Get-Content '%DEPLOY_DIR%\deployment.yaml') -replace '{{SECURITY_USER_PASSWORD}}', '!SECURITY_USER_PASSWORD!' | Set-Content '%DEPLOY_DIR%\deployment.yaml'"

echo.
echo ============================================================
echo  Applying Kubernetes manifests...
echo ============================================================

echo Applying namespace...
kubectl apply -f %DEPLOY_DIR%\namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    exit /b 1
)

echo Applying deployment...
kubectl apply -f %DEPLOY_DIR%\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    exit /b 1
)

echo Applying service...
kubectl apply -f %DEPLOY_DIR%\service.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    exit /b 1
)

echo Applying ingress...
kubectl apply -f %DEPLOY_DIR%\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    exit /b 1
)

echo.
echo ============================================================
echo  Waiting for deployment rollout...
echo ============================================================
kubectl rollout status deployment/%APP_NAME% -n %NAMESPACE% --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed. Initiating rollback...
    kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%
    echo Rollback initiated. Check pod status with:
    echo   kubectl get pods -n %NAMESPACE%
    exit /b 1
)

echo.
echo ============================================================
echo  Verifying deployed resources...
echo ============================================================
kubectl get pods,svc,ingress -n %NAMESPACE%

echo.
echo ============================================================
echo  Deployment completed successfully!
echo ============================================================
echo.
echo Useful commands:
echo   kubectl get pods -n %NAMESPACE%
echo   kubectl logs -f deployment/%APP_NAME% -n %NAMESPACE%
echo   kubectl describe deployment/%APP_NAME% -n %NAMESPACE%
echo   kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%

endlocal
