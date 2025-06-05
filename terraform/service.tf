resource "kubernetes_service" "spring_app_service" {
  metadata {
    name      = "spring-app-service"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }

  spec {
    selector = {
      app = "spring-app"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
