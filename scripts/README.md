## update_meilisearch_version_safely.sh

### Requirements

1. Systemd-based distribution.
2. Nginx Reverse proxy.
3. jq JSON processor.
4. A Running Meilisearch instance.
5. Disable writes before running a script.

### Description
The script installs the new version of Meilisearch on a different port as an additional systemd service. It makes a dump from the current version and restores it to the new one.
After restoring a backup, it checks the health of the new version. if everything is successful, it replaces the port in the Nginx server block to direct traffic to a new version. 
Then it stops the original version.

Advantages:
- the original version of Meilisearch remains intact: data, executable, configuration.
- the Meilisearch instance continues serving read queries during an updating process.

Caveats:
If writes are not disabled, data synchronization is needed to copy changes made to the original version during an updating process. To disable all queries, set 
CURRENT_MEILISEARCH_STOP=true if there are no requirements to have read queries available during an update.

### Usage

1. Open *update_meilisearch_version_safely.sh* and update variables specific to your deployment.
2. Disable writes (see "Caveats").
3. Run the following script

```bash
bash update_meilisearch_version_safely.sh
```

4. After update, cleanup the resources for the original version (data, executable, configuration)

### Tests
v0.26.0 -> v1.0.0, AWS deployment with Meilisearch AMI.
