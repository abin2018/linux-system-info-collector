#!/bin/bash
# Date: 2021-01-04
# Author: Eric
# Email: yanghigh@163.com
# Version: 1.0

BASEDIR=$(cd $(dirname $0) ; pwd)
source $BASEDIR/functions.sh
source $BASEDIR/env.sh


# Check Vendor and Product Name
function get_product_info() {
    sys_vendor=$(cat /sys/class/dmi/id/sys_vendor)
    product_name=$(cat /sys/class/dmi/id/product_name)
    product_serial=$(cat /sys/class/dmi/id/product_serial)
    product_uuid=$(cat /sys/class/dmi/id/product_uuid)
    echo ${sys_vendor} ${product_name} ${product_serial} ${product_uuid}
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

# Check OS Info
function get_os_info() {
    os_version=$(awk '{print $4}' /etc/redhat-release | awk -F'.' '{print $1"."$2}')
    os_name=$(awk '{print $1}' /etc/redhat-release)
    echo ${os_name}_${os_version}
}

# Check CPU Info
function get_cpu_info() {
    cpu_model_name=$(grep 'model name' /proc/cpuinfo | uniq | awk -F': ' '{print $2}')
    cpu_physical_count=$(grep 'physical id' /proc/cpuinfo | uniq | wc -l)
    cpu_cores_count=$(grep 'cpu cores' /proc/cpuinfo | awk -F': ' '{print $2}')
    cpu_processor_count=$(grep "processor" /proc/cpuinfo | wc -l)
    echo "${cpu_model_name} ${cpu_physical_count}*${cpu_cores_count}(${cpu_processor_count})"
}

# Check Memory Info
function get_memory_info() {
    total_mem=0;
    for mem in /sys/devices/system/memory/memory*; do
	if [[ "$(cat ${mem}/online)" == "1" ]] ; then
	    total_mem=$((totalmem+$((0x$(cat /sys/devices/system/memory/block_size_bytes)))));
	fi
    done
    echo $(bytes_unit_trans $total_mem)
}

# Check Disk Info
function get_disk_info() {
    all_disks=$(ls /sys/block/ | grep -o -E "${DISK_PATTERN}")
    for disk in ${all_disks} ; do
	disk_type_tag=$(cat /sys/block/$disk/queue/rotational)
	disk_sectors=$(cat /sys/block/$disk/size)
	disk_sector_size=$(cat /sys/block/$disk/queue/hw_sector_size)
	if [[ ${disk_type_tag} == "1" ]] ; then
	    disk_type="SATA"
	else
	    disk_type="SSD"
	fi
	disk_size=$(bytes_unit_trans $((${disk_sectors}*${disk_sector_size})))
	echo -n "${disk_size}(${disk_type}) "
    done
    echo
}

# Check Network
function get_net_interface_info() {
    for interface in $(ls /sys/class/net/ | xargs -n 1 | grep -Ev 'lo') ; do 
	carrier_file=/sys/class/net/$interface/carrier
	if [[ -f ${carrier_file} ]] && [[ $(cat ${carrier_file} 2>/dev/null) -eq 1 ]]; then
	    speed=$(cat /sys/class/net/$interface/speed 2>/dev/null)
	    [ -z "$speed" ] && speed="--"
	    echo -n "$interface(${speed}Mb/s) "
	fi
    done
    echo
}

# Usage function
function usage() {
    echo -e "Usage: sh $0 command
-----------------------------------
Valid command:
    get_product_info
    get_server_type 
    get_os_info 
    get_cpu_info 
    get_memory_info
    get_net_interface_info
    get_disk_info
    get_all"
}


# Main function
function main() {
    case $1 in 
	get_product_info) 
		    get_product_info
		    ;;
	get_server_type) 
		    get_server_type
		    ;;
	get_os_info) 
		    get_os_info
		    ;;
	get_cpu_info) 
		    get_cpu_info
		    ;;
	get_memory_info) 
		    get_memory_info
		    ;;
	get_net_interface_info) 
		    get_net_interface_info
		    ;;
	get_disk_info) 
		    get_disk_info
		    ;;
	get_all) 
		    get_product_info
		    get_server_type
		    get_os_info
		    get_cpu_info
		    get_memory_info
		    get_net_interface_info
		    get_disk_info
		    ;;
	*) 
		    usage
    esac
}

# Main
if [ $#  -ne 1 ] ; then
    usage
else
    cmd=$1
    main $cmd 
fi
