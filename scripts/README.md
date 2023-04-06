## update_meilisearch_version_safely.sh

### Requirements

1. Systemd-based distribution.
2. Nginx Reverse proxy.
3. jq JSON processor.
4. A Running Meilisearch instance.

### Description
The script installs the new version of Meilisearch on a different port as an additional systemd service. It makes a dump from the current version and restores it to the new one.
After restoring a backup, it checks the health of the new Meilisearch version. if everything is successful, it replaces the port in the Nginx server block to direct traffic to a new version. 
Then it stops the original one.

The original version's data, executable, and configuration files are left for rollback. Once you ensure the new version is operational, you can delete them.

#### Advantages
- the original version of Meilisearch remains intact: data, executable, and configuration files.
- simple rollback: bring up the original version of Meilisearch and switch ports in the Nginx server block.
- (optional) the Meilisearch instance can continue serving read queries during an updating process if you block all writes.

### Usage

Before proceeding with the upgrade, it is recommended that you take a snapshot of your data, restore it to a new virtual machine, and test the scripts there first.

1. Open *update_meilisearch_version_safely.sh* and update variables specific to your deployment.
2. (Optional) To continue serving read queries during an updating process: 
   - set ORIGINAL_MEILISEARCH_STOP=false
   - stop any writes.
3. Run the following script with root user privileges

```bash
bash update_meilisearch_version_safely.sh
```

4. After update, cleanup the resources for the original version (data, executable, and configuration files)

### Rollback

Set variables and run the below snippet with root user privileges.
For more information on variables, please check the script comments.

```bash
ORIGINAL_MEILISEARCH_PORT=7700
NEW_MEILISEARCH_PORT=7701

ORIGINAL_MEILISEARCH_SERVICE=meilisearch.service
NEW_MEILISEARCH_SERVICE=meilisearch-v1.0.0.service

NGINX_CONFIG=/etc/nginx/sites-enabled/meilisearch

systemctl start $ORIGINAL_MEILISEARCH_SERVICE
sed -i "s/$NEW_MEILISEARCH_PORT/$ORIGINAL_MEILISEARCH_PORT/g" $NGINX_CONFIG
nginx -s reload
systemctl stop $NEW_MEILISEARCH_SERVICE
```

### Tested
v0.26.0 -> v1.0.0, AWS deployment with Meilisearch AMI.
