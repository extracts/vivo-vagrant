#!/bin/bash

#
# Setup Solr
#

# Solr version to be installed
SOLR_VERSION="8.11.1" # use "8.11.1" or "9.8.1"
SOLR_TAR="solr-$SOLR_VERSION.tgz"
SOLR_URL="https://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/$SOLR_TAR"

# Exit on first error
set -e

# Print shell commands
set -o verbose

# Determine the appropriate branch in the https://github.com/vivo-project/vivo-solr repository
SOLR_MAJOR_VERSION=$(echo $SOLR_VERSION | cut -d'.' -f1)
case $SOLR_MAJOR_VERSION in
  "8")
    SOLR_BRANCH="solr-8.11"
    ;;
  "9")
    SOLR_BRANCH="solr-9.8.1"
    ;;
  *)
    echo "Unsupported Solr major version: $SOLR_MAJOR_VERSION"
    exit 1
    ;;
esac

# Install Solr
# see <https://wiki.lyrasis.org/display/VIVODOC115x/Installing+VIVO#InstallingVIVO-ConfigureandStartSolr>
# see <https://github.com/vivo-project/vivo-solr/blob/main/README.md>
installSolr () {
  echo "Installing Solr v$SOLR_VERSION"

  echo '*           soft    nofile          65000' >> /etc/security/limits.conf
  echo '*           hard    nproc           65000' >> /etc/security/limits.conf

  if ! [ -f "$SOLR_TAR" ] || ! [ -s "$SOLR_TAR" ]; then
    echo "Getting: $SOLR_URL"
    wget -q --show-progress --progress=bar:force $SOLR_URL -O $SOLR_TAR
  fi

  mkdir -p /opt/solr || true
  tar xzvf $SOLR_TAR -C /opt/solr --strip-components=1 --no-same-owner

  mkdir -p /opt/solr/server/solr || true
  
  cd /home/vagrant

  if ! [ -d "vivo-solr" ]; then
    echo "Cloning Solr branch: $SOLR_BRANCH"
    git clone -b $SOLR_BRANCH https://github.com/vivo-project/vivo-solr.git vivo-solr || true
  fi

  cp -R vivo-solr/vivocore /opt/solr/server/solr

  /opt/solr/bin/solr start -force

  SOLR_SCHEMA="/opt/solr/server/solr/vivocore/conf/schema.xml"
  if test -f SOLR_SCHEMA; then
    rm SOLR_SCHEMA || true 
  fi
}

installSolr

echo Solr installed.

exit

