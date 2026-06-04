resource "kubernetes_deployment" "backend" {
  metadata {
    name = "backend-service"
    labels = {
      app = "backend-service"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend-service"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "ichameau/fullstack-backend:latest"

          env {
            name  = "DB_HOST"
            value = "mysql-service"
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-user"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-password"
              }
            }
          }

          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-database"
              }
            }
          }

          port {
            container_port = 3000
            name           = "http"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.mysql]
}

resource "kubernetes_service" "backend" {
  metadata {
    name = "backend-service"
  }

  spec {
    selector = {
      app = "backend-service"
    }

    port {
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}
