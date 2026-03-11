# 🌐 01-Networking: Traffic Control

This directory manages how external users access services inside the Kubernetes cluster. The networking stack uses **Cilium CNI**, **MetalLB**, and **Traefik** as the ingress controller.

## 📄 Components

### 1. `traefik-ingressroute.yaml`
Traefik's Custom Resource: **`IngressRoute`**. These are more powerful than standard Kubernetes `Ingress` objects because they support TCP, Middleware, and Weighted Routing natively.

**Example Logic:**
```yaml
match: Host(`airflow.3.228.1.250.sslip.io`)
services:
  - name: airflow-web
    port: 8080
```
This tells Traefik: "If a request comes for `airflow...`, send it to the `airflow-web` service on port 8080".

### 2. `traefik-transport.yaml`
Defines `ServersTransport` resources for configuring TLS settings and transport options between Traefik and backend services.

### 3. `values-traefik.yaml`
Helm values file for the Traefik chart. Configures Traefik to run as a `type: LoadBalancer` service (no `hostNetwork`), pinned to the control-plane node.

### 4. `metallb-config.yaml`
MetalLB `IPAddressPool` and `L2Advertisement` configuration. Assigns a dedicated Elastic IP to the Traefik LoadBalancer service.

### 5. `hubble-ui-ingressroute.yaml`
Exposes the **Cilium Hubble UI** via an IngressRoute for network observability. Hubble provides real-time visibility into pod-to-pod traffic flows and DNS queries.

## 🔗 Networking Architecture
*   **Cilium CNI** handles pod networking with AWS ENI IPAM mode (pods get real VPC IPs).
*   **MetalLB** provides `LoadBalancer` service support on bare-metal/self-managed clusters.
*   **Traefik** receives traffic via the MetalLB-assigned IP and routes it to internal services.
