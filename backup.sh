#!/bin/sh

### Database Backup Script ###
if (( $# != 2 ))
  then
      echo "Usage: $0 database user"
      exit 1
fi

DB_USER="root"
DB="${1:-moodle}"
FILE=${2:-$DB}
DIR="/var/www/data/dumps/${FILE}.sql"

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Initiating backup of [${DB}] to: [${DIR}]"
/usr/bin/mysqldump -u ${DB_USER} ${DB} > ${DIR}
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Backup complete"
