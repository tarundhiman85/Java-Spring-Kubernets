resource "kubernetes_config_map" "spring_app_config" {
  metadata {
    name      = "spring-app-config"
    namespace = kubernetes_namespace.spring.metadata[0].name
  }

  data = {
    "application.properties" = <<EOT
spring.application.name=spring-app
spring.datasource.url=jdbc:h2:mem:todo-db
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=$${DB_USERNAME:defaultUser}
spring.datasource.password=$${DB_PASSWORD:defaultPass}
spring.jpa.hibernate.ddl-auto=update
spring.h2.console.enabled=true
spring.h2.console.path=/h2-console
spring.h2.console.settings.web-allow-others=true
management.endpoints.web.exposure.include=prometheus
management.endpoint.health.show-details=always
EOT
  }
}
