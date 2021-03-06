#!/bin/bash

#General Variables
BASE_DIR=$(cd $(dirname $0) ; pwd)
HOSTS_FILE=""
SPECIFY_HOST_FILE=${BASE_DIR}/.tmp_hosts
RESULT_DIR=$BASE_DIR/.result
IGNORE_HOSTS=$BASE_DIR/.ignore_hosts
OUTPUT_FORMAT="table"
LOG_DIR=$BASE_DIR/log
ERROR_LOG=${LOG_DIR}/running.log
PYTHON_EXEC=$(which python 2>/dev/null || which python2 2>/dev/null \
	      || which python3 2>/dev/null)  # 设置python解释器
MAX_PROCESS_COUNT=20 #分发脚本和采集信息时最大允许同时允许的进程数
PROCESS_COUNT=5 #分发脚本和采集信息时默认的进程数
SSH_DEFAULT_OPTIONS="-o PasswordAuthentication=no -o BatchMode=yes \
	             -o ConnectTimeout=3 -o StrictHostKeyChecking=no"

function prepare() {
    if [ -z "${HOSTS_FILE}" ] ; then
        HOSTS_FILE=$BASE_DIR/.empty
        touch ${HOSTS_FILE}
    fi
    ALL_HOSTS=$(cat ${HOSTS_FILE})
    ALL_HOSTS_ARRAY=(${ALL_HOSTS})
    ALL_HOSTS_ARRAY_INDEX=0
    HOSTS_COUNT=$(cat ${HOSTS_FILE} | wc -l)
    [ -f ${IGNORE_HOSTS} ] && rm -f ${IGNORE_HOSTS}
    touch ${IGNORE_HOSTS}
    [ -d ${RESULT_DIR} ] && rm -rf ${RESULT_DIR}
    mkdir ${RESULT_DIR}
    [ -d ${LOG_DIR} ] && rm -rf ${LOG_DIR}
    mkdir ${LOG_DIR}
}

function ssh_error_handler() {
    host=$1
    error_info=$2
    if [ -n "${error_info}" ] ; then
        echo "$host: error: ${error_info}" >&2
        echo $host >> ${IGNORE_HOSTS}  #将失败的主机写入到一个文件中
    fi
}

function pre_checking() {
    host=$1
    error_info=$(ssh ${SSH_DEFAULT_OPTIONS} $host exit 2>&1 1>/dev/null)  #检查是否做了互相以及是否可达
    ssh_error_handler "$host" "${error_info}"
}

function distribute_script() {
    host=$1
    error_info=$(scp ${SSH_DEFAULT_OPTIONS} -r $BASE_DIR/scripts $host:/tmp/ &>/dev/null)
    ssh_error_handler "$host" "${error_info}"
}

function multi_process_running() {
    exec_function=$1
    local counter=0
    while ((counter < ${#ALL_HOSTS_ARRAY[@]})); do
        temp_host_list=($(echo ${ALL_HOSTS_ARRAY[@]:$counter:$PROCESS_COUNT}))
        for host in ${temp_host_list[@]} ; do 
            ${exec_function} $host 2>>${ERROR_LOG} &
        done
        wait
        counter=$((counter+PROCESS_COUNT))
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
    error_info=$(ssh ${SSH_DEFAULT_OPTIONS} $host 'bash /tmp/scripts/run.sh get_json' 2>&1 1>>${result_file})
    if ! echo ${error_info} | grep -q '.*#$'; then
        ssh_error_handler "$host" "${error_info}"
    else
        echo "${error_info}" | while read info ; do
            echo "$host: $(echo $info | tr -d '#')" >> ${ERROR_LOG}
        done
    fi
}

function running_result_count() {
    success_number=${#ALL_HOSTS_ARRAY[@]}
    fail_number=$(cat ${IGNORE_HOSTS} | wc -l)
    total_number=$((success_number+fail_number))
    echo -e "总计:${total_number}\t成功:${success_number}\t失败:${fail_number}\t运行日志:${ERROR_LOG}"
}

function usage() {
    cat <<eof
Usage: $0 [ARGS] [OPTION]
options
   ?                         show this help
  -f format                  set the output format, valid option is 'json' or 'table', default is 'table'
  -h hostfile                specify a text file that contains all hosts
  -s host                    specify a single host
  -c process_count           specify the process number running at the same time
eof
}

function args_parser() {
    if [[ $1 == '?' ]] ; then
        usage
    exit
    fi
    while getopts ":f:h:s:c:" opt ; do
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
            s) 
                SPECIFY_HOSTS=$OPTARG
                if echo ${HOSTS_FILE} | grep -q '^-.*' ; then
                    usage
                    exit
                fi 
                echo ${SPECIFY_HOSTS}> ${SPECIFY_HOST_FILE}
                HOSTS_FILE=${SPECIFY_HOST_FILE}
                ;;
            c) 
                _PROCESS_COUNT=$OPTARG
                if echo ${HOSTS_FILE} | grep -q '^-.*' ; then
                    usage
                    exit
                fi 
                if [[ ! ${_PROCESS_COUNT} =~ ^[0-9]+$ ]] ; then
                    echo "PROCESS_COUNT should be a positive number"
                    exit
                elif ((_PROCESS_COUNT > MAX_PROCESS_COUNT)) ; then
                    echo "PROCESS_COUNT should be less than ${MAX_PROCESS_COUNT}"
                    exit
                else
                    PROCESS_COUNT=${_PROCESS_COUNT}
                fi
                ;;
            ?)
                usage
                exit
         esac
    done
}

function python_output() {
    if [ -n "$PYTHON_EXEC" ] ; then
        $PYTHON_EXEC $BASE_DIR/process_hosts_info.py ${OUTPUT_FORMAT} ${HOSTS_FILE} 2>>${ERROR_LOG}
    else
        echo "No python found, output failed"
        return 1
    fi
}

function main() {
    if [ -z "${ALL_HOSTS}" ] ; then
        error_info=$(/bin/bash $BASE_DIR/scripts/run.sh get_json 2>&1 1>${RESULT_DIR}/localhost.json)
        if [ -n "${error_info}" ] ; then
            echo "${error_info}" | while read info ; do
                echo "localhost: $(echo $info | tr -d '#')" >> ${ERROR_LOG}
            done
        fi
        return 1
    else
        multi_process_running pre_checking
        multi_process_running distribute_script
        echo "开始收集主机信息，请稍等 "
        multi_process_running running_script
        multi_process_running clean_script
        echo "-------------------------------------------------------------------------------------------------------------------------"
        running_result_count
        echo "-------------------------------------------------------------------------------------------------------------------------"
    fi
}

args_parser "$@"
prepare
main
python_output
