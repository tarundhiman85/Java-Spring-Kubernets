resource "kubernetes_namespace" "spring" {
  metadata {
    name = "tarun-spring-app"
  }
}
