resource "kubernetes_deployment" "spring_app" {
  metadata {
    name      = "spring-app"
    namespace = kubernetes_namespace.spring.metadata[0].name
    labels = {
      app = "spring-app"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8080"
      "prometheus.io/path"   = "/actuator/prometheus"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "spring-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "spring-app"
        }
      }

      spec {
        container {
          name  = "spring-app"
          image = "tarundhiman/spring-app:v3"

          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/config/application.properties"
            sub_path   = "application.properties"
          }

          env {
            name = "DB_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.spring_app_secret.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.spring_app_secret.metadata[0].name
                key  = "password"
              }
            }
          }

          args = ["--spring.config.location=file:/config/application.properties"]
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.spring_app_config.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}
