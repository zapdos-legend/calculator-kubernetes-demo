# calculator-kubernetes-demo

## Project purpose

This project demonstrates a complete beginner-friendly application and DevOps workflow, beginning with a browser-based calculator and eventually progressing through containerization and local Kubernetes deployment. Development is intentionally completed one phase at a time.

## Current phase

**Phase 5 — Kubernetes deployment preparation**

The calculator frontend is packaged in a simple Nginx-based Docker image, with AWS CodeBuild setup and Docker Hub publishing instructions. Kubernetes manifests now prepare two calculator replicas and a NodePort Service for a future Killercoda demonstration; this phase does not deploy them to a cluster.

## Technologies used

- HTML5
- CSS3
- Vanilla JavaScript

The application has no backend, package manager, external framework, or runtime dependency.

## Run locally

1. Clone or download this repository.
2. Open `index.html` in a modern web browser.

Alternatively, if Python is already installed, serve the directory locally:

```bash
python3 -m http.server 8000
```

Then visit [http://localhost:8000](http://localhost:8000) in a browser. No installation or build step is required.

## Phase 2 - Docker

Build the local Docker image:

```bash
docker build -t calculator-kubernetes-demo:latest .
```

Start the calculator container and map host port 8080 to Nginx on port 80:

```bash
docker run -d --name calculator-demo -p 8080:80 calculator-kubernetes-demo:latest
```

Visit [http://localhost:8080](http://localhost:8080) in a browser.

Verify the running container and review its logs:

```bash
docker ps
docker logs calculator-demo
```

Stop and remove the container when finished:

```bash
docker stop calculator-demo
docker rm calculator-demo
```

## Calculator controls

Use the on-screen keypad, or use number keys and the `+`, `-`, `*`, and `/` keys. Press `Enter` or `=` to calculate, `Backspace` to delete the last digit, and `Escape` to clear the calculator.

## Phase 3 - AWS CodeBuild

- [`aws/codebuild-setup.ps1`](aws/codebuild-setup.ps1) creates or updates the CodeBuild project in `ap-south-1`, using the public GitHub `main` branch and the repository's `buildspec.yml`.
- The script first verifies the selected AWS CLI profile, reuses an existing named IAM role when present, and limits that role to writing this project's CloudWatch log group.
- The build uses the smallest CodeBuild compute type, enables privileged mode for Docker, and produces no external artifacts.
- No ECR, Docker Hub push, VPC, environment secrets, or Kubernetes resources are configured.

### Prerequisites and placeholders

Install AWS CLI v2 and PowerShell 7, then configure an AWS CLI profile whose caller is allowed to manage the named CodeBuild project, its service role and inline policy, and its CloudWatch log group. The commands expect the profile named `default`. Replace `default` in every command below with another configured profile name when needed. There are no other placeholders.

The CodeBuild service role itself is deliberately narrower than the permissions needed by the human or automation identity running this setup. Public GitHub source checkout is performed by CodeBuild and does not require a source-read IAM permission or a GitHub secret.

### Create or update the project

From the repository root, create/update the role, policy, and project without starting a build:

```powershell
pwsh -File ./aws/codebuild-setup.ps1 -Profile default -SkipBuild
```

The script stops before changing resources if credentials for the profile are unavailable. It safely creates the role only when absent, updates its trust policy and project-scoped inline logging policy, and then creates or updates the project. If an existing role has any unrelated inline or managed policies, the script stops rather than deleting permissions that might belong to another workload; review that role manually before rerunning.

Verify the resulting project configuration:

```powershell
aws --profile default --region ap-south-1 codebuild batch-get-projects --names calculator-kubernetes-demo-build --query "projects[0].{Name:name,Source:source.location,Branch:sourceVersion,Image:environment.image,Compute:environment.computeType,Privileged:environment.privilegedMode,Artifacts:artifacts.type,Role:serviceRole}" --output table
```

### Start and observe a build

Start a build and retain its ID in PowerShell:

```powershell
$BuildId = aws --profile default --region ap-south-1 codebuild start-build --project-name calculator-kubernetes-demo-build --query "build.id" --output text
```

Check its current status and phase:

```powershell
aws --profile default --region ap-south-1 codebuild batch-get-builds --ids $BuildId --query "builds[0].{Status:buildStatus,Phase:currentPhase,Started:startTime,Ended:endTime}" --output table
```

Follow CloudWatch output (press Ctrl+C to stop following):

```powershell
aws --profile default --region ap-south-1 logs tail "/aws/codebuild/calculator-kubernetes-demo-build" --follow
```

Alternatively, omit `-SkipBuild` to provision the project and start a build in one rerunnable command:

```powershell
pwsh -File ./aws/codebuild-setup.ps1 -Profile default
```

### Clean up after the demo

Wait for any build to finish, then remove the project, its CloudWatch log group, inline policy, and dedicated service role:

```powershell
pwsh -File ./aws/codebuild-setup.ps1 -Profile default -Cleanup
```

## Phase 4 - Docker Hub

A Docker Hub account is required to publish the image. Create a Docker Hub repository named exactly `calculator-kubernetes-demo`; a public repository is preferred for this demo so Kubernetes can later pull the image without registry credentials.

Build the local image as described in Phase 2, then authenticate interactively:

```bash
docker login
```

Tag and push the image, replacing `<DOCKERHUB_USERNAME>` with your Docker Hub username:

```bash
docker tag calculator-kubernetes-demo:latest <DOCKERHUB_USERNAME>/calculator-kubernetes-demo:latest
docker push <DOCKERHUB_USERNAME>/calculator-kubernetes-demo:latest
```

Confirm that the published image can be retrieved:

```bash
docker pull <DOCKERHUB_USERNAME>/calculator-kubernetes-demo:latest
```

The Docker Hub image naming convention is `<DOCKERHUB_USERNAME>/calculator-kubernetes-demo:latest`. Never place a Docker Hub password, access token, or other credential in this repository or in a committed command or credential file. `docker login` must obtain credentials outside version control.

## Phase 5 - Kubernetes / Killercoda

Before the demonstration, replace `<DOCKERHUB_USERNAME>` in `kubernetes/deployment.yaml` with the username for the public Docker Hub image. Then, from the repository root in a Killercoda Kubernetes environment, create the Deployment and Service:

```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
```

Check the created resources:

```bash
kubectl get deployments
kubectl get pods
kubectl get services
```

Inspect the Deployment and NodePort Service in detail:

```bash
kubectl describe deployment calculator-deployment
kubectl describe service calculator-service
```

Delete the demo resources when finished:

```bash
kubectl delete -f kubernetes/service.yaml
kubectl delete -f kubernetes/deployment.yaml
```
