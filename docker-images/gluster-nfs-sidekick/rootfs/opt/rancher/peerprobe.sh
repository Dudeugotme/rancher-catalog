#!/bin/bash

. /opt/rancher/common.sh

peer_wait_hosts()
{
    echo "[peer_probe] waiting for all gluster daemons to come up..."
    ready=false
    while [ "$ready" != true ]; do
        sleep 5
        ready=true
        for peer in $(giddyup service containers -n); do
            IP=$(get_container_primary_ip ${peer})
            giddyup probe --timeout ${TCP_TIMEOUT}s tcp://$IP:$DAEMON_PORT > /dev/null
            if [ "$?" -ne "0" ]; then
                echo "[peer_probe] gluster daemon $peer is not ready"
                ready=false
            fi
        done
    done
}

peer_probe_hosts()
{
    for peer in $(giddyup service containers --exclude-self -n);do
        IP=$(get_container_primary_ip ${peer})
        echo "[peer_probe] probing peer ${IP}"
        gluster peer probe ${IP}
        sleep .5
    done

    echo "[peer_probe] current pool list:"
    echo "========================================================"
    gluster pool list
    echo "========================================================"
}

peer_probe()
{
    while true; do
        PEER_COUNT=$(gluster pool list|grep -v UUID|wc -l)
        if [ "$(giddyup service scale)" -ne "${PEER_COUNT}" ]; then
            echo "[peer_probe] *unprobed nodes detected*"
            peer_probe_hosts
        fi
        sleep 15
    done
}

echo "[peer_probe] waiting for all service containers to start..."
giddyup service wait scale --timeout=600
peer_wait_hosts
peer_probe
