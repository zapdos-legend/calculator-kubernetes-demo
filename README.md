# calculator-kubernetes-demo

## Project purpose

This project demonstrates a complete beginner-friendly application and DevOps workflow, beginning with a browser-based calculator and eventually progressing through containerization and local Kubernetes deployment. Development is intentionally completed one phase at a time.

## Current phase

**Phase 2 — Docker Containerization**

The calculator frontend is packaged in a simple Nginx-based Docker image for local use. Kubernetes, Minikube, cloud resources, CI/CD, and other deployment configuration are intentionally not included yet.

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

- AWS CodeBuild will build the Docker image remotely.
- Docker Desktop is not required locally.
- The Docker Hub push will be handled in the next phase.
