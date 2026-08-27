# calculator-kubernetes-demo

## Project purpose

This project demonstrates a complete beginner-friendly application and DevOps workflow, beginning with a browser-based calculator and eventually progressing through containerization and local Kubernetes deployment. Development is intentionally completed one phase at a time.

## Current phase

**Phase 1 — Calculator Web Application**

The current phase contains only the calculator frontend. Docker, Kubernetes, Minikube, cloud resources, CI/CD, and other deployment configuration are intentionally not included yet.

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

## Calculator controls

Use the on-screen keypad, or use number keys and the `+`, `-`, `*`, and `/` keys. Press `Enter` or `=` to calculate, `Backspace` to delete the last digit, and `Escape` to clear the calculator.

The calculator evaluates operations without `eval()`, displays the active expression, supports decimal input, and shows a clear error instead of producing an invalid value when dividing by zero.
