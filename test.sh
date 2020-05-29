#!/usr/bin/env bash


# Abort on any error
set -e -u

# Simpler git usage, relative file paths
CWD=$(dirname "$0")
cd "$CWD"

# Load helpful functions
source libs/common.sh

# Check access to docker daemon
assert_dependency "docker"
if ! docker version &> /dev/null; then
	echo "Docker daemon is not running or you have unsufficient permissions!"
	exit -1
fi

# Download archive
ARCHIVE_PATH="/tmp/nextcloud.tar.bz2"
if ! [ -e "$ARCHIVE_PATH" ]; then
	curl --location "https://download.nextcloud.com/server/releases/latest.tar.bz2" --output "$ARCHIVE_PATH"
fi

APP_NAME="nextcloud"

# Set up temporary srv directory
TMP_SRV_DIR=$(mktemp -d "/tmp/$APP_NAME-DATA-XXXXXXXXXX")
add_cleanup "rm -rf $TMP_SRV_DIR"
tar --extract --bzip2 --strip-components=1 --directory "$TMP_SRV_DIR" --file "$ARCHIVE_PATH"

# Set up temporary hosts directory
TMP_HOSTS_DIR=$(mktemp -d "/tmp/$APP_NAME-HOSTS-XXXXXXXXXX")
add_cleanup "rm -rf $TMP_HOSTS_DIR"
cp "host.conf" "$TMP_HOSTS_DIR"

# Set up temporary log directory
TMP_LOG_DIR=$(mktemp -d "/tmp/$APP_NAME-LOG-XXXXXXXXXX")
add_cleanup "rm -rf $TMP_LOG_DIR"
mkdir "$TMP_LOG_DIR/nginx"
mkdir "$TMP_LOG_DIR/php"

# Apply permissions, UID & GID matches process user
chown -R "33":"33" "$TMP_SRV_DIR" "$TMP_HOSTS_DIR" "$TMP_LOG_DIR"

# Network
NETWORK_NAME="$APP_NAME-test"
docker network create "$NETWORK_NAME"
add_cleanup "docker network rm $NETWORK_NAME"

# Start php-fpm
PHP_CONT_NAME="$APP_NAME-php-fpm"
docker run \
--rm \
--detach \
--net "$NETWORK_NAME" \
--publish 9000:9000/tcp \
--mount type=bind,source="$TMP_SRV_DIR",target="/srv" \
--mount type=bind,source="$TMP_LOG_DIR/php",target="/var/log/php7" \
--mount type=bind,source=/etc/localtime,target=/etc/localtime,readonly \
--name "$PHP_CONT_NAME" \
hetsh/php-fpm-nextcloud
add_cleanup "docker stop $PHP_CONT_NAME"

# Start nginx
NGINX_CONT_NAME="$APP_NAME-nginx"
docker run \
--rm \
--interactive \
--net "$NETWORK_NAME" \
--publish 80:80/tcp \
--mount type=bind,source="$TMP_SRV_DIR",target="/srv" \
--mount type=bind,source="$TMP_HOSTS_DIR",target="/etc/nginx/conf.d" \
--mount type=bind,source="$TMP_LOG_DIR/nginx",target="/var/log/nginx" \
--mount type=bind,source=/etc/localtime,target=/etc/localtime,readonly \
--name "$NGINX_CONT_NAME" \
hetsh/nginx