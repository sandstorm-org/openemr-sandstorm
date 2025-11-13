#!/bin/bash

# When you change this file, you must take manual action. Read this doc:
# - https://docs.sandstorm.io/en/latest/vagrant-spk/customizing/#setupsh

set -o errexit -o errtrace -o nounset -o pipefail
# This is the ideal place to do things like:
#
#    export DEBIAN_FRONTEND=noninteractive
#    apt-get update
#    apt-get install -y nginx nodejs nodejs-legacy python2.7 mysql-server
#
# If the packages you're installing here need some configuration adjustments,
# this is also a good place to do that:
#
#    sed --in-place='' \
#            --expression 's/^user www-data/#user www-data/' \
#            --expression 's#^pid /run/nginx.pid#pid /var/run/nginx.pid#' \
#            --expression 's/^\s*error_log.*/error_log stderr;/' \
#            --expression 's/^\s*access_log.*/access_log off;/' \
#            /etc/nginx/nginx.conf

# By default, this script does nothing.  You'll have to modify it as
# appropriate for your application.

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "${script_dir}/environment"

# Install Open-EMR dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get install --yes apache2 build-essential imagemagick libapache2-mod-php libnss-wrapper libtiff-tools mariadb-server php php-mysql php-cli php-gd php-xml php-curl php-soap php-json php-mbstring php-zip php-ldap php-intl

# Install development tools
apt-get install --yes patch

# Work with downloads
mkdir -p "${DOWNLOADS_DIR}"
cd "${DOWNLOADS_DIR}"

# Download Open-EMR
if [ ! -f "${OPENEMR_ARCHIVE}" ]; then
	printf "%s\n" "Downloading Open-EMR ${OPENEMR_VERSION} from ${OPENEMR_URL}"
	curl --location --proto '=https' --tlsv1.2 -sSf "${OPENEMR_URL}" > "${DOWNLOADS_DIR}/${OPENEMR_ARCHIVE}"
fi

# Verify Open-EMR download
printf "Verifying SHA-256 hash of Open-EMR archive\n"
sha256sum --check --ignore-missing "${OPENEMR_ARCHIVE}.sha256"

# Extract Open-EMR
printf "Extracting Open-EMR\n"
mkdir --parents "${OPENEMR_OPT_DIR}/openemr"
cd "${OPENEMR_OPT_DIR}/openemr"
tar --strip-components=1 -zxf "${DOWNLOADS_DIR}/${OPENEMR_ARCHIVE}"
# Remove this writable file and link it to /var
rm ${OPENEMR_OPT_DIR}/openemr/sites/default/sqlconf.php
ln -s ${OPENEMR_VAR_DIR}/openemr/sites/default/sqlconf.php ${OPENEMR_OPT_DIR}/openemr/sites/default/sqlconf.php
# Put the site documents in /var
rm -rf "${OPENEMR_OPT_DIR}/documents"
mv ${OPENEMR_OPT_DIR}/openemr/sites/default/documents ${OPENEMR_OPT_DIR}/documents
ln -s ${OPENEMR_VAR_DIR}/openemr/sites/default/documents ${OPENEMR_OPT_DIR}/openemr/sites/default/documents
# Patch Open-EMR
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/library/auth.inc.php ${PATCHES_DIR}/openemr-auth.inc.php.patch
rm ${OPENEMR_OPT_DIR}/openemr/src/Common/Auth/AuthSandstorm.php
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/src/Common/Auth/AuthSandstorm.php ${PATCHES_DIR}/openemr-AuthSandstorm.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/src/Common/Auth/AuthUtils.php ${PATCHES_DIR}/openemr-AuthUtils.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/interface/login/login.php ${PATCHES_DIR}/openemr-login.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/interface/main/main_screen.php ${PATCHES_DIR}/openemr-main_screen.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/interface/usergroup/user_admin.php ${PATCHES_DIR}/openemr-user_admin.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/interface/usergroup/usergroup_admin.php ${PATCHES_DIR}/openemr-usergroup_admin.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/interface/usergroup/usergroup_admin_add.php ${PATCHES_DIR}/openemr-usergroup_admin_add.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/src/Services/UserService.php ${PATCHES_DIR}/openemr-UserService.php.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/templates/login/login_core.html.twig ${PATCHES_DIR}/openemr-login_core.html.twig.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/templates/login/layouts/vertical_box.html.twig ${PATCHES_DIR}/openemr-vertical_box.html.twig.patch
${PATCH_CMD} ${OPENEMR_OPT_DIR}/openemr/templates/login/partials/html/login_details.html.twig ${PATCHES_DIR}/openemr-login_details.html.twig.patch

# Stop and disable services.  Sandstorm will run them.
systemctl stop apache2
systemctl stop mariadb
systemctl disable apache2
systemctl disable mariadb

# Update Apache HTTP Server configuration
a2enmod rewrite
a2dismod reqtimeout
a2dismod status
a2dissite 000-default
[ -f "${APACHE_SITES_DIR}/openemr.conf" ] && rm "${APACHE_SITES_DIR}/openemr.conf"
${PATCH_CMD} "${APACHE_SITES_DIR}/openemr.conf" "${PATCHES_DIR}/apache2-openemr.conf.patch"
[ -f "${APACHE_CONF_DIR}/global-server-name.conf" ] && rm "${APACHE_CONF_DIR}/global-server-name.conf"
${PATCH_CMD} "${APACHE_CONF_DIR}/global-server-name.conf" "${PATCHES_DIR}/apache2-global-server-name.conf.patch"
[ -f "${APACHE_ETC_DIR}/ports.conf.orig" ] && mv "${APACHE_ETC_DIR}/ports.conf.orig" "${APACHE_ETC_DIR}/ports.conf"
${PATCH_CMD} "${APACHE_ETC_DIR}/ports.conf" "${PATCHES_DIR}/apache2-ports.conf.patch"
a2enconf global-server-name
a2ensite openemr

# Update MariaDB configuration
[ -f "${MARIADB_HOME_DIR}/mariadb.cnf.orig" ] && mv "${MARIADB_HOME_DIR}/mariadb.cnf.orig" "${MARIADB_HOME_DIR}/mariadb.cnf"
${PATCH_CMD} "${MARIADB_HOME_DIR}/mariadb.cnf" "${PATCHES_DIR}/mariadb-mariadb.cnf.patch"
[ -f "${MARIADB_CONF_D_DIR}/50-server.cnf.orig" ] && mv "${MARIADB_CONF_D_DIR}/50-server.cnf.orig" "${MARIADB_CONF_D_DIR}/50-server.cnf"
${PATCH_CMD} "${MARIADB_CONF_D_DIR}/50-server.cnf" "${PATCHES_DIR}/mariadb-50-server.cnf.patch"

# Patch
exit 0
