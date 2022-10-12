#!/bin/sh

### Restore Database Script ###

if (( $# != 2 ))
  then
      echo "Usage: $0 databasename dump.sql"
      exit 1
fi

DB_USER="root"
DB=${1}
FILE=${2}

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Initiating restore of [${DB}] from: [${FILE}]"
mysql -u root -p -e "DROP DATABASE IF EXISTS ${DB}; CREATE DATABASE IF NOT EXISTS ${DB}; USE ${DB}; SOURCE ${FILE};"
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Restore complete"
