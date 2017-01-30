#!/bin/bash

. /opt/rancher/common.sh

set -e

# environment variables
: ${GANESHA_EXPORT:="/"}
: ${GANESHA_PSEUDO_EXPORT:="/"}
: ${GANESHA_CONFIG:="/etc/ganesha/ganesha.conf"}
: ${GANESHA_LOGFILE:="/dev/stdout"}
: ${GANESHA_OPTIONS:="-N NIV_DEBUG"} # NIV_DEBUG, NIV_EVENT, NIV_WARN

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
EXPORT{
    Export_Id = 2;
    Path = "${EXPORT_1_PATH}";
    FSAL {
        name = VFS;
    }
    Access_type = RW;
    Disable_ACL = true;
    Pseudo = "/${EXPORT_1_NAME}";
    Squash = "No_Root_Squash";
    Protocols = "NFS4";
    SecType = "sys";
}
EXPORT{
    Export_Id = 3;
    Path = "${EXPORT_2_PATH}";
    FSAL {
        name = VFS;
    }
    Access_type = RW;
    Disable_ACL = true;
    Pseudo = "/${EXPORT_2_NAME}";
    Squash = "No_Root_Squash";
    Protocols = "NFS4";
    SecType = "sys";
}

END
}

sleep 0.5

ALLMETA=$(curl -sS -H 'Accept: application/json' ${META_URL})
EXPORT_1_NAME=$(echo ${ALLMETA} | jq -r '.self.service.metadata.export_1_name')
EXPORT_2_NAME=$(echo ${ALLMETA} | jq -r '.self.service.metadata.export_2_name')
EXPORT_BASE_PATH=$(echo ${ALLMETA} | jq -r '.self.service.metadata.export_base_path')
EXPORT_1_PATH="${EXPORT_BASE_PATH}/${EXPORT_1_NAME}"
EXPORT_2_PATH="${EXPORT_BASE_PATH}/${EXPORT_2_NAME}"

if [ ! -f ${EXPORT_1_PATH} ]; then
    mkdir -p "${EXPORT_1_PATH}"
fi
if [ ! -f ${EXPORT_2_PATH} ]; then
    mkdir -p "${EXPORT_2_PATH}"
fi

echo "initializing Ganesha NFS server"
echo "=================================="
echo "export 1 name: ${EXPORT_1_NAME}"
echo "export 1 path: ${EXPORT_1_PATH}"
echo "export 2 name: ${EXPORT_2_NAME}"
echo "export 2 path: ${EXPORT_2_PATH}"
echo "=================================="

bootstrap_config
init_rpc
init_dbus

echo "generated Ganesha-NFS config:"
cat ${GANESHA_CONFIG}

echo "* starting Ganesha-NFS"
exec /usr/bin/ganesha.nfsd -F -L ${GANESHA_LOGFILE} -f ${GANESHA_CONFIG} ${GANESHA_OPTIONS}
