#!/bin/bash
#Date: 2021-01-04
#Author: DuYanbin
#Email: duyanbin@lvwan.com
#Version: 1.0

BASEDIR=$(cd $(dirname $0) ; pwd)
source $BASEDIR/env.sh


#Check Vendor and Product Name
function get_product_info() {
    if [[ $(systemd-detect-virt) == "docker" ]] ; then
	echo "容器(N/A)"
    else
        manufacturer=$(dmidecode -s system-manufacturer | tr ' ' '_')
        product_name=$(dmidecode -s system-product-name)
        echo ${manufacturer}"*"${product_name}
    fi
}


#Check Server Type
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


#Check OS Info
function get_os_info_by_redhat_file() {
    os_version=$(awk '{print $4}' /etc/redhat-release | awk -F'.' '{print $1"."$2}')
    os_name=$(awk '{print $1}' /etc/redhat-release)
    echo ${os_name}_${os_version}
}

function get_os_info_by_lsb_release() {
    os_name=$(lsb_release -a | grep 'Distributor ID' | awk -F'\t' '{print $2}')
    os_version=$(lsb_release -a | grep 'Release' | awk -F'\t' '{print $2}' | awk -F'.' '{print $1"."$2}')
    echo ${os_name}_${os_version}
}

function get_os_info() {
    which lsb_release > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        get_os_info_by_lsb_release
    elif [ -f /etc/redhat-release ] ; then
        get_os_info_by_redhat_file
    else
        echo "Unknown"
    fi
}

#Check CPU Info
function get_cpu_info() {
    cpu_model_name=$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c)
    cpu_logic_count=$(cat /proc/cpuinfo| grep "processor"| wc -l)
    echo ${cpu_logic_count}
}


#Check Memory Info
function get_memory_info_old() {
    if [[ $(systemd-detect-virt) == "none" ]] ; then
        memory_total=$(dmidecode|grep -P -A5 "Memory Device" |grep Size | grep -v No | awk '{sum+=$2} END {printf "%.0fG\n",sum/1024}')
    else
        memory_total=$(cat /proc/meminfo | grep 'MemTotal' | awk '{print $2}')"KB"
    fi
    echo ${memory_total}
}
   
function get_memory_info_docker() {
    total_mem=$(cat /proc/meminfo | grep 'MemTotal' | awk '{print $2}')
    echo $(trans_unit $((${total_mem}*1024)))
}

function get_memory_info() {
    if [[ $(systemd-detect-virt) == "docker" ]] ; then
	get_memory_info_docker
    else
	totalmem=0;
	for mem in /sys/devices/system/memory/memory*; do
	    [[ "$(cat ${mem}/online)" == "1" ]] \
	    && totalmem=$((totalmem+$((0x$(cat /sys/devices/system/memory/block_size_bytes)))));
	done
	echo $(trans_unit $totalmem)
    fi
}

#Check Disk Info
function trans_unit() {
    size=$1
    if ((size<1024)); then
        echo ${size}"B"
    elif ((size<1024*1024)); then
        echo $((size/1024))"KB"
    elif ((size<1024*1024*1024)); then
        echo $((size/1024/1024))"MB"
    elif ((size<1024*1024*1024*1024)); then
        echo $((size/1024/1024/1024))"GB"
    elif ((size<1024*1024*1024*1024*1024)); then
        echo $((size/1024/1024/1024/1024))"TB"
    fi
}

function trans_unit_raid() {
    hex_value=$1
    dec_value=$(echo "obase=10;ibase=16;$(echo ${hex_value} |tr [a-z] [A-Z])" | ${APP_DIR}/bc)
    if ((dec_value<1024*1024*2*1024)) ; then
	echo $(echo "${dec_value}/2*1024/1000/1000/1000" | ${APP_DIR}/bc)"GB"
    else
	echo $(echo "scale=1;(${dec_value}/2*1024/1000/1000/1000/1000)/1" | ${APP_DIR}/bc)"TB"
    fi
}

function get_all_disks() {
    #all_disks=$(ls /dev/sd* | grep -o 'sd[a-z]$' | xargs -n 1)
    all_disks=$(ls /dev/{sd,vd,xvd}* 2>/dev/null | grep -o -E '(sd|vd|xvd)[a-z]$' | xargs -n 1)
    echo "${all_disks}"
}

function get_disk_info() {
    if [[ $(systemd-detect-virt) == "docker" ]] ; then
	echo -n $(df -h | grep "/$" | awk '{print $2}')"_" 
	return 1
    fi		       
    all_disks=$(get_all_disks)
    for disk in ${all_disks} ; do
	disk_type_tag=$(cat /sys/block/$disk/queue/rotational)
	disk_size_half_bytes=$(blockdev --getsz /dev/$disk)
	if [[ ${disk_type_tag} == "1" ]] ; then
	    disk_type="SATA"
	else
	    disk_type="SSD"
	fi
	disk_size=$(trans_unit $((${disk_size_half_bytes}/2*1024)))
	echo -n "${disk_size}(${disk_type})_"
    done
}

