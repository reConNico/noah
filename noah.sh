#!/bin/bash

# --------------------------------------------------------------------------------------------------
# Copyright (c) Brian Faust <hello@brianfaust.me>
# --------------------------------------------------------------------------------------------------

if [[ $BASH_VERSINFO < 4 ]]; then
    echo "Sorry, you need at least bash-4.0 to run this script."
    exit 1
fi

# --------------------------------------------------------------------------------------------------
# Initialization
# --------------------------------------------------------------------------------------------------

PATH="$HOME/.nvm/versions/node/v6.9.5/bin:$PATH"
export PATH

# --------------------------------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------------------------------

USER=$(whoami)

# --------------------------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------------------------

CURRENT_DIRECTORY=$(pwd)

if [ ! -f "$CURRENT_DIRECTORY/noah.conf" ]; then
    cp "$CURRENT_DIRECTORY/noah.conf.example" "$CURRENT_DIRECTORY/noah.conf";
fi

if [[ -e "$CURRENT_DIRECTORY/noah.conf" ]]; then
    . "$CURRENT_DIRECTORY/noah.conf"
fi

# --------------------------------------------------------------------------------------------------
# Day / Night Handling of Triggers
# --------------------------------------------------------------------------------------------------

TRIGGER_METHOD_NOTIFY=true  # notify if we have a match in the log...
TRIGGER_METHOD_REBUILD=true # rebuild if we have a match in the log...

if [[ $NIGHT_MODE_ENABLED = true ]]; then
    NIGHT_MODE_CURRENT_HOUR=$(date +"%H")

    if [ ${NIGHT_MODE_CURRENT_HOUR} -ge ${NIGHT_MODE_END} -a ${NIGHT_MODE_CURRENT_HOUR} -le ${NIGHT_MODE_START} ]; then
        # Day
        TRIGGER_METHOD_NOTIFY=true
        TRIGGER_METHOD_REBUILD=false
    else
        # Night
        TRIGGER_METHOD_NOTIFY=false
        TRIGGER_METHOD_REBUILD=true
    fi
fi

# --------------------------------------------------------------------------------------------------
# Functions - ARK Node
# --------------------------------------------------------------------------------------------------

node_start() {
    cd ${DIRECTORY_ARK}
    forever start app.js --genesis genesisBlock.${NETWORK}.json --config config.${NETWORK}.json >&- 2>&-
}

node_stop() {
    cd ${DIRECTORY_ARK}
    forever stop ${PROCESS_FOREVER} >&- 2>&-
}

# --------------------------------------------------------------------------------------------------
# Processes
# --------------------------------------------------------------------------------------------------

PROCESS_POSTGRES=$(pgrep -a "postgres" | awk '{print $1}')
PROCESS_ARK_NODE=$(pgrep -a "node" | grep ark-node | awk '{print $1}')

if [ -z "$PROCESS_ARK_NODE" ]; then
    node_start
fi

PROCESS_FOREVER=$(forever --plain list | grep ${PROCESS_ARK_NODE} | sed -nr 's/.*\[(.*)\].*/\1/p')

# --------------------------------------------------------------------------------------------------
# Functions - Notifications
# --------------------------------------------------------------------------------------------------

notify_via_log() {
    CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

    printf "[$CURRENT_DATETIME] $1\n" >> $NOTIFICATION_LOG
}

notify_via_email() {
    CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$CURRENT_DATETIME] $1" | mail -s "$NOTIFICATION_EMAIL_SUBJECT" "$NOTIFICATION_EMAIL_TO"
}

notify_via_sms() {
    CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

    curl -X "POST" "https://rest.nexmo.com/sms/json" \
      -d "from=$NOTIFICATION_SMS_FROM" \
      -d "text=[$CURRENT_DATETIME] $1" \
      -d "to=$NOTIFICATION_SMS_TO" \
      -d "api_key=$NOTIFICATION_SMS_API_KEY" \
      -d "api_secret=$NOTIFICATION_SMS_API_SECRET"
}

notify_via_pushover() {
    CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

    curl -s -F "token=$NOTIFICATION_PUSHOVER_TOKEN" \
        -F "user=$NOTIFICATION_PUSHOVER_USER" \
        -F "title=$NOTIFICATION_PUSHOVER_TITLE" \
        -F "message=[$CURRENT_DATETIME] $1" https://api.pushover.net/1/messages.json
}

