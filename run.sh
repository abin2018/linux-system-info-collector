#!/bin/bash

#General Variables
BASE_DIR=$(cd $(dirname $0) ; pwd)
HOSTS_FILE=""
RESULT_DIR=$BASE_DIR/.result
IGNORE_HOSTS=$BASE_DIR/.ignore_hosts
OUTPUT_FORMAT="table"
LOG_DIR=$BASE_DIR/log
ERROR_LOG=${LOG_DIR}/running.log
PYTHON_EXEC=$(which python || which python2 || which python3)  # 设置python解释器
MAX_PROCESS_COUNT=5 #分发脚本和采集信息时最大允许同时允许的进程数

function prepare() {
    if [ -z "${HOSTS_FILE}" ] ; then
        HOSTS_FILE=$BASE_DIR/.empty
        touch ${HOSTS_FILE}
    fi
    ALL_HOSTS=$(cat ${HOSTS_FILE})
    ALL_HOSTS_ARRAY=(${ALL_HOSTS})
    ALL_HOSTS_ARRAY_INDEX=0
    HOSTS_COUNT=$(cat ${HOSTS_FILE} | wc -l)
    echo > ${IGNORE_HOSTS}
    [ -d ${RESULT_DIR} ] && rm -rf ${RESULT_DIR}
    mkdir ${RESULT_DIR}
    [ -d ${LOG_DIR} ] && rm -rf ${LOG_DIR}
    mkdir ${LOG_DIR}
}

function distribute_script() {
    host=$1
    scp -o ConnectTimeout=3 -r $BASE_DIR/scripts $host:/tmp/ &>/dev/null
    [ $? -ne 0 ] && { echo "$host connect failed: timeout" >> ${ERROR_LOG}; echo $host >> ${IGNORE_HOSTS}; }  #将失败的主机写入到一个文件中
}

function multi_process_running() {
    exec_function=$1
    local counter=0
    while ((counter < ${#ALL_HOSTS_ARRAY[@]})); do
        temp_host_list=($(echo ${ALL_HOSTS_ARRAY[@]:$counter:$MAX_PROCESS_COUNT}))
        for host in ${temp_host_list[@]} ; do 
            echo $host
            ${exec_function} $host &
        done
        wait
        echo "----------------"
        counter=$((counter+MAX_PROCESS_COUNT))
    done
    for host in $(cat ${IGNORE_HOSTS}); do
	ALL_HOSTS=$(echo "${ALL_HOSTS}" | grep -v $host)
        ALL_HOSTS_ARRAY=(${ALL_HOSTS})
    done
}

function clean_script() {
    host=$1
    ssh  -o ConnectTimeout=3 $host "rm -rf /tmp/scripts"
}

function running_script() {
    host=$1
    result_file=${RESULT_DIR}/$host.json
    rm -f ${result_file}
    ssh  -o ConnectTimeout=3 $host 'bash /tmp/scripts/run.sh get_json' >> ${result_file} 2>/dev/null
    [ $? -ne 0 ] && { echo "$host connect failed: timeout" >> ${ERROR_LOG}; echo $host >> ${IGNORE_HOSTS}; }  #将失败的主机写入到一个文件中
}

function usage() {
    cat <<eof
Usage: $0 [OPTION] [FILE]
options
  -f format                  set the output format, valid option is 'json' or 'table', default is 'table'
  -h hostfile                a text file that contains all hosts
eof
}

function args_parser() {
    while getopts ":f:h:" opt ; do
        case $opt in 
            f)
                OUTPUT_FORMAT=$OPTARG
                if echo ${OUTPUT_FORMAT} | grep -q '^-.*' ; then
                    usage
                    exit
                fi 
                if [[ ${OUTPUT_FORMAT} != 'json' ]] && [[ ${OUTPUT_FORMAT} != 'table' ]] ; then
                    echo "only json or table is supported"
                    exit
                fi
                ;;
            h) 
                HOSTS_FILE=$OPTARG
                if echo ${HOSTS_FILE} | grep -q '^-.*' ; then
                    usage
                    exit
                fi 
                if [ ! -f ${HOSTS_FILE} ] ; then
                    echo "load host file failed: ${HOSTS_FILE}: No such file"
                    exit
                fi
                ;;
            ?)
                usage
                exit
         esac
    done

}

function main() {
    if [ -z "${ALL_HOSTS}" ] ; then
        /bin/bash $BASE_DIR/scripts/run.sh get_json > ${RESULT_DIR}/localhost.json 2>/dev/null
        return 1
    else
        multi_process_running distribute_script
        echo "开始收集主机信息，请稍等 "
        multi_process_running running_script
        multi_process_running clean_script
    fi
}

args_parser "$@"
prepare
main
$PYTHON_EXEC $BASE_DIR/process_hosts_info.py ${OUTPUT_FORMAT}
