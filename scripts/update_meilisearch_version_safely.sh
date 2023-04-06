#!/bin/bash

set -ueo pipefail

# The master key of original and new Meilisearch versions
MEILISEARCH_MASTER_KEY=
# The system user for running the new Meilisearch version
MEILISEARCH_USER=meilisearch

# The dir where the original Meilisearch version stores dumps
ORIGINAL_MEILISEARCH_DUMP_DIR=/var/opt/meilisearch/dumps
# The port of the original Meilisearch version
ORIGINAL_MEILISEARCH_PORT=7700
# The name of the systemd service of the original Meilisearch version
ORIGINAL_MEILISEARCH_SERVICE=meilisearch.service
# To stop routing traffic to the original version of Meilisearch before making a dump.
ORIGINAL_MEILISEARCH_STOP=true

# The port of the new Meilisearch version 
NEW_MEILISEARCH_PORT=7701
# The version of the new Meilisearch to install
NEW_MEILISEARCH_VERSION=v1.0.0

# The Nginx configuration file with Reverse Proxy settings for Meilisearch.
# After the migration, the port number $ORIGINAL_MEILISEARCH_PORT will be 
# replaces with $NEW_MEILISEARCH_PORT and Nginx process will be reloaded.
NGINX_CONFIG=/etc/nginx/sites-enabled/meilisearch



trap 'error_handler' ERR SIGINT
error_handler() { 
  if [ "$ORIGINAL_MEILISEARCH_STOP" == "true" ]; then
    systemctl start $ORIGINAL_MEILISEARCH_SERVICE
    log "Restoring Nginx configuration file from $TMP_NGINX_CONFIG"
    mv $TMP_NGINX_CONFIG $NGINX_CONFIG 
    rmdir $(dirname $TMP_NGINX_CONFIG)
    nginx -s reload
    log "Restored."
  fi    
}
log() { echo -e "[log]: $1" ;}

# 
# Validate input
#

[ -z "$MEILISEARCH_MASTER_KEY" ] && unset MEILISEARCH_MASTER_KEY

# 
# Create and prepare dump from the original Meilisearch version
#

