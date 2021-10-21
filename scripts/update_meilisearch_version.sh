#!/bin/bash

## Constants

RED="\033[0;31m"
BRED="\033[1;31m"
BGREEN="\033[1;32m"
BYELLOW="\033[1;33m"
BBLUE="\033[1;34m"
BPINK="\033[1;35m"
WHITE="\033[0m"
NC="\033[0m"
ERROR_LABEL="${BRED}error: ${NC}"
SUCCESS_LABEL="${BGREEN}success: ${NC}"
PENDING_LABEL="${BYELLOW}pending: ${NC}"
INFO_LABEL="${BBLUE}info: ${NC}"

## Utils Functions

# Rollback to previous MeiliSearch version in case something went wrong

previous_version_rollback() {

    echo "${ERROR_LABEL}MeiliSearch update to $meilisearch_version failed." >&2
    echo "${INFO_LABEL}Rollbacking to previous version ${BPINK}$current_meilisearch_version${NC}." >&2
    echo "${INFO_LABEL}Recovering..." >&2
    mv /tmp/meilisearch /usr/bin/meilisearch
    echo "${SUCCESS_LABEL}Recover previous data.ms." >&2
    mv /tmp/data.ms /var/lib/meilisearch/data.ms
    echo "${INFO_LABEL}Restarting MeiliSearch." >&2
    systemctl restart meilisearch
    systemctl_status exit
    echo "${SUCCESS_LABEL}Previous MeiliSearch version ${BPINK}$current_meilisearch_version${NC} restarted correctly with its data recovered." >&2
    delete_temporary_files
    echo "${ERROR_LABEL}Update MeiliSearch from ${BPINK}$current_meilisearch_version${NC} to ${BPINK}$meilisearch_version${NC} failed. Rollback to previous version successfull." >&2
    exit
}

# Check if MeiliSearch systemctl process is Active
systemctl_status() {
    systemctl status meilisearch | grep -E 'Active: active \(running\)' -q
    grep_status_code=$?
    callback_1=$1
    callback_2=$2
    if [ $grep_status_code -ne 0 ]; then
        echo "${ERROR_LABEL}MeiliSearch Service is not Running. Please start MeiliSearch." >&2
        if [ ! -z "$callback_1" ]; then
            $callback_1
        fi

        if [ ! -z "$callback_2" ]; then
            $callback_2
        fi
    fi
}

# Delete temporary files
delete_temporary_files() {
    echo "${INFO_LABEL}Cleaning temporary files..."
    if [ -f "meilisearch" ]; then
        rm meilisearch
        echo "${SUCCESS_LABEL}Delete temporary meilisearch binary."
    fi

    if [ -d "logs" ]; then
        rm logs
        echo "${SUCCESS_LABEL}Delete temporary logs file."
    fi

    local dump_file="/dumps/$dump_id.dump"
    if [ -f $dump_file ]; then
        rm "$dump_file"
        echo "${SUCCESS_LABEL}Delete temporary dump file."
    fi

}

# Check if MeiliSearch arguments are provided
check_args() {
    if [ $1 -eq 0 ]; then
        echo "${ERROR_LABEL}$2"
        exit
    fi
}

# Check if latest command exit status is not an error
check_last_exit_status() {
    status=$1
    message=$2
    callback_1=$3
    callback_2=$4

    if [ $status -ne 0 ]; then
        echo "${ERROR_LABEL}$messag."
        if [ ! -z "$callback_1" ]; then
            ($callback_1)
        fi
        if [ ! -z "$callback_2" ]; then
            ($callback_2)
        fi
        exit
    fi
}

## Main Script

#
# Current Running MeiliSearch
#

echo "${SUCCESS_LABEL}Starting version update of MeiliSearch."

# Check if MeiliSearch Service is running
systemctl_status exit

# Check if version argument was provided on script launch
check_args $# "MeiliSearch version not provided as arg.\nUsage: sh update_meilisearch_version.sh [vX.X.X]"

# Version to update MeiliSearch to.
meilisearch_version=$1

echo "${SUCCESS_LABEL}Requested MeiliSearch version: ${BPINK}$meilisearch_version${NC}."

# Current MeiliSearch version
current_meilisearch_version=$(
    curl -X GET 'http://localhost:7700/version' --header "X-Meili-API-Key: $MEILISEARCH_MASTER_KEY" -s --show-error |
        cut -d '"' -f 12
)

# Check if curl version request is successfull.
check_last_exit_status $? "Version request 'GET /version' request failed."
echo "${SUCCESS_LABEL}Current running MeiliSearch version: ${BPINK}$current_meilisearch_version${NC}."

#
# Back Up Dump
#

# Create dump for migration in case of incompatible versions
echo "${INFO_LABEL}Creation of a dump in case new version does not have compatibility with the current MeiliSearch."
dump_return=$(curl -X POST 'http://localhost:7700/dumps' --header "X-Meili-API-Key: $MEILISEARCH_MASTER_KEY" --show-error -s)

# Check if curl request was successfull.
check_last_exit_status $? "Dump creation 'POST /dumps' request failed."

# Get the dump id
dump_id=$(echo $dump_return | cut -d '"' -f 4)
echo "${INFO_LABEL}Creating dump id with id: $dump_id."

