#!/bin/bash

#
# Setup the base box
#

# Exit on first error
set -e

# Print shell commands
set -o verbose

# Update Ubuntu packages. Comment out during development
apt-get update -y

# Install Java
apt-get -yq install openjdk-11-jdk

# Install Maven
apt-get install -y maven

# Some utils
apt-get install -y git vim screen wget curl raptor2-utils unzip

# Set time zone
timedatectl set-timezone Europe/Berlin

# Install MariaDB 10.11
installMySQL () {
  export DEBIAN_FRONTEND=noninteractive

  # Import the MariaDB GPG key
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

  # Add the MariaDB repository
  add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://ftp.osuosl.org/pub/mariadb/repo/10.11/ubuntu jammy main'

  # Update the package lists
  apt-get update -y

  # Install MariaDB
  apt-get install -y mariadb-server mariadb-client

  # Set the root password
  mysqladmin -u root password vivo
}

# Install Tomcat 9
installTomcat () {
  # Tomcat 9 version to be installed
  TOMCAT_VERSION="9.0.113"
  TOMCAT_TAR="apache-tomcat-$TOMCAT_VERSION.tar.gz"
  TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/$TOMCAT_TAR"

  groupadd tomcat || true
  useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat || true

  if test ! -f "$TOMCAT_TAR"; then
    echo "Getting: $TOMCAT_URL"
    wget -q --show-progress --progress=bar:force $TOMCAT_URL -O $TOMCAT_TAR
  fi

  mkdir -p /opt/tomcat || true
  tar xzvf $TOMCAT_TAR -C /opt/tomcat --strip-components=1 --no-same-owner

  chgrp -R tomcat /opt/tomcat
  chmod -R g+r /opt/tomcat/conf
  chmod g+x /opt/tomcat/conf
  chown -R tomcat /opt/tomcat/webapps /opt/tomcat/work /opt/tomcat/temp /opt/tomcat/logs

  cp /home/vagrant/provision/tomcat/tomcat.service /etc/systemd/system/tomcat.service

  cp /home/vagrant/provision/tomcat/server.xml /opt/tomcat/conf/server.xml

  cp /home/vagrant/provision/tomcat/context.xml /opt/tomcat/webapps/manager/META-INF/context.xml

  cp /home/vagrant/provision/tomcat/context.xml /opt/tomcat/webapps/host-manager/META-INF/context.xml

  cp /home/vagrant/provision/tomcat/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml

  systemctl daemon-reload

  systemctl start tomcat
  systemctl enable tomcat
}

# Setup Ubuntu Firewall
setupFirewall () {
  ufw allow 22
  ufw allow 8080
  ufw allow 8081
  ufw allow 8000
  ufw enable
}

installMySQL
installTomcat
setupFirewall

# ca-certificates-java must be explicitly installed as it is needed for maven based installation
/var/lib/dpkg/info/ca-certificates-java.postinst configure

# Make Karma scripts executable
chmod +x /home/vagrant/provision/karma.sh

echo Box boostrapped.

exit

