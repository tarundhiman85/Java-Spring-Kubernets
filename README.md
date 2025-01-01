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

## How to Deploy

### 1. Create the Namespace

```bash
kubectl apply -f tarun-spring-app.yaml

