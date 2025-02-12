# Spring Boot on Kubernetes (2-Replica Version)

This repository demonstrates how to deploy a Spring Boot application to Kubernetes using:

1. **Deployment** (with 2 replicas)  
2. **Service**  
3. **Ingress**  
4. **ConfigMap** (mounted as a **Volume**)  
5. **Secret**  
6. **Prometheus** (for basic metrics scraping)

> **Note**: These examples assume:
> - You already have a Kubernetes cluster.
> - You have a configured Ingress controller (e.g., NGINX Ingress).

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Diagram](#diagram)
  - [Detailed Flow](#detailed-flow)
- [Kubernetes Manifests](#kubernetes-manifests)
- [How to Deploy](#how-to-deploy)
  - [1. Create the Namespace](#1-create-the-namespace)
  - [2. Apply the Resources](#2-apply-the-resources)
  - [3. Verify Everything Is Running](#3-verify-everything-is-running)
- [Testing the Application](#testing-the-application)
- [Notes on Configuration](#notes-on-configuration)
- [Prometheus Integration](#prometheus-integration-optional)
  - [1. Prometheus Configuration](#1-prometheus-configuration)
  - [2. Prometheus Deployment & Service](#2-prometheus-deployment--service)
- [Cleanup](#cleanup)
- [Future Enhancements](#future-enhancements)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project packages a Spring Boot application (`tarundhiman/spring-app:v1`) into a container and runs it in a Kubernetes cluster. The application:

- Listens on port **8080**.
- Loads its configuration (`application.properties`) from a **ConfigMap** rather than from the container’s filesystem.
- Uses a **Secret** to store database credentials (`DB_USERNAME`, `DB_PASSWORD`).
- Is exposed internally via a **Service** of type `ClusterIP` and externally via an **Ingress**.
- Uses **2 replicas** in the Deployment to ensure higher availability or handle more concurrent requests.


## Architecture

### Diagram

A simplified diagram of how traffic flows from the end user into the cluster and how the Pods receive their configuration:

![image](https://github.com/user-attachments/assets/f3f0c111-4b59-4f5d-8213-eb9af7d6e949)


## Detailed Flow

1. **Traffic Ingress**  
   - A request to `spring-app.example.com/` comes in.  
   - The Ingress resource (with `host: spring-app.example.com`) handles this request.

2. **Service Routing**  
   - The Ingress forwards traffic to **spring-app-service** on port **80**.  
   - The Service (type `ClusterIP`) distributes traffic **round-robin** among **both** Pods on port **8080**.

3. **Pod / Container Startup**  
   - The Pods are defined by the **Deployment**.  
   - Each Pod pulls the container image `tarundhiman/spring-app:v1` from the Docker registry.  
   - The containers include a startup argument (`--spring.config.location=file:/config/application.properties`) telling Spring Boot to read configuration from `/config/application.properties`.

4. **Configuration Loading**  
   - The Pod definition mounts a **configMap** volume (named `config-volume`) at `/config/application.properties`.  
   - This volume is sourced from the **spring-app-config** ConfigMap (which holds `application.properties`).  
   - Therefore, each Spring application instance sees those properties as if they were local.
   - Database credentials are stored in a **Secret** (`spring-app-secret`) and injected as environment variables.

5. **Response**  
   - One of the Pods processes the request and returns a response.  
   - The response travels back through the Service, the Ingress, and out to the end user’s browser.

---

## Kubernetes Manifests

Below are the primary files in this setup:

1. **Namespace** (`namespace.yaml`)  
2. **Deployment** (`deployment.yaml`)  
3. **Service** (`service.yaml`)  
4. **Ingress** (`ingress.yaml`)  
5. **ConfigMap** (`configmap.yaml`)  
6. **Secret** (`secret.yaml`)  
7. *(Optional)* **Prometheus** config and resources


### Example: Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tarun-spring-app
```

### Example: Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app
  namespace: tarun-spring-app
  labels:
    app: spring-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      name: spring-app
      labels:
        app: spring-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      containers:
        - name: spring-app
          image: tarundhiman/spring-app:v3
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080

          volumeMounts:
            - name: config-volume
              mountPath: /config/application.properties
              subPath: application.properties

          env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: spring-app-secret
                  key: username

            - name: DB_PASSWORD
              valueFrom:
                  secretKeyRef:
                    name: spring-app-secret
                    key: password

          args:
            - "--spring.config.location=file:/config/application.properties"

      volumes:
        - name: config-volume
          configMap:
            name: spring-app-config
      restartPolicy: Always
```
### Example: Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
  namespace: tarun-spring-app
spec:
  type: ClusterIP
  selector:
    app: spring-app
  ports:
    - port: 80
      targetPort: 8080
```
### Example: Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: spring-app-ingress
  namespace: tarun-spring-app
spec:
  ingressClassName: nginx
  rules:
    - host: spring-app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: spring-app-service
                port:
                  number: 80
          - path: /prometheus
            pathType: Prefix
            backend:
              service:
                name: prometheus-service
                port:
                  number: 90

```
### Example: ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spring-app-config
  namespace: tarun-spring-app
data:
  application.properties: |
    spring.application.name=spring-app
    spring.datasource.url=jdbc:h2:mem:todo-db
    spring.datasource.driverClassName=org.h2.Driver
    spring.datasource.username=${DB_USERNAME:defaultUser}
    spring.datasource.password=${DB_PASSWORD:defaultPass}
    spring.jpa.hibernate.ddl-auto=update
    spring.h2.console.enabled=true
    spring.h2.console.path=/h2-console
    spring.h2.console.settings.web-allow-others=true
    management.endpoints.web.exposure.include=prometheus
    management.endpoint.health.show-details=always
```
### Example: Secret 
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: spring-app-secret
  namespace: tarun-spring-app
type: kubernetes.io/basic-auth
stringData:
  username: "BASE64EncodedUsername"
  password: "BASE64EncodedPassword"
```
## Secrets Management
Store sensitive information—like database credentials or API keys—in Kubernetes Secrets, not in plain text or ConfigMaps. This ensures credentials remain obfuscated in the cluster and reduces the risk of accidental disclosure.

## How to Deploy

### 1. Create the Namespace

```bash
kubectl apply -f tarun-spring-app.yaml
```

### 2. Apply the Resources
Apply the ConfigMap, Deployment, Service, and Ingress. For example:

```bash
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f secret.yaml
```
### 3. Verify Everything Is Running

```bash
kubectl get all -n tarun-spring-app
```
You should see:
1.**Pods** (2 replicas, e.g., spring-app-xxxxxx-1, spring-app-xxxxxx-2)
2.**Deployment** (spring-app)
3.**Service** (spring-app-service)
4.**Ingress** (spring-app-ingress)

```bash
kubectl logs -n tarun-spring-app -l app=spring-app
```

## Prometheus Integration
To monitor key metrics—like request counts, latencies, or custom metrics from your Spring Boot application—follow these steps.

1 .**Prometheus Configuration**
Your Spring Boot app should expose metrics at /actuator/prometheus (default if Spring Actuator is on the classpath and enabled).
Create a ConfigMap specifying how Prometheus scrapes pods labeled app: spring-app. For example:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: tarun-spring-app
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'spring-app'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: spring-app
        metrics_path: /actuator/prometheus
        scheme: http

```
2 .**Prometheus Deployment & Service**
Deploy Prometheus, mounting the above config:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: tarun-spring-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.22.0
        args:
          - "--config.file=/etc/prometheus/prometheus.yml"
        ports:
          - containerPort: 9090
        volumeMounts:
          - name: prometheus-config-volume
            mountPath: /etc/prometheus
      volumes:
        - name: prometheus-config-volume
          configMap:
            name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: tarun-spring-app
spec:
  type: ClusterIP
  selector:
    app: prometheus
  ports:
    - name: http
      port: 90
      targetPort: 9090
```

### Testing the Application
1. **DNS / Hosts File**
Ensure spring-app.example.com resolves to your Ingress controller’s IP (e.g., by configuring DNS or /etc/hosts if testing locally via minikube).

2. **Access the App**
Open a browser to http://spring-app.example.com/
You should see the Spring application’s default page or any endpoints you’ve defined.

3. **Verify ConfigMap is Loaded**
Check the app logs for references to sat or other properties from application.properties.

4. **Verify Load Balancing**
Since there are 2 replicas, requests should be distributed between both Pods. You can see this by repeatedly hitting the endpoint and checking the logs or the Pod IP from which the response is served.

### Notes on Configuration
**Externalized Configuration**
By specifying args: --spring.config.location=file:/config/application.properties, you instruct Spring Boot to load from the ConfigMap-mounted volume.

**Scaling**
Currently set to 2 replicas in the Deployment. To scale up (e.g., 3 replicas):

```bash
kubectl scale deployment spring-app --replicas=3 -n tarun-spring-app
```

**ContainerPort vs Service Port**
The container listens on 8080, while the Service is bound to 80 internally. The Ingress routes traffic from 80 (or 443 for HTTPS) to the Service’s port 80, which in turn routes to 8080 in your container.

**Multiple Environments**
For staging or production, you can maintain separate ConfigMaps with environment-specific properties (e.g., spring-app-config-staging, spring-app-config-prod) and mount them as needed.

### Cleanup
To remove all resources, run:

```bash
kubectl delete -f singress.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f configmap.yaml
kubectl delete -f secret.yaml
kubectl delete -f prometheus-deployment.yaml
kubectl delete -f prometheus-service.yaml
kubectl delete -f prometheus-config.yaml
kubectl delete namespace tarun-spring-app
```
This ensures the namespace and all resources within it are deleted.

## Future Enhancements

Below are some potential enhancements and next steps for this project:

1. **Autoscaling (HPA)**
   - Implement a Horizontal Pod Autoscaler (HPA) based on CPU or custom metrics to automatically scale the number of replicas under load.
   - Configure resource requests and limits in the Deployment to facilitate more accurate scaling decisions.

2. **CI/CD Integration**
   - Integrate a CI/CD pipeline (e.g., GitHub Actions, GitLab CI, or Jenkins) to automatically build and test your Spring Boot application, then deploy updates to Kubernetes when new changes are merged.

3. **TLS/HTTPS**
   - Enhance security by setting up TLS termination at the Ingress level (e.g., using cert-manager to provision and renew Let’s Encrypt certificates).

4. **Observability & Monitoring**
   - Add monitoring with Grafana for metrics (CPU usage, memory, custom Spring Boot metrics).
   - Enable distributed tracing using tools like Jaeger or Zipkin to better understand request flow and performance bottlenecks.

5. **Centralized Logging**
   - Integrate ELK (Elasticsearch, Logstash, Kibana) or EFK (Elasticsearch, Fluentd, Kibana) stack to collect and analyze logs from all pods in one place.

6. **Blue-Green / Canary Deployments**
   - Explore advanced deployment strategies like blue-green or canary deployments using tools such as Argo Rollouts to reduce downtime and risk during application updates.

7. **Multi-Environment Management**
   - Create separate overlays or parameterized manifests (e.g., using Helm or Kustomize) for staging, QA, and production environments.

8. **Testing Tools**
   - Add integration tests or end-to-end tests (e.g., using Cypress or Postman) that can run automatically after deployment to confirm functionality.

9. **GitOps Workflow**
    - Manage your Kubernetes manifests with a GitOps tool (e.g., Argo CD or Flux) to achieve a fully declarative and automated deployment process.

---
### Contributing
Contributions are welcome! Feel free to submit pull requests with improvements or open issues for any bug reports or feature requests.

### License
This project is licensed under the MIT License.
You’re free to use, modify, and distribute the code under its terms.
