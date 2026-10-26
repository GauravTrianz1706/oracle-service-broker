@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM build-push.bat - Build and push Docker image for oracle-service-broker
REM Target Platform: GCP GKE
REM ============================================================

set PROJECT_NAME=oracle-service-broker

REM Sanitize image name to lowercase with hyphens
set IMAGE_NAME=oracle-service-broker

echo ============================================================
echo  Build ^& Push Docker Image
echo  Application: %PROJECT_NAME%
echo ============================================================
echo.

REM Prompt for image tag
set /p IMAGE_TAG_INPUT="Enter image tag (press Enter for 'latest'): "
if "!IMAGE_TAG_INPUT!"=="" (
    set IMAGE_TAG=latest
) else (
    set IMAGE_TAG=!IMAGE_TAG_INPUT!
)
echo Using image tag: !IMAGE_TAG!
echo.

REM Prompt for registry type
echo Select container registry:
echo   1. Google Artifact Registry
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice (1 or 2): "
echo.

if "!REGISTRY_CHOICE!"=="1" (
    REM Google Artifact Registry
    set /p GCP_PROJECT="Enter GCP Project ID: "
    set /p GCP_REGION="Enter GCP Region (e.g., us-central1): "
    set /p AR_REPO="Enter Artifact Registry repository name: "

    set FULL_IMAGE_NAME=!GCP_REGION!-docker.pkg.dev/!GCP_PROJECT!/!AR_REPO!/!IMAGE_NAME!:!IMAGE_TAG!

    echo Authenticating with Google Artifact Registry...
    gcloud auth configure-docker !GCP_REGION!-docker.pkg.dev
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Artifact Registry authentication failed.
        exit /b 1
    )

) else if "!REGISTRY_CHOICE!"=="2" (
    REM Docker Hub
    set /p DOCKER_USERNAME="Enter Docker Hub username: "
    set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
    set /p DOCKER_REPO_INPUT="Enter Docker Hub repository name (default: !IMAGE_NAME!): "
    if "!DOCKER_REPO_INPUT!"=="" (
        set DOCKER_REPO=!IMAGE_NAME!
    ) else (
        set DOCKER_REPO=!DOCKER_REPO_INPUT!
    )

    set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!DOCKER_REPO!:!IMAGE_TAG!

    echo Authenticating with Docker Hub...
    echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Docker Hub authentication failed.
        exit /b 1
    )

) else (
    echo ERROR: Invalid registry choice. Please enter 1 or 2.
    exit /b 1
)

echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Build context: %CD%
echo.

docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)

echo.
echo Pushing Docker image: !FULL_IMAGE_NAME!
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ============================================================
echo  SUCCESS: Image pushed successfully!
echo  Image: !FULL_IMAGE_NAME!
echo ============================================================
echo.
echo Use this image URI in your deployment:
echo   !FULL_IMAGE_NAME!

endlocal
