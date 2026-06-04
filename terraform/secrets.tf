resource "kubernetes_secret" "db_secrets" {
  metadata {
    name = "db-secrets"
  }

  data = {
    mysql-root-password = var.mysql_root_password
    mysql-database      = var.mysql_database
    mysql-user          = var.mysql_user
    mysql-password      = var.mysql_password
  }

  type = "Opaque"
}

resource "kubernetes_secret" "grafana_secrets" {
  metadata {
    name = "grafana-secrets"
  }

  data = {
    admin-user     = var.grafana_admin_user
    admin-password = var.grafana_admin_password
  }

  type = "Opaque"
}
