#!/bin/bash

# Load environment variables from /env.list
if [ -f /env.list ]; then
  while IFS='=' read -r key value; do
    # Skip empty lines or comments
    [ -z "$key" ] || [ "${key#\#}" != "$key" ] && continue
    export "$key=$value"
  done < /env.list
fi

# SFTP credentials (use env vars for security)
SFTP_HOST=${SFTP_HOST:-sftp.example.com}
SFTP_PORT=${SFTP_PORT:-22}
SFTP_USER=${SFTP_USER:-sftpuser}
SFTP_PASS=${SFTP_PASS:-sftppassword}
SFTP_TARGET_DIR=${SFTP_TARGET_DIR:-/backups}

# Mongo credentials
MONGO_HOST=${MONGO_HOST:-mongodb}
MONGO_USER=${MONGO_USER:-devuser}
MONGO_PASS=${MONGO_PASS:-devpass}

DATE=$(date +"%Y-%m-%d_%H:%M")
BACKUP_DIR="/backup/$DATE"
ARCHIVE_NAME="${MONGO_HOST}_full_${DATE}.tar.gz"
ARCHIVE_PATH="/backup/$ARCHIVE_NAME"

# Wait for MongoDB to become ready (up to 60s)
echo "Waiting for MongoDB to become available..."
for i in $(seq 1 30); do
  # Try to ping MongoDB, capture output and exit code
  ERROR_OUTPUT=$(mongosh --host=mongodb --username=databaseuser --password=databasepassword --authenticationDatabase=admin --eval "db.adminCommand('ping')" 2>&1)
  STATUS=$?

  if [ "$STATUS" -eq 0 ]; then
    echo "MongoDB is ready."
    break
  else
    echo "Attempt $i: MongoDB not available yet, retrying in 2s..."
    echo "Error output: $ERROR_OUTPUT"
  fi

  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "MongoDB did not become available after 60s. Exiting."
    exit 1
  fi
done

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Run mongodump
mongodump --host=$MONGO_HOST \
  --username=$MONGO_USER \
  --password=$MONGO_PASS \
  --authenticationDatabase=admin \
  --out="$BACKUP_DIR"

# Compress the backup
tar -czf "$ARCHIVE_PATH" -C /backup "$(basename "$BACKUP_DIR")"

# Remove uncompressed directory
rm -rf "$BACKUP_DIR"

# Upload via SFTP
echo "Uploading $ARCHIVE_NAME to SFTP..."
sshpass -p "$SFTP_PASS" sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" <<EOF
mkdir $SFTP_TARGET_DIR
cd $SFTP_TARGET_DIR
put $ARCHIVE_PATH
bye
EOF

echo "Backup and SFTP upload complete."

# Retain only the latest 72 backup files (by date)
echo "Cleaning up old backups, keeping only the 72 most recent..."
ls -tp /backup/$MONGO_HOST_full_*.tar.gz | grep -v '/$' | tail -n +73 | xargs -r rm --

echo "Cleanup complete."
