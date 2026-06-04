resource "kubernetes_deployment" "frontend" {
  metadata {
    name = "frontend-service"
    labels = {
      app = "frontend-service"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend-service"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "ichameau/fullstack-frontend:latest"

          port {
            container_port = 80
            name           = "http"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.backend]
}

resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend-service"
  }

  spec {
    selector = {
      app = "frontend-service"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
