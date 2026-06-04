# --- Nginx Exporter ---

resource "kubernetes_deployment" "nginx_exporter" {
  metadata {
    name = "nginx-exporter"
    labels = {
      app = "nginx-exporter"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-exporter"
        }
      }

      spec {
        container {
          name  = "nginx-exporter"
          image = "nginx/nginx-prometheus-exporter:1.3.0"
          args  = ["-nginx.scrape-uri=http://frontend-service:80/nginx_status"]

          port {
            container_port = 9113
            name           = "metrics"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_exporter" {
  metadata {
    name = "nginx-exporter"
  }

  spec {
    selector = {
      app = "nginx-exporter"
    }

    port {
      port        = 9113
      target_port = 9113
    }

    type = "ClusterIP"
  }
}

# --- MySQL Exporter ---

resource "kubernetes_deployment" "mysql_exporter" {
  metadata {
    name = "mysql-exporter"
    labels = {
      app = "mysql-exporter"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql-exporter"
        }
      }

      spec {
        container {
          name  = "mysql-exporter"
          image = "prom/mysqld-exporter:v0.15.1"
          args  = ["--mysqld.address=mysql-service:3306"]

          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-user"
              }
            }
          }

          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-password"
              }
            }
          }

          env {
            name  = "DATA_SOURCE_NAME"
            value = "$(MYSQL_USER):$(MYSQL_PASSWORD)@(mysql-service:3306)/"
          }

          port {
            container_port = 9104
            name           = "metrics"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mysql_exporter" {
  metadata {
    name = "mysql-exporter"
  }

  spec {
    selector = {
      app = "mysql-exporter"
    }

    port {
      port        = 9104
      target_port = 9104
    }

    type = "ClusterIP"
  }
}

# --- Prometheus ---

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name = "prometheus"
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
        container {
          name  = "prometheus"
          image = "ichameau/kamka-prometheus:latest"

          port {
            container_port = 9090
            name           = "web"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name = "prometheus"
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
    }

    type = "ClusterIP"
  }
}

# --- Grafana ---

resource "kubernetes_deployment" "grafana" {
  metadata {
    name = "grafana"
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          name  = "grafana"
          image = "ichameau/kamka-grafana:latest"

          env {
            name = "GF_SECURITY_ADMIN_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_secrets.metadata[0].name
                key  = "admin-user"
              }
            }
          }

          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_secrets.metadata[0].name
                key  = "admin-password"
              }
            }
          }

          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "false"
          }

          env {
            name  = "GF_SECURITY_ALLOW_EMBEDDING"
            value = "true"
          }

          port {
            container_port = 3000
            name           = "web"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.grafana_secrets]
}

resource "kubernetes_service" "grafana" {
  metadata {
    name = "grafana"
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3001
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}
