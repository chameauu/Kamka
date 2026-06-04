variable "mysql_root_password" {
  type        = string
  description = "Root password for MySQL"
  sensitive   = true
  default     = "rootpassword"
}

variable "mysql_database" {
  type        = string
  description = "Database name for MySQL"
  default     = "fullstack_db"
}

variable "mysql_user" {
  type        = string
  description = "Username for MySQL database connection"
  default     = "appuser"
}

variable "mysql_password" {
  type        = string
  description = "Password for MySQL database connection"
  sensitive   = true
  default     = "apppassword"
}

variable "grafana_admin_user" {
  type        = string
  description = "Grafana admin username"
  default     = "admin"
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
  default     = "adminpassword"
}
