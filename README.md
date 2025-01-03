# Spring Boot on Kubernetes (2-Replica Version)

This repository demonstrates how to deploy a Spring Boot application to Kubernetes using:

1. **Deployment** (with 2 replicas)  
2. **Service**  
3. **Ingress**  
4. **ConfigMap** (mounted as a **Volume**)

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
- [Cleanup](#cleanup)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project packages a Spring Boot application (`tarundhiman/spring-app:v1`) into a container and runs it in a Kubernetes cluster. The application:

- Listens on port **8080**.
- Loads its configuration (`application.properties`) from a **ConfigMap** rather than from the container’s filesystem.  
- Is exposed internally via a **Service** of type `ClusterIP` and externally via an **Ingress**.
- Uses **2 replicas** in the Deployment to ensure higher availability or handle more concurrent requests.

---

## Architecture

### Diagram

A simplified diagram of how traffic flows from the end user into the cluster and how the Pods receive their configuration:

![spring-app-architecture-kubernetes](https://github.com/user-attachments/assets/97be3855-d5a9-4462-9565-56339a7871bb)

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

5. **Response**  
   - One of the Pods processes the request and returns a response.  
   - The response travels back through the Service, the Ingress, and out to the end user’s browser.

---

## Kubernetes Manifests

Below are the primary files in this setup:

1. **Namespace** (`tarun-spring-app.yaml`)  
2. **Deployment** (`spring-app-deployment.yaml`)  
3. **Service** (`spring-app-service.yaml`)  
4. **Ingress** (`spring-app-ingress.yaml`)  
5. **ConfigMap** (`spring-app-configmap.yaml`)  

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
    spec:
      containers:
        - name: spring-app
          image: tarundhiman/spring-app:v1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: config-volume
              mountPath: /config/application.properties
              subPath: application.properties
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
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
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
    spring.datasource.username=sat
    spring.datasource.password=password
    spring.jpa.hibernate.ddl-auto=update
    spring.h2.console.enabled=true
    spring.h2.console.path=/h2-console
    spring.h2.console.settings.web-allow-others=true
```
## How to Deploy

### 1. Create the Namespace

```bash
kubectl apply -f tarun-spring-app.yaml
```

### 2. Apply the Resources
Apply the ConfigMap, Deployment, Service, and Ingress. For example:

```bash
kubectl apply -f spring-app-configmap.yaml
kubectl apply -f spring-app-deployment.yaml
kubectl apply -f spring-app-service.yaml
kubectl apply -f spring-app-ingress.yaml
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
kubectl delete -f spring-app-ingress.yaml
kubectl delete -f spring-app-service.yaml
kubectl delete -f spring-app-deployment.yaml
kubectl delete -f spring-app-configmap.yaml
kubectl delete namespace tarun-spring-app
```
This ensures the namespace and all resources within it are deleted.

### Contributing
Contributions are welcome! Feel free to submit pull requests with improvements or open issues for any bug reports or feature requests.

### License
This project is licensed under the MIT License.
You’re free to use, modify, and distribute the code under its terms.
