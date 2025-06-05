resource "kubernetes_ingress_v1" "spring_app_ingress" {
  metadata {
    name      = "spring-app-ingress"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "spring-app.example.com"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.spring_app_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/prometheus"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.prometheus_service.metadata[0].name
              port {
                number = 90
              }
            }
          }
        }
      }
    }
  }
}
