resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus-clusterrole"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "endpoints", "services"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus-clusterrolebinding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = kubernetes_namespace.spring.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<EOT
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'spring-app'
    metrics_path: /actuator/prometheus
    scheme: http
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: spring-app
EOT
  }
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus-deployment"
    namespace = kubernetes_namespace.spring.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.prometheus.metadata[0].name
        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.22.0"
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--web.route-prefix=/prometheus",
            "--web.external-url=http://spring-app.example.com/prometheus"
          ]
          port {
            container_port = 9090
          }
          volume_mount {
            name       = "prometheus-config-volume"
            mount_path = "/etc/prometheus"
          }
        }

        volume {
          name = "prometheus-config-volume"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus_service" {
  metadata {
    name      = "prometheus-service"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      name        = "http"
      port        = 90
      target_port = 9090
    }

    type = "ClusterIP"
  }
}