function get_raid_info() {
    all_raid_info=$(${APP_DIR}/MegaCli64 -LdPdInfo -aALL)
    OLD_IFS=$IFS
    IFS=$'\n'
    all_vds=$(echo "${all_raid_info}" | grep 'Virtual Drive')
    [ -z "${all_vds}" ] && get_disk_info
    for vd in ${all_vds} ; do 
	result=$(echo "${all_raid_info}" | sed -n "/$vd/,/Raw Size.*/p")
	raid_level=$(echo "$result" | grep "RAID Level" | awk -F':' '{print $2}' | awk -F',' '{print $1}' | awk -F'-' '{print $2}')
	number_of_drivers=$(echo "$result" | grep "Number Of Drives" | awk -F':' '{print $2}' | tr -d ' ')
	pd_type=$(echo "$result" | grep "PD Type" | awk -F':' '{print $2}' | tr -d ' ')
	raw_size_hex=$(echo "$result" | grep "Raw Size" | sed -n 's/.*0x\(.*\) .*/\1/p')
	raw_size=$(trans_unit_raid ${raw_size_hex})
	#raw_size=$(echo "$result" | grep "Raw Size" | awk '{print $3$4}' | tr -d ' ')
	echo -n "${number_of_drivers}*${raw_size}(${pd_type} RAID${raid_level})_"
    done
    echo
    IFS=${OLD_IFS}
}


function run_io_test() {
    [ -d /data ] || mkdir /data  #For Test
    ${APP_DIR}/fio -filename=/data/testfile -direct=1 -iodepth 1 -thread -rw=randrw -rwmixread=70 -ioengine=psync -bs=16k -size=${FIO_OUTPUT_FILE_SIZE} -numjobs=20 -runtime=300 -group_reporting -name=mytest > ${IO_TEST_FILE}
}


function get_disk_io() {
    run_io_test
    rm -f /data/testfile
    read_iops=$(grep 'iops=' ${IO_TEST_FILE} | grep 'read' | awk -F',' '{print $3}' | awk -F'=' '{print $2}' | tr -d ' ')
    write_iops=$(grep 'iops=' ${IO_TEST_FILE} | grep 'write' | awk -F',' '{print $3}' | awk -F'=' '{print $2}' | tr -d ' ')
    echo "${read_iops} ${write_iops}"
}

#function get_disk_io() {
#    sleep 10
#    echo "2000 3000"
#}

#Check Network
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

#Check Ping Status
function run_iperf3() {
    #echo "${APP_DIR}/iperf3/lib" > ${APP_DIR}/iperf3/iperf3_lib.conf
    #ldconfig -f ${APP_DIR}/iperf3/iperf3_lib.conf
    [ -f  /tmp/iperf3.pid ] || ${APP_DIR}/iperf3 -s -D -I /tmp/iperf3.pid 
}

function get_bandwidth() {
    host=$1
    bandwidth=$(${APP_DIR}/iperf3 -c $host -t 10 -i 1 | grep sender | awk '{print $7$8}')
    echo "${bandwidth}"
}

function kill_iperf3() {
    [ -f /tmp/iperf3.pid ] && kill $(cat /tmp/iperf3.pid)
}

function main() {
    case $1 in 
	run_iperf3) 
		    run_iperf3
		    ;;
	kill_iperf3) 
		    kill_iperf3
		    ;;
	collect_bandwidth) 
		    get_bandwidth $2
		    ;;
	collect_disk_info) 
		    get_raid_info
		    ;;
	collect_raid_info) 
		    get_raid_info
		    ;;
	collect_io) 
		    get_disk_io
		    ;;
	collect_net) 
		    get_net_interface_info
		    ;;
	collect_all) 
		    rm -f /tmp/finished.tag
		    get_product_info
		    get_server_type
		    get_os_info
		    get_cpu_info
		    get_memory_info
		    get_net_interface_info
		    get_raid_info
		    get_disk_io
		    touch /tmp/finished.tag
		    ;;
	*) 
		    echo "Invalid command"
    esac
}

#Must run as root
if [ $(id -u) -ne 0 ] ; then
    echo "请使用root用户运行"
    exit
fi

#参数处理
if [ $# -ne 1 ] ; then
    if [ $# -eq 2 ] ; then
	if [[ $1 == 'collect_bandwidth' ]] ; then
	    cmd=$1
	    iperf_host=$2
	else
	    echo "Invalid except collect_bandwidth"
	    exit
	fi
    else 
        echo "Usage: $0 command"
        exit
    fi
else
    cmd=$1
fi

main $cmd ${iperf_host}
