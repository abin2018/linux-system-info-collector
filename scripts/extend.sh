#!/bin/bash

# Check Distribute Info
function get_dist_by_rhrelease() {
    echo $(cat /etc/redhat-release)
}

function get_dist_by_issue() {
    echo $(cat /etc/issue | head -1 | awk '{print $1" "$2" "$3}')
}

function get_dist_by_osrelease() {
    echo $(cat /etc/os-release | grep "PRETTY_NAME" | awk -F'=' '{print $2}' | tr -d '"')
}

function get_dist_info() {
    if [ -f /etc/redhat-release ] ; then
        get_dist_by_rhrelease
    elif [ -f /etc/os-release ] ; then
        get_dist_by_osrelease
    elif [ -f /etc/issue ] ; then
        get_dist_by_issue
    else
        echo "Unknown"
    fi
}

# Check Server Type
function get_server_type() {
    virtual_check_result=$(systemd-detect-virt)
    if [[ ${virtual_check_result} == "none" ]] ; then
        echo "物理机"
    elif [[ ${virtual_check_result} == "docker" ]] ; then
        echo "Docker"
    else
        echo "虚拟机(${virtual_check_result})"
    fi
}

