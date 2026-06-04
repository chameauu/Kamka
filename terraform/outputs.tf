output "frontend_public_ip" {
  description = "Public IP address of the Nginx frontend"
  value       = kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].ip
}

output "grafana_public_ip" {
  description = "Public IP address of the Grafana dashboard (port 3001)"
  value       = kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].ip
}
