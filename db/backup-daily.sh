#!/bin/sh

### Daily Database Backup Script ###

DAY=$(date +"%A")

DB_USER="root"
DB="${1:-moodle}"
FILE=${2:-$DB}
DIR="/home/backup/dumps/${FILE}-${DAY}.sql"

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Initiating monthly backup of [${DB}] to: [${DIR}]"
/usr/bin/mysqldump -u ${DB_USER} ${DB} > ${DIR}
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Backup complete"
