#!/bin/sh

set -x

###############################
### SCRIPT CONFIG VARIABLES ###
###############################

DB_NAME=$(pwgen -c -n -1)
ROOT_PASS=$(pwgen -c -n -1 16)
BACKUP_PASS=$(pwgen -c -n -1 16)
SECRET_DIR='/conf/.creds'
DB_FILE="${SECRET_DIR}/dbdata.yaml"
LOGFILE='/var/log/mariadb-setup.log'

##############################
### MYSQL CONFIG VARIABLES ###
##############################

DATADIR='/var/lib/mysql'
MYSQL_LOGDIR='/var/log/mariadb'
MYSQL_LOGFILE="${MYSQL_LOGDIR}/mariadb.log"
MYSQL_ERR_LOGFILE="${MYSQL_LOGDIR}/mariadb-error.log"
MYSQL_SLO_LOGFILE="${MYSQL_LOGDIR}/mariadb-slow.log"

### FUNCTIONS ###

f_err() {
  echo "$(date '+%Y-%m-%dT%H:%M') - ERROR: $1" | tee $LOGFILE
  exit 1
}

f_warn() {
  echo "$(date '+%Y-%m-%dT%H:%M') - $1" | tee $LOGFILE
}

### LOGFILE AND TESTS ###

if [[ ! -f $LOGFILE ]] ; then
  touch $LOGFILE || f_warn "Unable to open ${LOGFILE}"
  echo "$(date '+%Y-%m-%dT%H:%M') - Logfile opened" >> $LOGFILE
fi

if [[ -z $ROOT_PASS ]] ; then
  f_err "No root user password was generated - is pwgen installed?"
fi

if [[ -z $BACKUP_PASS ]] ; then
  f_err "No backup password was generated - is pwgen installed?"
fi

if [[ ! -d '/conf' ]] ; then
  f_err "There are no volumes mounted from the data container"
fi

if [[ -f $DB_FILE ]] ; then
  f_warn "A ${DB_FILE} already exists"
fi

if [ -f "${DATADIR}/ibdata1" ] ; then
  f_warn "${DATADIR}/ibdata1 file exists"
fi

#################################
### DBDATA.YAML FILE CREATION ###
#################################

if [[ ! -d $SECRET_DIR ]] ; then
  f_warn "$SECRET_DIR did not exist; creating"
  mkdir -p $SECRET_DIR
fi

if [[ ! -f $DB_FILE ]] ; then
cat << EOF > $DB_FILE
---
  name: $DB_NAME
  mysql: $ROOT_PASS 
  backup: $BACKUP_PASS
EOF
else
  f_warn "A ${DB_FILE} already exists"
fi

chmod 600 $DB_FILE || f_warn "Unable to chown ${DB_FILE}"

##############################
### MYSQL SETUP BELOW HERE ###
##############################

mkdir -p $MYSQL_LOGDIR || f_err "Unable to create log directory"

for file in $MYSQL_ERR_LOGFILE $MYSQL_SLO_LOGFILE $MYSQL_LOGFILE ; do
  touch $file | tee $LOGFILE || f_err "Unable to create ${file}"
  chown mysql:mysql $file || f_err "Unable to chown ${file} to mysql.mysql"
  chmod 0640 $file || f_err "Unable to chmod ${file} to 0640"
done

/usr/bin/mysql_install_db --datadir=${DATADIR} --user=mysql | tee $MYSQL_LOGFILE

chown -R mysql:mysql "${DATADIR}" 
chmod 0755 "${DATADIR}"

/usr/bin/mysqld_safe |tee $MYSQL_LOGFILE &

sleep 5s && \

mysql -u root -e "CREATE DATABASE ${DB_NAME};" \
        || f_err "Unable to create database"
mysql -u root -e "GRANT ALL PRIVILEGES on *.* to 'backup'@'%' IDENTIFIED BY \"${BACKUP_PASS}\";" \
        || f_err "Unable to setup backup user"
mysql -u root -e "GRANT ALL PRIVILEGES on ${DB_NAME}.* to 'root'@'%' IDENTIFIED BY \"${ROOT_PASS}\";" \
        || f_err "Unable to setup root user"
# MAKE SURE THIS ONE IS LAST, OR WE'LL HAVE TO PASS THE ROOT PW EVERY TIME
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD(\"${ROOT_PASS}\") WHERE User='root'; FLUSH PRIVILEGES" \
        || f_err "Unable to set root user password"

mysqladmin -uroot -p${ROOT_PASS} shutdown | tee $MYSQL_LOGFILE
