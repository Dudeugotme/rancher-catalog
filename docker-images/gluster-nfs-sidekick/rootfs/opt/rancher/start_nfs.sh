#!/bin/bash

. /opt/rancher/common.sh

set -e

# environment variables
: ${GANESHA_EXPORT:="/"}
: ${GANESHA_PSEUDO_EXPORT:="/"}
: ${GANESHA_CONFIG:="/etc/ganesha/ganesha.conf"}
: ${GANESHA_LOGFILE:="/dev/stdout"}
: ${GANESHA_OPTIONS:="-N NIV_EVENT"} # NIV_DEBUG, NIV_EVENT, NIV_WARN

init_rpc() {
    echo "* starting rpcbind"
    if [ ! -x /run/rpcbind ] ; then
        install -m755 -g 32 -o 32 -d /run/rpcbind
    fi
    rpcbind || return 0
    rpc.statd -L || return 0
    rpc.idmapd || return 0
    sleep 1
}

init_dbus() {
    echo "* starting dbus"
    if [ ! -x /var/run/dbus ] ; then
        install -m755 -g 81 -o 81 -d /var/run/dbus
    fi
    rm -f /var/run/dbus/*
    rm -f /var/run/messagebus.pid
    dbus-uuidgen --ensure
    dbus-daemon --system --fork
    sleep 1
}

# About pNFS
# Ganesha by default is configured as pNFS DS.
# A full pNFS cluster consists of multiple DS
# and one MDS (Meta Data server). To implement
# this we need to deploy multiple Ganesha NFS
# and then configure one of them as MDS:
# GLUSTER { PNFS_MDS = ${WITH_PNFS}; }

bootstrap_config() {
    echo "* writing configuration"
    cat <<END >${GANESHA_CONFIG}

NFSV4 { Graceless = true; }
GLUSTER { PNFS_MDS = ${WITH_PNFS}; }
EXPORT{
    Export_Id = 2;
    Path = "${GANESHA_EXPORT}";
    FSAL {
        name = GLUSTER;
        hostname = "${GLUSTER_SERVICE_IP}";
        volume = "${VOLUME_NAME}";
    }
    Access_type = RW;
    Disable_ACL = true;
    Squash = "No_root_squash";
    Pseudo = "${GANESHA_PSEUDO_EXPORT}";
    #Protocols = "4";
    #Transports = "TCP";
    SecType = "sys";
}

END
}

sleep 0.5

GLUSTER_SERVICE_NAME="${1:?ERROR: Argument is required: Gluster service name}"
ALLMETA=$(curl -sS -H 'Accept: application/json' ${META_URL})
VOLUME_NAME=$(echo ${ALLMETA} | jq -r '.self.service.metadata.volume_name')
WITH_PNFS=$(echo ${ALLMETA} | jq -r '.self.service.metadata.with_pnfs')

echo "initializing Gluster NFS server"
echo "=================================="
echo "gluster service name: ${GLUSTER_SERVICE_NAME}"
echo "gluster volume: ${VOLUME_NAME}"
echo "nfs export: ${GANESHA_EXPORT}"
echo "=================================="

echo "waiting for gluster service to start up..."
wait_for_all_service_containers ${GLUSTER_SERVICE_NAME}

GLUSTER_SERVICE_IP=$(get_service_primary_ip ${GLUSTER_SERVICE_NAME})
echo "waiting for gluster node ${GLUSTER_SERVICE_IP} to become healthy..."
wait_for_gluster_ip_healthy ${GLUSTER_SERVICE_IP}

bootstrap_config
init_rpc
init_dbus

echo "generated Ganesha-NFS config:"
cat ${GANESHA_CONFIG}

echo "* starting Ganesha-NFS"
exec /usr/bin/ganesha.nfsd -F -L ${GANESHA_LOGFILE} -f ${GANESHA_CONFIG} ${GANESHA_OPTIONS}
