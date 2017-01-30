#!/bin/bash

. /opt/rancher/common.sh

set -e

echo "[volume_create] waiting for all service containers to start..."
giddyup service wait scale --timeout=600
echo "[volume_create] containers are coming up..."

STRINGIFY_OPTS=
ALLMETA=$(curl -sS -H 'Accept: application/json' ${META_URL})
VOLUME_NAME=$(echo ${ALLMETA} | jq -r '.self.service.metadata.volume_name')
WITH_PNFS=$(echo ${ALLMETA} | jq -r '.self.service.metadata.with_pnfs')
# TODO: derive the brick name from the stack-service name
BRICK_PATH="/data/glusterfs/brick1"
VOLUME_PATH="${BRICK_PATH}/${VOLUME_NAME}"
REPLICA_COUNT=$(giddyup service scale)

if [ ! -f ${VOLUME_PATH} ]; then
    mkdir -p "${VOLUME_PATH}"
fi

echo "[volume_create] checking if i am the leader..."

ret=0
giddyup leader check || ret=$?
if [ "$ret" -ne "0" ]; then
    echo "[volume_create] i am not the leader"
    sleep 5
    exit 0
fi

echo "[volume_create] i am the leader"
echo "[volume_create] waiting for all peers to join cluster..."
while true; do
    STATE_READY="true"
    for container in $(giddyup service containers -n); do
        IP=$(get_container_primary_ip ${container})
        if [ "$(($(gluster --remote-host=${IP} peer status | grep 'Peer in Cluster' | wc -l) + 1))" -ne "${REPLICA_COUNT}" ]; then
            echo "[volume_create] peer ${IP} is not ready yet"
            STATE_READY="false"
            break 1
        fi
    done

    if [ "${STATE_READY}" = "true" ]; then
        break 1
    fi
    sleep 5
done

echo "[volume_create] all peers have joined"

CONTAINER_MNTS=$(giddyup ip stringify --delimiter " " --suffix ":${VOLUME_PATH}" ${STRINGIFY_OPTS})

if [ "$(gluster volume info ${VOLUME_NAME} 2>&1 | grep 'does\ not\ exist' | wc -w)" -ne "0" ]; then
    echo "[volume_create] creating ${REPLICA_COUNT}x replicated volume ${VOLUME_NAME} in ${VOLUME_PATH}"
    gluster volume create ${VOLUME_NAME} replica ${REPLICA_COUNT} transport tcp ${CONTAINER_MNTS}
    sleep 5
    # Disable gluster built-in NFS
    gluster vol set ${VOLUME_NAME} nfs.disable on
    if [ "${WITH_PNFS,,}" = "true" ]; then
        echo "[volume_create] enabling support for pNFS"
        # Required for pNFS support
        gluster volume set ${VOLUME_NAME} features.cache-invalidation on
    fi
else
    echo "[volume_create] volume ${VOLUME_NAME} already exists"
fi

VOLUME_STATE=$(gluster volume info ${VOLUME_NAME}| grep ^Status | tr -d '[[:space:]]' | cut -d':' -f2)

if [ "$VOLUME_STATE" == "Created" ]; then
    echo "[volume_create] starting volume ${VOLUME_NAME}..."
    gluster volume start ${VOLUME_NAME}
    sleep 1
else
    if [ "$VOLUME_STATE" == "Started" ]; then
        echo "[volume_create] volume ${VOLUME_NAME} is already started"
    else
        echo "[volume_create] volume ${VOLUME_NAME} has unexpected state: ${VOLUME_STATE}"
        exit 1
    fi
fi

echo "[volume_create] volume info:"
echo "========================================================"
gluster volume info ${VOLUME_NAME}
echo "========================================================"
