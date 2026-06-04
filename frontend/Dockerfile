FROM nginx:1.31.1-alpine

# Install curl for health checks and metrics collection
RUN apk add --no-cache curl bash

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
