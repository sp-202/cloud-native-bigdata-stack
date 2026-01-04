# 🌐 01-Networking: Traffic Control

This directory manages how external users access services inside the private Kubernetes cluster. We use **Traefik** as our Ingress Controller.

## 📄 Components

### 1. `ingress-routes.yaml`
We use Traefik's Custom Resource: **`IngressRoute`**.
These are more powerful than standard Kubernetes `Ingress` objects because they support TCP, Middleware, and Weighted Routing natively.

**Example Logic:**
```yaml
match: Host(`airflow.sslip.io`)
services:
  - name: airflow-web
    port: 8080
```
This tells Traefik: "If a request comes for `airflow...`, send it to the `airflow-web` service on port 8080".

### 2. `middlewares.yaml`
Middlewares process the request *before* it reaches the app.
*   **`strip-prefix`**: Common pattern. If you access `domain.com/airflow`, the app expects `/`. This middleware strips the `/airflow` from the path so the app doesn't break.
*   **`auth`**: (Optional) Can add Basic Auth to unsecured services.

### 3. `traefik-config.yaml`
Global configurations for the Traefik pods themselves (e.g., enabling the Dashboard, setting log levels).
