FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ARG CRON_SYNTAX="0 * * * * root /usr/local/bin/backup-mongo.sh >> /var/log/cron.log 2>&1"

# Install dependencies, MongoDB tools, and mongosh
RUN apt-get update && \
    apt-get install -y cron wget gnupg curl ca-certificates && \
    mkdir -p /usr/share/keyrings && \
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --batch --dearmor -o /usr/share/keyrings/mongodb-server.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y mongodb-database-tools mongodb-mongosh sshpass openssh-client && \
    rm -rf /var/lib/apt/lists/*

# Copy backup script into container
COPY backup-mongo.sh /usr/local/bin/backup-mongo.sh
RUN chmod +x /usr/local/bin/backup-mongo.sh

# Set up cron job
RUN echo "${CRON_SYNTAX}" > /etc/cron.d/mongo-backup && \
    chmod 0644 /etc/cron.d/mongo-backup && \
    crontab /etc/cron.d/mongo-backup

# Start cron, wait with countdown, run backup, and tail log
CMD ["bash", "-c", "\
  printenv > /env.list && \
  cron && \
  echo '==== Waiting 30 seconds before initial backup ====' && \
  for i in 30 25 20 15 10 5; do \
    echo \"... $i seconds remaining\"; \
    sleep 5; \
  done && \
  echo '==== Running initial backup ====' && \
  sh /usr/local/bin/backup-mongo.sh && \
  echo '==== Tailing /var/log/cron.log ====' && \
  touch /var/log/cron.log && \
  tail -f /var/log/cron.log"]