# Check if curl call succeeded to avoid infinite loop. In case of fail exit and clean
response=$(curl -X GET "http://localhost:7700/dumps/$dump_id/status" --header "X-Meili-API-Key: $MEILISEARCH_MASTER_KEY" --show-error -s)
if echo response | grep '"status":"failed"' -q; then
    echo "${ERROR_LABEL}MeiliSearch could not create the dump:\n ${response}" >&2
    delete_temporary_files
    exit
fi

check_last_exit_status $? \
    "Dump status check 'POST /dumps/:dump_id/status' request failed." \
    delete_temporary_files dump_id

# Wait for Dump to be created
until curl -X GET "http://localhost:7700/dumps/$dump_id/status" \
    --header "X-Meili-API-Key: $MEILISEARCH_MASTER_KEY" --show-error -s |
    grep '"status":"done"' -q; do
    echo "${PENDING_LABEL}MeiliSearch is still creating the dump: $dump_id."
    sleep 2
done

echo "${SUCCESS_LABEL}MeiliSearch finished creating the dump: $dump_id."

#
# New MeiliSsarch
#

# Download MeiliSearch of the right version
echo "${INFO_LABEL}Downloading MeiliSearch version ${BPINK}$meilisearch_version${NC}."
response=$(curl "https://github.com/meilisearch/MeiliSearch/releases/download/$meilisearch_version/meilisearch-linux-amd64" --output meilisearch --location -s --show-error)

check_last_exit_status $? \
    "Request to download MeiliSearch $meilisearch_version release failed." \
    delete_temporary_files

# Give read and write access to meilisearch binary
chmod +x meilisearch

# Check if MeiliSearch binary is not corrupted
if file meilisearch | grep "ELF 64-bit LSB shared object" -q; then
    echo "${SUCCESS_LABEL}Successfully downloaded MeiliSearch version $meilisearch_version."
else
    echo "${ERROR_LABEL}MeiliSearch binary is corrupted.\n\
  It may be due to: \n\
  - Invalid version syntax. Provided: $meilisearch_version, expected: vX.X.X. ex: v0.22.0 \n\
  - Rate limiting from GitHub." >&2
    delete_temporary_files
    exit
fi

echo "${INFO_LABEL}Stopping MeiliSearch Service to update the version."
## Stop meilisearch running
systemctl stop meilisearch # stop the service to update the version

## Move the binary of the current MeiliSearch version to the temp folder
echo "${INFO_LABEL}Keep a temporary copy of previous MeiliSearch."
mv /usr/bin/meilisearch /tmp

## Copy
echo "${INFO_LABEL}Update MeiliSearch version."
cp meilisearch /usr/bin/meilisearch

## Restart MeiliSearch
systemctl restart meilisearch
echo "${INFO_LABEL}MeiliSearch $meilisearch_version is starting."

# Stopping MeiliSearch Service
systemctl stop meilisearch
echo "${INFO_LABEL}Stop MeiliSearch $meilisearch_version service."

# Keep cache of previous data.ms in case of failure
cp -r /var/lib/meilisearch/data.ms /tmp/
echo "${INFO_LABEL}Copy data.ms to be able to recover in case of failure."

# Remove data.ms
rm -rf /var/lib/meilisearch/data.ms
echo "${INFO_LABEL}Delete current MeiliSearch's data.ms"

# Run MeiliSearch
MEILI_IMPORT_DUMP="/dumps/$dump_id.dump"
./meilisearch --db-path /var/lib/meilisearch/data.ms --env production --import-dump "/dumps/$dump_id.dump" --master-key $MEILISEARCH_MASTER_KEY 2>logs &
echo "${INFO_LABEL}Run local $meilisearch_version binary importing the dump and creating the new data.ms."

sleep 2

# Needed conditions due to bug in MeiliSearch #1701
if cat logs | grep "Error: No such file or directory (os error 2)" -q; then
    # If dump was empty no import is needed
    echo "${SUCCESS_LABEL}Empty database! Importing of no data done."
else
    echo "${INFO_LABEL}Check if local $meilisearch_version started correctly."
    # Check if local meilisearch started correctly `./meilisearch ..`
    if ps | grep "meilisearch" -q; then
        echo "${SUCCESS_LABEL}MeiliSearch started successfully and is importing the dump."
    else
        echo "${ERROR_LABEL}MeiliSearch could not start: \n ${BRED}$(cat logs)${NC}." >&2
        # In case of failed start rollback to initial version
        previous_version_rollback
    fi

    ## Wait for pending dump indexation
    until curl -X GET 'http://localhost:7700/health' -s >/dev/null; do
        echo "${PENDING_LABEL}MeiliSearch is still indexing the dump."
        sleep 2
    done

    echo "${SUCCESS_LABEL}MeiliSearch is done indexing the dump."
    # Kill local MeiliSearch process
    pkill meilisearch
    echo "${INFO_LABEL}Kill local MeiliSearch process."

    # Restart MeiliSearch
    systemctl restart meilisearch
    echo "${INFO_LABEL}MeiliSearch $meilisearch_version service is starting."
    # In case of failed restart rollback to initial version
    systemctl_status previous_version_rollback exit
    echo "${SUCCESS_LABEL}MeiliSearch $meilisearch_version service started succesfully."
fi

# Delete temporary files to leave the environment the way it was initially
delete_temporary_files

echo "${BGREEN}Migration complete. MeiliSearch is now in version ${NC} ${BPINK}$meilisearch_version${NC}."
