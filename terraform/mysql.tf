resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name = "mysql-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
  timeouts {
    create = "15m"
  }
  wait_until_bound = false
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name = "mysql-service"
    labels = {
      app = "mysql-service"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql-service"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "mysql-service"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "ichameau/fullstack-mysql:latest"

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-root-password"
              }
            }
          }

          env {
            name = "MYSQL_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_secrets.metadata[0].name
                key  = "mysql-database"
              }
            }
          }

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

          port {
            container_port = 3306
            name           = "mysql"
          }

          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }

          liveness_probe {
            exec {
              command = ["mysqladmin", "ping", "-h", "localhost"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
          }

          readiness_probe {
            exec {
              command = ["mysqladmin", "ping", "-h", "localhost"]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }

        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql_pvc.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.db_secrets]
}

resource "kubernetes_service" "mysql" {
  metadata {
    name = "mysql-service"
  }

  spec {
    selector = {
      app = "mysql-service"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}
