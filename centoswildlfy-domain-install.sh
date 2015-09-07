#!/bin/bash
#title           :wildfly-install.sh
#description     :The script to install Wildfly 8.x
#more            :
#author	         :Marek Polcar, Dmitriy Sukharev  -- Edited by AURA TECNOLOGICA S.L
#date            :20150907
#usage           :/bin/bash wildfly-install.sh

WILDFLY_VERSION=8.2.0.Final
WILDFLY_FILENAME=wildfly-$WILDFLY_VERSION
WILDFLY_ARCHIVE_NAME=$WILDFLY_FILENAME.tar.gz
WILDFLY_DOWNLOAD_ADDRESS=http://download.jboss.org/wildfly/$WILDFLY_VERSION/$WILDFLY_ARCHIVE_NAME

INSTALL_DIR=/opt
WILDFLY_FULL_DIR=$INSTALL_DIR/$WILDFLY_FILENAME
WILDFLY_DIR=$INSTALL_DIR/wildfly

WILDFLY_USER="wildfly"
WILDFLY_SERVICE="wildfly"
WILDFLY_CONFIG="domain.xml"

WILDFLY_STARTUP_TIMEOUT=240
WILDFLY_SHUTDOWN_TIMEOUT=30

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

echo "Downloading: $WILDFLY_DOWNLOAD_ADDRESS..."
[ -e "$WILDFLY_ARCHIVE_NAME" ] && echo 'Wildfly archive already exists.'
if [ ! -e "$WILDFLY_ARCHIVE_NAME" ]; then
  wget -q $WILDFLY_DOWNLOAD_ADDRESS
  if [ $? -ne 0 ]; then
    echo "Not possible to download Wildfly."
    exit 1
  fi
fi

echo "Cleaning up..."
rm -f "$WILDFLY_DIR"
rm -rf "$WILDFLY_FULL_DIR"
rm -rf "/var/run/$WILDFLY_SERVICE/"
rm -f "/etc/init.d/$WILDFLY_SERVICE"

echo "Installation..."
mkdir $WILDFLY_FULL_DIR
tar -xzf $WILDFLY_ARCHIVE_NAME -C $INSTALL_DIR
ln -s $WILDFLY_FULL_DIR/ $WILDFLY_DIR
useradd -s /sbin/nologin $WILDFLY_USER
chown -R $WILDFLY_USER:$WILDFLY_USER $WILDFLY_DIR
chown -R $WILDFLY_USER:$WILDFLY_USER $WILDFLY_DIR/

echo "Registrating Wildfly as service..."
# if RHEL-like distribution
if [ -r /etc/init.d/functions ]; then
    cp $WILDFLY_DIR/bin/domain.sh /etc/init.d/$WILDFLY_SERVICE
    WILDFLY_SERVICE_CONF=/etc/default/wildfly.conf
fi

chmod 755 /etc/init.d/$WILDFLY_SERVICE

if [ ! -z "$WILDFLY_SERVICE_CONF" ]; then
    echo "Configuring service..."
    echo JBOSS_HOME=\"$WILDFLY_DIR\" > $WILDFLY_SERVICE_CONF
    echo JBOSS_USER=$WILDFLY_USER >> $WILDFLY_SERVICE_CONF
    echo STARTUP_WAIT=$WILDFLY_STARTUP_TIMEOUT >> $WILDFLY_SERVICE_CONF
    echo SHUTDOWN_WAIT=$WILDFLY_SHUTDOWN_TIMEOUT >> $WILDFLY_SERVICE_CONF
    echo JBOSS_CONFIG=$WILDFLY_CONFIG >> $WILDFLY_SERVICE_CONF
fi

echo "Configuring application server..."
sed -i -e 's,</extensions>,</extensions><system-properties><property name="TAPKA_ENV" value="prod"/></system-properties>,g' $WILDFLY_DIR/domain/configuration/$WILDFLY_CONFIG
sed -i -e 's,<inet-address value="${jboss.bind.address:127.0.0.1}"/>,<any-address/>,g' $WILDFLY_DIR/domain/configuration/$WILDFLY_CONFIG

service $WILDFLY_SERVICE start

echo "Done."