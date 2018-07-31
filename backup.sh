#!/bin/sh

### Database Backup Script ###

DB_USER="dbuser"
DB="${1:-moodle}"
FILE=${2:-$DB}
DIR="/home/backup/dumps/$FILE.sql"

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Initiating backup of [${DB}] to: [${DIR}]"
/usr/bin/mysqldump -u ${DB_USER} ${DB} > ${DIR}
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Backup complete"
