# MongoDB Backup Container

A minimal Docker container that performs scheduled MongoDB backups and uploads them to a remote SFTP server.

This container:
- Connects to a MongoDB instance
- Runs a backup using `mongodump`
- Compresses the output
- Uploads the archive via SFTP
- Runs on a cron schedule
- Retains the latest 72 backup files

---

## 📦 Files

### `Dockerfile`

Defines the container with:
- `mongodb-database-tools` and `mongosh`
- Cron for scheduled execution
- A startup script that waits 30 seconds, runs an initial backup, then tails the cron log

### `backup-mongo.sh`

A bash script that:
- Loads environment variables from `/env.list`
- Waits up to 60s for MongoDB readiness
- Runs `mongodump`
- Compresses and uploads the backup over SFTP
- Keeps only the 72 most recent backups

---

## 🛠 Environment Variables

| Variable           | Default             | Description |
|--------------------|---------------------|-------------|
| `MONGO_HOST`       | `mongodb`           | MongoDB hostname |
| `MONGO_USER`       | `devuser`           | MongoDB username |
| `MONGO_PASS`       | `devpass`           | MongoDB password |
| `SFTP_HOST`        | `sftp.example.com`  | SFTP server hostname |
| `SFTP_PORT`        | `22`                | SFTP port |
| `SFTP_USER`        | `sftpuser`          | SFTP username |
| `SFTP_PASS`        | `sftppassword`      | SFTP password |
| `SFTP_TARGET_DIR`  | `/backups`          | Remote directory for uploads |
| `CRON_SYNTAX`      | `0 * * * * ...`     | (Build-time ARG) Cron syntax for scheduling backups |

---

## 🚀 Usage

### 1. Build the image
```sh
docker build -t mongo-backup .
```

### 2. Run the container
```
docker run -d \
  --name mongo-backup \
  -e MONGO_HOST=your-mongo-host \
  -e MONGO_USER=your-user \
  -e MONGO_PASS=your-password \
  -e SFTP_HOST=sftp.server.com \
  -e SFTP_USER=user \
  -e SFTP_PASS=pass \
  -e SFTP_TARGET_DIR=/remote/path \
  -v /your/host/backup:/backup \
  mongo-backup
```

Ensure that the /backup volume is mapped to a persistent host directory.

### 🧪 Initial Backup and Cron

Upon startup, the container:
- Waits 30 seconds
- Performs an initial backup
- Starts cron to run backups as scheduled

All output is logged to /var/log/cron.log.
🧹 Cleanup

After each backup, the script deletes older backups, retaining the latest 72 backup archives.

### 🔐 Security Notes

- SFTP credentials are passed as environment variables.
- Consider using Docker secrets or volume-mounted .env files in production.