notify_via_slack() {
    CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$CURRENT_DATETIME] $1" | $NOTIFICATION_SLACK_SLACKTEE -c "$NOTIFICATION_SLACK_CHANNEL" -u "$NOTIFICATION_SLACK_FROM" -i "$NOTIFICATION_SLACK_ICON"
}

notify() {
    for driver in "${NOTIFICATION_DRIVER[@]}"
    do
        case $driver in
        "LOG")
            notify_via_log "$1"
            ;;
        "EMAIL")
            notify_via_email "$1"
            ;;
        "SMS")
            notify_via_sms "$1"
            ;;
        "SLACK")
            notify_via_slack "$1"
            ;;
        "NONE")
            :
            ;;
        *)
            notify_via_log "$1"
            ;;
        esac
    done
}

# --------------------------------------------------------------------------------------------------
# Functions - Database
# --------------------------------------------------------------------------------------------------

database_drop_user() {
    if [ -z "$PROCESS_POSTGRES" ]; then
        sudo service postgresql start
    fi

    sudo -u postgres dropuser --if-exists $USER
}

database_destroy() {
    if [ -z "$PROCESS_POSTGRES" ]; then
        sudo service postgresql start
    fi

    dropdb --if-exists ark_${NETWORK}
}

database_create() {
    if [ -z "$PROCESS_POSTGRES" ]; then
        sudo service postgresql start
    fi

    sleep 1
    sudo -u postgres psql -c "update pg_database set encoding = 6, datcollate = 'en_US.UTF8', datctype = 'en_US.UTF8' where datname = 'template0';" >&- 2>&-
    sudo -u postgres psql -c "update pg_database set encoding = 6, datcollate = 'en_US.UTF8', datctype = 'en_US.UTF8' where datname = 'template1';" >&- 2>&-
    sudo -u postgres psql -c "CREATE USER $USER WITH PASSWORD 'password' CREATEDB;" >&- 2>&-
    sleep 1
    createdb ark_${NETWORK}
}

# --------------------------------------------------------------------------------------------------
# Functions - Snapshots
# --------------------------------------------------------------------------------------------------

snapshot_download() {
    rm ${DIRECTORY_SNAPSHOT}/current
    wget -nv ${SNAPSHOT_SOURCE} -O ${DIRECTORY_SNAPSHOT}/current
}

snapshot_restore() {
    if [ -z "$PROCESS_POSTGRES" ]; then
        sudo service postgresql start
    fi

    pg_restore -O -j 8 -d ark_${NETWORK} ${DIRECTORY_SNAPSHOT}/current 2>/dev/null
}

# --------------------------------------------------------------------------------------------------
# Functions - Rebuild
# --------------------------------------------------------------------------------------------------

rebuild() {
    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Stopping ARK Process...";
    fi

    node_stop

    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Dropping Database User...";
    fi

    database_destroy

    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Dropping Database...";
    fi

    database_drop_user

    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Creating Database...";
    fi

    database_create

    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Downloading Current Snapshot...";
    fi

    snapshot_download

    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Restoring Database...";
    fi

    snapshot_restore

    if [[ $TRIGGER_METHOD_NOTIFY = true ]]; then
        notify "Starting ARK Process...";
    fi

    node_start
}

# --------------------------------------------------------------------------------------------------
# Functions - Observe
# --------------------------------------------------------------------------------------------------

observe() {
    while true;
    do
        if tail -2 $FILE_ARK_LOG | grep -q "Blockchain not ready to receive block";
        then
            # Day >>> Only Notify
            if [[ $TRIGGER_METHOD_NOTIFY = true && $TRIGGER_METHOD_REBUILD = false ]]; then
                notify "ARK Node out of sync - Rebuild required...";
            fi

            # Night >>> Only Rebuild
            if [[ $TRIGGER_METHOD_REBUILD = true ]]; then
                rebuild
            fi

            sleep $WAIT_BETWEEN_REBUILD

            break
        fi

        # Reduce CPU Overhead
        sleep $WAIT_BETWEEN_LOG_CHECK
    done
}

# --------------------------------------------------------------------------------------------------
# Parse Arguments and Start
# --------------------------------------------------------------------------------------------------

if [[ "$#" -eq "0" ]]; then
    observe
else
    rebuild
fi
