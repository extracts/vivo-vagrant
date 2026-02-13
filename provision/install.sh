#!/bin/bash

#
# Install VIVO.
#

# Defines the VIVO & Vitro repositories to be used
VIVOREPO="https://github.com/extracts/VIVO.git"
VITROREPO="https://github.com/vivo-project/Vitro.git"

# Defines the VIVO & Vitro branches (and thus versions) to be used
VIVOBRANCH="rel-1.15-maint"
VITROBRANCH="rel-1.15-maint"

# Exit on first error
set -e

# Print shell commands
set -o verbose

# Extract the version number (or any number) from the branch name
VERSION=$(echo "$VIVOBRANCH" | grep -o -E '\d+(\.\d+\.?\d*)?') || true
VERSION=$(echo "$VERSION" | tr -d '.') || true
VIVO_DATABASE="vivodev"
export VIVO_DATABASE
# TODO: it would be nice to also adopt the VIVO database names in
#       `reset_vivo_db.sh` and `vivo/runtime.properties` dynamically,
#       then use `VIVO_DATABASE="vivo${VERSION}dev"`

# Make data directory
mkdir -p /opt/vivo
# Make config directory
mkdir -p /opt/vivo/config
# Make log directory
mkdir -p /opt/vivo/logs

# Make src directory
mkdir -p /home/vagrant/src

removeRDFFiles(){
    # In development, you might want to remove these ontology and data files
    # since they slow down Tomcat restarts considerably.
    rm /opt/vivo/rdf/tbox/filegraph/geo-political.owl
    rm /opt/vivo/rdf/abox/filegraph/continents.n3
    rm /opt/vivo/rdf/abox/filegraph/us-states.rdf
    rm /opt/vivo/rdf/abox/filegraph/geopolitical.abox.ver1.1-11-18-11.owl
    return $TRUE
}

setLogAlias() {
    # Alias for viewing VIVO log
    VLOG="alias vlog='less +F /opt/tomcat/logs/vivo.all.log'"
    BASHRC=/home/vagrant/.bashrc

    if grep "$VLOG" $BASHRC > /dev/null
    then
       echo "log alias exists"
    else
       (echo;  echo $VLOG)>> $BASHRC
       echo "log alias created"
    fi
}

setupTomcat() {
    cd
    # Change permissions
    dirs=( /opt/vivo /opt/tomcat/webapps/vivo )
    for dir in "${dirs[@]}"
    do
      chown -R vagrant:tomcat $dir
      chmod -R g+rws $dir
    done

    # Add redirect to /vivo in tomcat root
    rm -f /opt/tomcat/webapps/ROOT/index.html
    cp /home/vagrant/provision/vivo/index.jsp /opt/tomcat/webapps/ROOT/index.jsp
}

setupMySQL() {
  mysql --user=root --password=vivo -e "CREATE DATABASE ${VIVO_DATABASE} CHARACTER SET utf8;" || true
  mysql --user=root --password=vivo -e "GRANT ALL ON ${VIVO_DATABASE}.* TO 'vivo'@'localhost' IDENTIFIED BY 'vivo';"
}

installVIVO() {

  echo 'apache           hard    nproc           400' >> /etc/security/limits.conf
  echo 'tomcat           hard    nproc           1500' >> /etc/security/limits.conf

  # Vivo
  cd /home/vagrant/src

  if ! [ -d "Vitro" ]; then
    echo "Cloning Vitro branch $VITROBRANCH from $VITROREPO"
    git clone --depth 1 -b ${VITROBRANCH} ${VITROREPO} Vitro || true
  fi

  if ! [ -d "VIVO" ]; then
    echo "Cloning VIVO branch $VIVOBRANCH from $VIVOREPO"
    git clone --depth 1 -b ${VIVOBRANCH} ${VIVOREPO} VIVO || true
  fi

  cd VIVO
  mvn clean install -DskipTests -s /home/vagrant/provision/vivo/settings.xml

  cp /home/vagrant/provision/vivo/runtime.properties /opt/vivo/config/runtime.properties
  cp /home/vagrant/provision/vivo/developer.properties /opt/vivo/config/developer.properties
  cp /home/vagrant/provision/vivo/build.properties /opt/vivo/config/build.properties
  cp /home/vagrant/provision/vivo/applicationSetup.n3 /opt/vivo/config/applicationSetup.n3

  chgrp -R tomcat /opt/vivo
  chown -R tomcat /opt/vivo
}

# Stop tomcat
systemctl stop tomcat

# add vagrant to tomcat group
if ! id "vagrant" >/dev/null 2>&1; then
  echo "Creating 'vagrant' user"
  adduser --disabled-password --gecos "" vagrant || true
fi
usermod -a -G tomcat vagrant || true

# create VIVO database
setupMySQL

# install the app
installVIVO

# Adjust tomcat permissions
setupTomcat

# Set a log alias
setLogAlias

# Start tomcat
systemctl start tomcat

echo VIVO installed.

exit

