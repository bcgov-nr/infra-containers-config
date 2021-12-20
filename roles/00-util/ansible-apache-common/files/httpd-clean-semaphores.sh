#!/bin/bash

# Get active and inactive httpd instances - generally we assume all instances should be active,
# but maybe some are not running intentionally so we will only start the ones that were running
# before semaphore cleanup.

ALL_HTTPD_INSTANCES=()
ACTIVE_HTTPD_INSTANCES=()
INACTIVE_HTTPD_INSTANCES=()

# for loop range is based on expecting httpdXX instances on a server, where
# it is unlikely we have any more than 10 httpd instances (httpd01, httpd02, ...).
for i in {01..10}
do
    HTTPD_INSTANCE="httpd$i"
    #echo "$HTTPD_INSTANCE $(systemctl is-active $HTTPD_INSTANCE)"
    if [ "$(systemctl is-active $HTTPD_INSTANCE)" = "active" ]; then
        ALL_HTTPD_INSTANCES+=($HTTPD_INSTANCE)
        ACTIVE_HTTPD_INSTANCES+=($HTTPD_INSTANCE)
    elif [ "$(systemctl is-active $HTTPD_INSTANCE)" = "inactive" ]; then
        ALL_HTTPD_INSTANCES+=($HTTPD_INSTANCE)
        INACTIVE_HTTPD_INSTANCES+=($HTTPD_INSTANCE)
    fi
done

# for debug - echo array contents if necessary
#echo "ALL: ${ALL_HTTPD_INSTANCES[@]}"
#echo "ACTIVE: ${ACTIVE_HTTPD_INSTANCES[@]}"
#echo "INACTIVE: ${INACTIVE_HTTPD_INSTANCES[@]}"


echo "==========================================================="
echo "HTTPD semaphore cleanup for wwwsvr"
echo "==========================================================="


# Show status of httpd instances and semaphore count for wwwsvr

if [ ${#ALL_HTTPD_INSTANCES[@]} -ne 0 ]; then
    echo "Status of httpd instances..."
    for instance in "${ALL_HTTPD_INSTANCES[@]}"
    do
        echo "$instance $(systemctl is-active $instance)"
    done
    echo "Semaphore count for wwwsvr: $(ipcs -s | grep wwwsvr | wc -l)"
else
    echo "No active or inactive httpdXX instances found on server."
fi


echo "==========================================================="


# Stop active httpd instances

if [ ${#ACTIVE_HTTPD_INSTANCES[@]} -ne 0 ]; then
    echo "Stopping active httpd instances..."
    for instance in "${ACTIVE_HTTPD_INSTANCES[@]}"
    do
        sudo systemctl stop "$instance"
    done
    echo "Done stopping active httpd instances."
else
    echo "No httpd instances to stop since none are active."
fi


echo "==========================================================="


# Show status of httpd instances

if [ ${#ALL_HTTPD_INSTANCES[@]} -ne 0 ]; then
    echo "Status of httpd instances..."
    for instance in "${ALL_HTTPD_INSTANCES[@]}"
    do
        echo "$instance $(systemctl is-active $instance)"
    done
else
    echo "No httpdXX instances found."
fi


echo "==========================================================="


# Confirm that all httpd instances are stopped/inactive and cleanup semaphores if yes

ALL_HTTPD_INSTANCES_STOPPED=true
if [ ${#ALL_HTTPD_INSTANCES[@]} -ne 0 ]; then
    echo "Confirming that all httpd instances are stopped/inactive..."
    for instance in "${ALL_HTTPD_INSTANCES[@]}"
    do
        if [ "$(systemctl is-active $instance)" = "active" ]; then
            ALL_HTTPD_INSTANCES_STOPPED=false
        fi
    done
    if [ ALL_HTTPD_INSTANCES_STOPPED = false ]; then
        echo "Oops, some httpd instances are not stopped/inactive, semaphore cleanup might not work."
    else
        echo "Yes, all httpd instances are stopped/inactive. Cleaning wwwsvr semaphores now..."

        # command without quote escaping if running manually as wwwsvr user:
        # ipcs -s | awk -v user=wwwsvr '$3==user {system("ipcrm -s "$2)}'

        # escaped command for bash script
        sudo -u wwwsvr bash -c $'ipcs -s | awk -v user=wwwsvr \'$3==user {system("ipcrm -s "$2)}\''

        echo "wwwsvr semaphores cleaned up, count is now $(ipcs -s | grep wwwsvr | wc -l)"
    fi
else
    echo "No httpdXX instances found on the server."
fi


echo "==========================================================="


# Start previously active httpd instances - we'll start the ones that were active before the cleanup in case
# some were stopped intentionally.

if [ ${#ACTIVE_HTTPD_INSTANCES[@]} -ne 0 ]; then
    echo "Starting previously active httpd instances..."
    for instance in "${ACTIVE_HTTPD_INSTANCES[@]}"
    do
        sudo systemctl start "$instance"
    done
    echo "In progress or done starting previously active httpd instances."
else
    echo "No httpd instances to start since none were active before cleanup."
fi


echo "==========================================================="


# sleep for a few seconds before checking final status of httpd instances
sleep 10

# Show status of httpd instances

if [ ${#ALL_HTTPD_INSTANCES[@]} -ne 0 ]; then
    echo "Status of httpd instances..."
    for instance in "${ALL_HTTPD_INSTANCES[@]}"
    do
        echo "$instance $(systemctl is-active $instance)"
    done
    echo "Semaphore count for wwwsvr after httpd startup: $(ipcs -s | grep wwwsvr | wc -l)"
else
    echo "No httpdXX instances found."
fi

echo "==========================================================="
