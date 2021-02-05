#!/usr/bin/env bash


# Abort on any error
set -e -u

# Require root for changing permissions
if [ "$USER" != "root" ]
then
	echo "Must be executed as user \"root\"!"
	exit -1
fi

# Download archive
ARCHIVE_PATH="/root/nextcloud.tar.bz2"
if ! [ -e "$ARCHIVE_PATH" ]; then
	curl --location "https://download.nextcloud.com/server/releases/latest.tar.bz2" --output "$ARCHIVE_PATH"
fi

# Clean up
BASE_PATH="/root/cloud"
rm -rf "$BASE_PATH"

# Extract archive
CLOUD_PATH="$BASE_PATH/data"
mkdir -p "$CLOUD_PATH"
tar --extract --bzip2 --strip-components=1 --directory "$CLOUD_PATH" --file "$ARCHIVE_PATH"
#echo "<?php phpinfo(); ?>" > "$CLOUD_PATH/info.php"

# Log dirs
LOG_PATH="$BASE_PATH/log"
mkdir -p "${LOG_PATH}_nginx"
mkdir -p "${LOG_PATH}_php"

# Certs
SSL_DIR="$BASE_PATH/ssl"
mkdir -p "$SSL_DIR"
openssl req -x509 -nodes -newkey rsa:4096 -days 365 -keyout "$SSL_DIR/cloud.key" -out "$SSL_DIR/cloud.cert" -subj "/CN=localhost"

# Tables
DB_PATH="$BASE_PATH/tables"
mkdir -p "$DB_PATH"
mariadb-install-db --datadir="$DB_PATH"

# Set permissions
chown -R 33:33 "$BASE_PATH"
chown -R 1374:1374 "$DB_PATH"
