#!/bin/bash
set -euo pipefail
# This script is run every time an instance of our app - aka grain - starts up.
# This is the entry point for your application both when a grain is first launched
# and when a grain resumes after being previously shut down.
#
# This script is responsible for launching everything your app needs to run.  The
# thing it should do *last* is:
#
#   * Start a process in the foreground listening on port 8000 for HTTP requests.
#
# This is how you indicate to the platform that your application is up and
# ready to receive requests.  Often, this will be something like nginx serving
# static files and reverse proxying for some other dynamic backend service.
#
# Other things you probably want to do in this script include:
#
#   * Building folder structures in /var.  /var is the only non-tmpfs folder
#     mounted read-write in the sandbox, and when a grain is first launched, it
#     will start out empty.  It will persist between runs of the same grain, but
#     be unique per app instance.  That is, two instances of the same app have
#     separate instances of /var.
#   * Preparing a database and running migrations.  As your package changes
#     over time and you release updates, you will need to deal with migrating
#     data from previous schema versions to new ones, since users should not have
#     to think about such things.
#   * Launching other daemons your app needs (e.g. mysqld, redis-server, etc.)

# By default, this script does nothing.  You'll have to modify it as
# appropriate for your application.

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "${script_dir}/environment"

wait_for() {
	local service=$1
	local file=$2
	while [ ! -e "$file" ]; do
		echo "waiting for $service to be available at $file."
		sleep 0.1
	done
}

# Open-EMR wants to modify some files.
# Those files will go in /var/openemr-7.0.3/openemr for now.
mkdir --parents ${OPENEMR_VAR_DIR}/openemr/sites/default
if [ ! -f "${OPENEMR_VAR_DIR}/openemr/sites/default/sqlconf.php" ]; then
	cat > "${OPENEMR_VAR_DIR}/openemr/sites/default/sqlconf.php" << EOL
<?php
//  OpenEMR
//  MySQL Config

global \$disable_utf8_flag;
\$disable_utf8_flag = false;

\$host   = 'localhost';
//\$port   = '3306';
\$port   = '0';
\$socket = '/var/run/mysqld/mysqld.sock';
\$login  = 'openemr';
\$pass   = 'openemr';
\$dbase  = 'openemr';
\$db_encoding = 'utf8mb4';

\$sqlconf = array();
global \$sqlconf;
\$sqlconf["host"]= \$host;
\$sqlconf["port"] = \$port;
\$sqlconf["socket"] = \$socket;
\$sqlconf["login"] = \$login;
\$sqlconf["pass"] = \$pass;
\$sqlconf["dbase"] = \$dbase;
\$sqlconf["db_encoding"] = \$db_encoding;

//////////////////////////
//////////////////////////
//////////////////////////
//////DO NOT TOUCH THIS///
\$config = 1; /////////////
//////////////////////////
//////////////////////////
//////////////////////////
EOL
fi
chmod 0666 ${OPENEMR_VAR_DIR}/openemr/sites/default/sqlconf.php

if [ ! -d "${OPENEMR_VAR_DIR}/openemr/sites/default/documents" ]; then
	mkdir --parents ${OPENEMR_VAR_DIR}/openemr/sites/default/documents
	cp --no-preserve=ownership --recursive "${OPENEMR_OPT_DIR}/documents" "${OPENEMR_VAR_DIR}/openemr/sites/default"
fi

mkdir --parents /var/lib/mysql
mkdir --parents /var/lib/php/sessions

# TODO: Rotate logs
mkdir --parents /var/log/apache2

rm -rf /var/run
mkdir --parents /var/run/apache2
mkdir --parents /var/run/mysqld
#mkdir --parents /var/run/php

rm -rf /var/tmp
mkdir --parents /var/tmp

if [ ! -d ${MARIADB_DATA_DIR}/mysql ]; then
	# Create mysql tables in MySQL
	# TODO: Can we remove the --force?
	HOME=${MARIADB_HOME_DIR} /usr/bin/mariadb-install-db --force
fi

# Run MariaDB
HOME=${MARIADB_HOME_DIR} /usr/sbin/mariadbd --skip-grant-tables &
wait_for mariadb /var/run/mysqld/mysqld.sock

# Load data into the database if the Open-EMR database does not exist.
HAS_DATABASE=$(/usr/bin/mysql "--user=${OPENEMR_DATABASE_USER}" "--execute=USE ${OPENEMR_DATABASE}" && echo "YES" || echo "NO")
if [ "${HAS_DATABASE}" = "NO" ]; then
	echo "Open-EMR database not found."
	/usr/bin/mysql --user=root < "${SQL_DIR}/create_database.sql"
	[ $? = 0 ] && echo "Database created."
	/usr/bin/mysql "--user=${OPENEMR_DATABASE_USER}" "${OPENEMR_DATABASE}" < "${SQL_DIR}/initial_data.sql"
	[ $? = 0 ] && echo "Initial data loaded."
fi

# Apache 2 HTTP server wants our user to have a username.
# Create temporary passwd and group databases.
EGID=$(getegid)

PASSWD_FILE=$(mktemp)
echo "${OPENEMR_USER}:x:${EUID}:${EGID}:Open-EMR user,,,:/tmp:/usr/bin/bash" > "$PASSWD_FILE"
GROUP_FILE=$(mktemp)
echo "${OPENEMR_USER}:x:${EGID}:" > "$GROUP_FILE"
HOSTS_FILE=$(mktemp)
echo "127.0.0.1 localhost sandbox" >> "$HOSTS_FILE"
echo "::1 localhost sandbox" >> "$HOSTS_FILE"

echo "Running Apache"
LD_PRELOAD=libnss_wrapper.so NSS_WRAPPER_PASSWD="$PASSWD_FILE" NSS_WRAPPER_GROUP="$GROUP_FILE" NSS_WRAPPER_HOSTS="$HOSTS_FILE" APACHE_LOG_DIR=/var/log/apache2 APACHE_PID_FILE=/var/run/apache2/apache2.pid APACHE_RUN_DIR=/var/run/apache2 APACHE_RUN_GROUP=${OPENEMR_USER} APACHE_RUN_USER=${OPENEMR_USER} /usr/sbin/apache2 -D FOREGROUND

exit 0
