#!/bin/bash

TCP_TIMEOUT=1
DAEMON_PORT=24007
HEALTH_CHECK_PORT=1620
META_URL="http://rancher-metadata/2015-07-25"
META_V2_URL="http://rancher-metadata/2015-12-19"

get_host_ip() {
    UUID=$(curl -sS -H 'Accept: application/json' ${META_URL}/containers/${1}|jq -r '.host_uuid')
    IP=$(curl -sS -H 'Accept: application/json' ${META_URL}/hosts |jq -r ".[] | select(.uuid==\"${UUID}\") | .agent_ip")
    echo ${IP}
}

get_host_name() {
    UUID=$(curl -sS -H 'Accept: application/json' ${META_URL}/containers/${1}|jq -r '.host_uuid')
    IP=$(curl -sS -H 'Accept: application/json' ${META_URL}/hosts |jq -r ".[] | select(.uuid==\"${UUID}\") | .name")
    echo ${IP}
}

get_container_primary_ip() {
    IP=$(curl -sS -H 'Accept: application/json' ${META_URL}/containers/${1}|jq -r .primary_ip)
    echo ${IP}
}

# service name in self stack as arg
get_service_primary_ip() {
    IP=$(curl -sS -H 'Accept: application/json' ${META_V2_URL}/self/stack/services/${1}/containers/0|jq -r .primary_ip)
    echo ${IP}
}

# service name as optional arg
wait_for_all_service_containers() {
    if [ -z "${1}" ]; then
        URI="${META_URL}/self/service"
    else
        URI="${META_V2_URL}/self/stack/services/${1}"
    fi

    SET_SCALE=$(curl -sS -H 'Accept: application/json' ${URI} | jq -r .scale)
    while [ "$(curl -sS -H 'Accept: application/json' ${URI} | jq '.containers |length')" -lt "${SET_SCALE}" ]; do
        sleep 1
    done    
}

# service name as arg
get_healthy_service_ip() {
    n=0
    until [ $n -ge 60 ]; do
        CONTAINER=$(curl -sS -H 'Accept: application/json' ${META_V2_URL}/self/stack/services/${1}/containers/0)
        STATE=$(echo ${CONTAINER} | jq -r '.health_state')
        if [ "$STATE" == "healthy" ]; then
            break
        fi
        n=$[$n+1]
        sleep 1
    done
    if [ "$STATE" != "healthy" ]; then
        echo ""
    fi
    IP=$(echo ${CONTAINER} | jq -r '.primary_ip')
    echo ${IP}
}

# IP as arg
wait_for_gluster_ip_healthy()
{
    ret=0
    giddyup probe -loop -t 3s --min 2s --num 120 http://${1}:${HEALTH_CHECK_PORT}/ping > /dev/null || ret=$?
    if [ "$ret" -ne "0" ]; then
        echo "Timed out waiting for gluster node ${1} to become healthy"
        exit 1
    fi
}
