resource "kubernetes_secret" "spring_app_secret" {
  metadata {
    name      = "spring-app-secret"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }
  data = {
    username = base64decode("c2F0")
    password = base64decode("cGFzc3dvcmQ=")
  }
  type = "kubernetes.io/basic-auth"
}
