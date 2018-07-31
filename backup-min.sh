#!/bin/sh

### Minimal Database Backup Script - Excluding the data from large tables ###
DB_USER="dbuser"
DB="${1:-moodle}"
FILE=${2:-$DB}
DIR="/home/backup/dumps"
EXCLUDED=(
mdl_log
mdl_logstore_standard_log
mdl_stats_daily
mdl_stats_monthly
mdl_stats_weekly
mdl_stats_user_daily
mdl_stats_user_monthly
mdl_stats_user_weekly
)

IGNORE=''
for TABLE in "${EXCLUDED[@]}"
do :
   IGNORE+=" --ignore-table=${DB}.${TABLE}"
done

# Structure of all tables
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Dumping database structure of [${DB}] to: [${DIR}/structure.min.sql]"
/usr/bin/mysqldump -u ${DB_USER} --no-data ${DB} > ${DIR}/structure.min.sql

# Data of tables excepto excluded ones
echo "[`date "+%d-%m-%Y %H:%M:%S"`] Dumping database data of [${DB}] to: [${DIR}/data.min.sql]"
/usr/bin/mysqldump -u ${DB_USER} ${DB} --no-create-info ${IGNORE} > ${DIR}/data.min.sql

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Concatenating dump files together into: [${DIR}/${FILE}.sql]"
cat ${DIR}/structure.min.sql ${DIR}/data.min.sql > ${DIR}/${FILE}.sql

echo "[`date "+%d-%m-%Y %H:%M:%S"`] Backup complete"
