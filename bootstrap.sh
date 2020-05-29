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
ARCHIVE_PATH="/tmp/nextcloud.tar.bz2"
if ! [ -e "$ARCHIVE_PATH" ]; then
	curl --location "https://download.nextcloud.com/server/releases/latest.tar.bz2" --output "$ARCHIVE_PATH"
fi

# Extract archive
CLOUD_PATH="/tmp/cloud"
mkdir -p "$CLOUD_PATH"
tar --extract --bzip2 --strip-components=1 --directory "$CLOUD_PATH" --file "$ARCHIVE_PATH"

# Log dirs
LOG_PATH="/tmp/log"
mkdir -p "$LOG_PATH/nginx"
mkdir -p "$LOG_PATH/php"

# Set permissions
chown -R http:http "$CLOUD_PATH" "$LOG_PATH"