#!/bin/bash
# Date: 2021-01-04
# Author: Eric
# Email: yanghigh@163.com
# Version: 1.0

BASEDIR=$(cd $(dirname $0) ; pwd)
source $BASEDIR/functions.sh
source $BASEDIR/env.sh
source $BASEDIR/extend.sh


# Check Vendor and Product Name
function get_product_info() {
    sys_vendor=$(cat /sys/class/dmi/id/sys_vendor | tr ' ' '-')
    product_name=$(cat /sys/class/dmi/id/product_name | tr ' ' '-')
    echo "${sys_vendor}"#"${product_name}"
}

# Check Kernel Info
function get_kernel_info() {
    kernel_version=$(cat /proc/version | awk '{print $3}')
    echo ${kernel_version}
}

# Check CPU Info
function get_cpu_info() {
    cpu_model_name=$(grep 'model name' /proc/cpuinfo | uniq | awk -F': ' '{print $2}' | tr ' ' '_')
    cpu_physical_count=$(grep 'physical id' /proc/cpuinfo | uniq | wc -l)
    cpu_cores_count=$(grep 'cpu cores' /proc/cpuinfo | awk -F': ' '{print $2}')
    cpu_processor_count=$(grep "processor" /proc/cpuinfo | wc -l)
    echo "${cpu_model_name}#${cpu_physical_count}#${cpu_cores_count}#${cpu_processor_count}"
}

# Check Memory Info
function get_memory_info() {
    total_mem=0;
    for mem in /sys/devices/system/memory/memory*; do
	if [[ "$(cat ${mem}/online)" == "1" ]] ; then
	    total_mem=$((total_mem+$((0x$(cat /sys/devices/system/memory/block_size_bytes)))));
	fi
    done
    echo $(bytes_unit_trans $total_mem)
}

# Check Disk Info
function get_disk_info() {
    all_disks=$(ls /sys/block/ | grep -o -E "${DISK_INCLUDE_PATTERN}")
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
	echo -n "$disk:${disk_size}:${disk_type}#"
    done
    echo
}

# Check Network
function get_net_interface_info() {
    for interface in $(ls /sys/class/net/ | xargs -n 1 | grep -Ev "${NET_EXCLUDE_PATTERN}") ; do 
	carrier_file=/sys/class/net/$interface/carrier
	if [[ -f ${carrier_file} ]] && [[ $(cat ${carrier_file} 2>/dev/null) -eq 1 ]]; then
	    speed=$(cat /sys/class/net/$interface/speed 2>/dev/null)
	    [ -z "$speed" ] && speed="--"
	    echo -n "$interface:${speed}Mb/s#"
	fi
    done
    echo
}

#Output function
function output_json() {
    arr_element_counter=1
    echo "{"
    product_info=($(string_splitter "$(get_product_info)"))
    echo "    \"product_info\": {\"sys_vendor\": \"${product_info[0]}\", \"product_name\": \"${product_info[1]}\"},"
    server_type=$(get_server_type)
    echo "    \"server_type\": \"${server_type}\","
    os_info=$(get_dist_info)
    echo "    \"os_info\": \"${os_info}\","
    cpu_info=($(string_splitter $(get_cpu_info)))
    echo "    \"cpu_info\": {\"model_name\": \"${cpu_info[0]}\", \"cpu_physical_count\": \"${cpu_info[1]}\", 
                 \"cpu_cores_count\": \"${cpu_info[2]}\", \"cpu_processor_count\": \"${cpu_info[3]}\"},"
    memory_info=$(get_memory_info)
    echo "    \"memory_info\": \"${memory_info}\","
    cpu_info=($(string_splitter $(get_cpu_info)))
    net_interface_info=($(string_splitter $(get_net_interface_info)))
    echo -n "    \"net_interface_info\": ["
    for net in ${net_interface_info[@]}; do
	net_info=($(string_splitter "$net" ":"))
	if [[ ${arr_element_counter} -eq ${#net_interface_info[@]} ]] ; then
	    echo -n "{\"interface_name\": \"${net_info[0]}\", \"interface_speed\": \"${net_info[1]}\"}"
	else
	    echo -n "{\"interface_name\": \"${net_info[0]}\", \"interface_speed\": \"${net_info[1]}\"}, "
	fi
	((arr_element_counter++))
    done
    echo "],"
    arr_element_counter=1
    disk_info=($(string_splitter $(get_disk_info)))
    echo -n "    \"disk_info\": ["
    for disk in ${disk_info[@]}; do
	disk_info_single=($(string_splitter "$disk" ":"))
	if [[ ${arr_element_counter} -eq ${#disk_info[@]} ]] ; then
	    echo -n "{\"disk_name\": \"${disk_info_single[0]}\", \"disk_size\": \"${disk_info_single[1]}\", \"disk_type\": \"${disk_info_single[2]}\"}"
	else
	    echo -n "{\"disk_name\": \"${disk_info_single[0]}\", \"disk_size\": \"${disk_info_single[1]}\", \"disk_type\": \"${disk_info_single[2]}\"}, "
        fi
	((arr_element_counter++))
    done
    echo "]"
    arr_element_counter=1
    echo "}"
}

# Usage function
function usage() {
    echo -e "Usage: bash $0 command
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
	get_kernel_info) 
		    get_kernel_info
		    ;;
	get_server_type) 
		    get_server_type
		    ;;
	get_dist_info) 
		    get_dist_info
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
	get_json) 
		    output_json
		    ;;
	get_all) 
		    get_product_info
		    get_kernel_info
		    get_server_type
		    get_dist_info
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
