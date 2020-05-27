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

# Set up temporary srv directory
APP_NAME="nextcloud"
TMP_SRV_DIR=$(mktemp -d "/tmp/$APP_NAME-DATA-XXXXXXXXXX")
add_cleanup "rm -rf $TMP_SRV_DIR"
tar --extract --bzip2 --strip-components=1 --directory "$TMP_SRV_DIR" --file "$ARCHIVE_PATH"

# Set up temporary hosts directory
TMP_HOSTS_DIR=$(mktemp -d "/tmp/$APP_NAME-HOSTS-XXXXXXXXXX")
add_cleanup "rm -rf $TMP_HOSTS_DIR"
echo "server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;

	root /srv;
	index index.html;

	location ~ \.php$ {
		fastcgi_pass $APP_NAME-php-fpm:9000;
		include fastcgi_params;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
	}
}" > "$TMP_HOSTS_DIR/host.conf"

# Apply permissions, UID & GID matches process user
chown -R "33":"33" "$TMP_SRV_DIR" "$TMP_HOSTS_DIR"

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
--mount type=bind,source=/etc/localtime,target=/etc/localtime,readonly \
--name "$PHP_CONT_NAME" \
hetsh/php-fpm-nextcloud
add_cleanup "docker stop $PHP_CONT_NAME"

# Start nginx
docker run \
--rm \
--interactive \
--net "$NETWORK_NAME" \
--publish 80:80/tcp \
--mount type=bind,source="$TMP_SRV_DIR",target="/srv" \
--mount type=bind,source="$TMP_HOSTS_DIR",target="/etc/nginx/conf.d" \
--mount type=bind,source=/etc/localtime,target=/etc/localtime,readonly \
--name "$APP_NAME-nginx" \
hetsh/nginx