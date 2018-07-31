#!/bin/sh

### Monthly Database Backup Script ###

MONTH=$(date +"%m")
YEAR=$(date +"%Y")

DB_USER="root"
DB="${1:-moodle}"
FILE=${2:-$DB}
DIR="/home/backup/dumps/${FILE}-${YEAR}-${MONTH}.sql"

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Initiating monthly backup of [${DB}] to: [${DIR}]"
/usr/bin/mysqldump -u ${DB_USER} ${DB} > ${DIR}
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Backup complete"