if [ "$ORIGINAL_MEILISEARCH_STOP" == "true" ]; then
  log "Stop routing traffic to the original version from Nginx."
  TMP_NGINX_CONFIG=$(mktemp -d)/${NGINX_CONFIG##*/}
  mv $NGINX_CONFIG $TMP_NGINX_CONFIG
  nginx -s reload
  log "Nginx configuration file is moved to $TMP_NGINX_CONFIG"
  log "Stopped."
fi

log "Start dump creation."
response=$(curl -sS --fail -X POST "http://localhost:$ORIGINAL_MEILISEARCH_PORT/dumps" -H "Authorization: Bearer $MEILISEARCH_MASTER_KEY")
dump_uid=$(jq -r '.uid' <<< $response)
log "Dump uid: $dump_uid"

log "Wait until dump is ready."
while true; do
  response=$(curl -sS -X GET "http://localhost:$ORIGINAL_MEILISEARCH_PORT/dumps/$dump_uid/status" -H "Authorization: Bearer $MEILISEARCH_MASTER_KEY")
  status=$(jq -r '.status' <<< $response)
  if [ "$status" == "done" ]; then
    log "Dump is created."
    break
  fi
  log "Status of a dump creation process: $status"
  sleep 5
done

dump_file="$ORIGINAL_MEILISEARCH_DUMP_DIR/$dump_uid.dump"
log "Dump location: $dump_file"

if [ "$ORIGINAL_MEILISEARCH_STOP" == "true" ]; then
  log "Stop the original version of Meilisearch after making a dump."
  systemctl stop $ORIGINAL_MEILISEARCH_SERVICE
  log "Stopped."
fi

# 
# Install and configure a new systemd service for running the new Meilisearch version
#

log "Download Meilisearch $NEW_MEILISEARCH_VERSION binary."
curl -sSL --fail "https://github.com/meilisearch/meilisearch/releases/download/$NEW_MEILISEARCH_VERSION/meilisearch-linux-amd64" -o meilisearch-$NEW_MEILISEARCH_VERSION
chmod +x meilisearch-$NEW_MEILISEARCH_VERSION
mv meilisearch-$NEW_MEILISEARCH_VERSION /usr/local/bin
log "Done."

mkdir -p /var/lib/meilisearch-$NEW_MEILISEARCH_VERSION/{data,dumps,snapshots}

cat << EOF > /etc/meilisearch.toml
env = "production"
master_key = "$MEILISEARCH_MASTER_KEY"
db_path = "/var/lib/meilisearch-$NEW_MEILISEARCH_VERSION/data"
dump_dir = "/var/lib/meilisearch-$NEW_MEILISEARCH_VERSION/dumps"
snapshot_dir = "/var/lib/meilisearch-$NEW_MEILISEARCH_VERSION/snapshots"
http_addr = "localhost:$NEW_MEILISEARCH_PORT"
EOF

cat << EOF > /etc/systemd/system/meilisearch-$NEW_MEILISEARCH_VERSION.service
[Unit]
Description=Meilisearch
After=systemd-user-sessions.service

[Service]
Type=simple
WorkingDirectory=/var/lib/meilisearch-$NEW_MEILISEARCH_VERSION
ExecStart=/usr/local/bin/meilisearch-$NEW_MEILISEARCH_VERSION --config-file-path /etc/meilisearch.toml --import-dump $dump_file
User=$MEILISEARCH_USER
Group=$MEILISEARCH_USER

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload

id -u $MEILISEARCH_USER &>/dev/null || useradd -d /var/lib/meilisearch -b /bin/false -M -r $MEILISEARCH_USER
chown -R $MEILISEARCH_USER:$MEILISEARCH_USER /var/lib/meilisearch-$NEW_MEILISEARCH_VERSION
chmod 750 /var/lib/meilisearch-$NEW_MEILISEARCH_VERSION 
chown $MEILISEARCH_USER:$MEILISEARCH_USER $dump_file

# 
# Start the new Meilisearch version and begin the restoration process
#

log "Start meilisearch-$NEW_MEILISEARCH_VERSION.service and begin the restoration process."
systemctl start meilisearch-$NEW_MEILISEARCH_VERSION

sed -i 's/--import-dump [^ ]*//' /etc/systemd/system/meilisearch-$NEW_MEILISEARCH_VERSION.service
systemctl daemon-reload
systemctl enable meilisearch-$NEW_MEILISEARCH_VERSION
systemctl status --no-pager meilisearch-$NEW_MEILISEARCH_VERSION

log "Wait until Meilisearch $NEW_MEILISEARCH_VERSION is up and healthy."
while true; do
  service_state=$(systemctl is-active meilisearch-$NEW_MEILISEARCH_VERSION.service || :)
  log "The meilisearch-$NEW_MEILISEARCH_VERSION.service is in $service_state state."
  if [ "$service_state" != "active" ]; then
    log "The import operation failed. Check meilisearch-$NEW_MEILISEARCH_VERSION.service logs."
    exit 1
  fi

  response=$(curl -sS --fail -X GET "http://localhost:$NEW_MEILISEARCH_PORT/health" -H "Authorization: Bearer $MEILISEARCH_MASTER_KEY" 2>/dev/null) && exist_code="$?" || exist_code="$?" 
  if [ $exist_code -ne 0 ]; then 
    log "Meilisearch $NEW_MEILISEARCH_VERSION is still importing data."
    sleep 15
  else 
    status=$(jq -r '.status' <<< $response)
    if [ "$status" == "available" ]; then
      log "Meilisearch $NEW_MEILISEARCH_VERSION is up and healthy."
      break 
    fi
  fi
done
log "The restoration process is finished."

#
# Route traffic to a new Meilisearch version by changing the port in the proxy_pass directive
# 

if [ "$ORIGINAL_MEILISEARCH_STOP" == "true" ]; then
  mv $TMP_NGINX_CONFIG $NGINX_CONFIG 
  rmdir $(dirname $TMP_NGINX_CONFIG)
fi

log "Update Nginx server block to direct traffic to Meilisearch $NEW_MEILISEARCH_VERSION"
sed -i "s/$ORIGINAL_MEILISEARCH_PORT/$NEW_MEILISEARCH_PORT/g" $NGINX_CONFIG
nginx -s reload

#
# Turn off the original version of Meilisearch
# 

log "Stop and disable the original Meilisearch version."
systemctl stop $ORIGINAL_MEILISEARCH_SERVICE
systemctl disable $ORIGINAL_MEILISEARCH_SERVICE
log "Done."
