FROM grafana/grafana:13.0.2

# Copy dashboard provisioning configuration
COPY provisioning /etc/grafana/provisioning

# Copy dashboards JSON definitions
COPY dashboards /var/lib/grafana/dashboards
