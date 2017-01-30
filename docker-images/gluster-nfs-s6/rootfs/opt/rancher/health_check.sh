#!/bin/bash

. /opt/rancher/common.sh

VOLUME_NAME=$(curl -sS -H 'Accept: application/json' ${META_URL}/self/service/metadata | jq -r '.volume_name')
REPLICA_COUNT=$(giddyup service scale)

# check peer status
gluster peer status | grep State | grep "Disconnected" >> /dev/null 2>&1
if [ "$?" -eq 0 ]; then
    echo "[health_check] at least one peer is disconnected" >&2
    exit 1
fi

# check volume state
gluster volume info ${VOLUME_NAME} 2>&1 | grep Status | grep "Started" > /dev/null
if [ "$?" -ne "0" ]; then
    echo "[health_check] volume ${VOLUME_NAME} is not started" >&2
    exit 1
fi

# check if all volume processes are online
# issue: concurrent requests result in
# stdout being flooded with error:
# "could not acquire lock"
expected=$(($REPLICA_COUNT * 2))
# disabling this for now
# actual=$(gluster volume status ${VOLUME_NAME} 2>&1 | grep "Y" | wc -l)
actual=$(($REPLICA_COUNT * 2))
if [ "$actual" -lt "$expected" ]; then
    echo "[health_check] volume ${VOLUME_NAME} is not fully online" >&2
    exit 1
fi

exit 0
