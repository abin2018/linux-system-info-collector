#!/bin/bash

#General Variables
BASEDIR=$(cd $(dirname $0) ; pwd)
HOSTS_FILE=$BASEDIR/hosts
RESULT_DIR=$BASEDIR/.result
IGNORE_HOSTS=$BASEDIR/.ignore_hosts

[ -f ${HOSTS_FILE} ] || touch ${HOSTS_FILE}
[ -d ${RESULT_DIR} ] && rm -rf ${RESULT_DIR}
mkdir ${RESULT_DIR}

ALL_HOSTS=$(cat ${HOSTS_FILE})
ALL_HOSTS_ARRAY=(${ALL_HOSTS})
ALL_HOSTS_ARRAY_INDEX=0
HOSTS_COUNT=$(cat ${HOSTS_FILE} | wc -l)

function distribute_script() {
    host=$1
    scp -o ConnectTimeout=3 -r $BASEDIR/scripts $host:/tmp/ &>/dev/null
    [ $? -ne 0 ] && { echo "$host connect failed"; echo $host >> ${IGNORE_HOSTS}; }  #将失败的主机写入到一个文件中
}

function distribute_all_scripts() {
    echo > ${IGNORE_HOSTS}
    for host in ${ALL_HOSTS} ; do 
        distribute_script $host &
    done
    wait
    for host in $(cat ${IGNORE_HOSTS}); do
	ALL_HOSTS=$(echo "${ALL_HOSTS}" | grep -v $host)
    done
}

function clean_all() {
    for host in ${ALL_HOSTS} ; do 
        ssh  -o ConnectTimeout=3 $host "rm -rf /tmp/scripts"
    done
}


function call_run_remote_cmd() {
    for host in ${ALL_HOSTS} ; do 
	result_file=${RESULT_DIR}/$host.result
	rm -f ${result_file}
	echo "$host" >> ${result_file}
        ssh  -o ConnectTimeout=3 $host "$@" >> ${result_file} &
    done
    wait
}

distribute_all_scripts
echo "开始收集主机信息，请稍等 "
call_run_remote_cmd 'bash /tmp/scripts/check_system_info.sh get_all'
#python $BASEDIR/process_hosts_info.py
clean_all
