#!/bin/bash

#General Function
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


#Step 0: 提前准备好hosts文件以及做好ssh互信

#Step 1: 分发脚本文件
function distribute_script() {
    host=$1
    scp -o ConnectTimeout=3 -r $BASEDIR/scripts $host:/tmp/ &>/dev/null
    #[ $? -ne 0 ] && { echo "$host connect failed"; ALL_HOSTS=$(echo "${ALL_HOSTS}" | grep -v $host); }
    [ $? -ne 0 ] && { echo "$host connect failed"; echo $host >> ${IGNORE_HOSTS}; }  #将失败的主机写入到一个文件中
}

function distribute_scripts() {
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
    run_remote_cmd 'rm -rf /tmp/finished.tag ; rm -rf /tmp/scripts'
}

function run_remote_cmd() {
    for host in ${ALL_HOSTS} ; do 
        ssh -o ConnectTimeout=3 $host "$@"
    done
}

function call_run_remote_cmd() {
    for host in ${ALL_HOSTS} ; do 
	result_file=${RESULT_DIR}/$host.result
	rm -f ${result_file}
	echo "$host" >> ${result_file}
        ssh  -o ConnectTimeout=3 $host "$@" >> ${result_file} &
    done
    i=0
    ch=('|' '\' '-' '/')
    index=0
    while ps -ef | grep ssh | grep -q collect_all ; do 
	printf "%c%c%c%c%c\r" ${ch[$index]} ${ch[$index]} ${ch[$index]} ${ch[$index]} ${ch[$index]}
	((i++))
	index=$((i%4))
	sleep 0.5
    done
    wait
    echo
}

#Step 2: ssh远程执行脚本，获取信息
function call_iperf3_test() {
    for host in ${ALL_HOSTS} ; do
	if ((ALL_HOSTS_ARRAY_INDEX==((${#ALL_HOSTS_ARRAY[@]}-1)))); then
	    ALL_HOSTS_ARRAY_INDEX=0
	else
	    ((ALL_HOSTS_ARRAY_INDEX++))
	fi
	iperf_host=${ALL_HOSTS_ARRAY[${ALL_HOSTS_ARRAY_INDEX}]}
        bandwidth=$(ssh -o ConnectTimeout=3 $host "bash /tmp/scripts/check_system_info.sh collect_bandwidth ${iperf_host}")
	echo -e "$host\t-->\t$iperf_host\t$bandwidth"
    done
}


#Step 3: 处理收集到的信息并进行展示
distribute_scripts
echo "开始收集主机信息，请稍等 "
call_run_remote_cmd 'bash /tmp/scripts/check_system_info.sh collect_all'
python $BASEDIR/process_hosts_info.py
#echo "开始运行带宽测试..."
#run_remote_cmd 'bash /tmp/scripts/check_system_info.sh run_iperf3'
#call_iperf3_test
#run_remote_cmd 'bash /tmp/scripts/check_system_info.sh kill_iperf3'
clean_all
