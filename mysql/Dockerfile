FROM mysql:8.0

# Set environment variables using build arguments
ARG MYSQL_ROOT_PASSWORD=rootpassword
ARG MYSQL_DATABASE=fullstack_db
ARG MYSQL_USER=appuser
ARG MYSQL_PASSWORD=apppassword

ENV MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
    MYSQL_DATABASE=${MYSQL_DATABASE} \
    MYSQL_USER=${MYSQL_USER} \
    MYSQL_PASSWORD=${MYSQL_PASSWORD}


# Copy any initialization scripts
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Expose MySQL port
EXPOSE 3306

# Start MySQL server
CMD ["mysqld", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci"]
