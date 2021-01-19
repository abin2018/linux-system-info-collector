#!/bin/bash

#General Variables
BASE_DIR=$(cd $(dirname $0) ; pwd)
HOSTS_FILE=""
RESULT_DIR=$BASE_DIR/.result
IGNORE_HOSTS=$BASE_DIR/.ignore_hosts
OUTPUT_FORMAT="table"
LOG_DIR=$BASE_DIR/log

function prepare() {
    if [ -z "${HOSTS_FILE}" ] ; then
        HOSTS_FILE=$BASE_DIR/.empty
        touch ${HOSTS_FILE}
    fi
    ALL_HOSTS=$(cat ${HOSTS_FILE})
    ALL_HOSTS_ARRAY=(${ALL_HOSTS})
    ALL_HOSTS_ARRAY_INDEX=0
    HOSTS_COUNT=$(cat ${HOSTS_FILE} | wc -l)
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
	result_file=${RESULT_DIR}/$host.json
	rm -f ${result_file}
        ssh  -o ConnectTimeout=3 $host "$@" >> ${result_file} &
    done
    wait
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
                    echo "no such file ${HOSTS_FILE}"
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
        distribute_all_scripts
        echo "开始收集主机信息，请稍等 "
        call_run_remote_cmd 'bash /tmp/scripts/run.sh get_json' 2>/dev/null
        clean_all
    fi
}

args_parser "$@"
prepare
main
python $BASE_DIR/process_hosts_info.py ${OUTPUT_FORMAT}
