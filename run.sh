#!/bin/bash

#General Variables
BASE_DIR=$(cd $(dirname $0) ; pwd) # 获取脚本所在目录
HOSTS_FILE="" # host文件
SPECIFY_HOST_FILE=${BASE_DIR}/.tmp_hosts # 指定-s参数时，将主机名写入的文件
RESULT_DIR=$BASE_DIR/.result # 执行结果存放的目录
IGNORE_HOSTS=$BASE_DIR/.ignore_hosts # 存放执行过程中失败主机的文件
OUTPUT_FORMAT="table" # 输出结果的默认格式
LOG_DIR=$BASE_DIR/log # 运行日志目录
ERROR_LOG=${LOG_DIR}/running.log # 运行日志名称
PYTHON_EXEC=$(which python || which python2 || which python3)  # 设置python解释器
MAX_PROCESS_COUNT=20 # 分发脚本和采集信息时最大允许同时允许的进程数
PROCESS_COUNT=5 # 分发脚本和采集信息时默认的进程数
SSH_DEFAULT_OPTIONS="-o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no" # 连接SSH时默认参数

# 脚本执行前的准备
function prepare() {
    if [ -z "${HOSTS_FILE}" ] ; then  # 不指定host文件时，创建一个.empty文件，仅收集localhost信息
        HOSTS_FILE=$BASE_DIR/.empty
        touch ${HOSTS_FILE}
    fi
    ALL_HOSTS=$(cat ${HOSTS_FILE})
    ALL_HOSTS_ARRAY=(${ALL_HOSTS}) # 将host文件中的主机读入一个数组中
    ALL_HOSTS_ARRAY_INDEX=0
    HOSTS_COUNT=$(cat ${HOSTS_FILE} | wc -l)
    [ -f ${IGNORE_HOSTS} ] && rm -f ${IGNORE_HOSTS}
    touch ${IGNORE_HOSTS}
    [ -d ${RESULT_DIR} ] && rm -rf ${RESULT_DIR}
    mkdir ${RESULT_DIR}
    [ -d ${LOG_DIR} ] && rm -rf ${LOG_DIR}
    mkdir ${LOG_DIR}
}

# 当在ssh远程执行过程中遇到错误时的处理
function ssh_error_handler() {
    host=$1
    error_info=$2
    if [ -n "${error_info}" ] ; then   # 判断传入的错误信息是否为空
        echo "$host: error: ${error_info}" >&2
        echo $host >> ${IGNORE_HOSTS}  # 将有问题的主机写入到一个文件中
    fi
}

# ssh远程连接所有主机之前做一次检查，排除掉无法正常连接的主机
function pre_checking() {
    host=$1
    error_info=$(ssh ${SSH_DEFAULT_OPTIONS} $host exit 2>&1 1>/dev/null)  # 检查是否做了互相以及是否可达，将标准错误定向到标准输出，然后部捕获错误内容
    ssh_error_handler "$host" "${error_info}"
}

# 将执行脚本分发到每一台主机
function distribute_script() {
    host=$1
    error_info=$(scp ${SSH_DEFAULT_OPTIONS} -r $BASE_DIR/scripts $host:/tmp/ 2>&1 1>/dev/null)
    ssh_error_handler "$host" "${error_info}"
}

# 在每一台主机上启动iperf服务端
function run_all_iperf3() {
    host=$1
    error_info=$(ssh ${SSH_DEFAULT_OPTIONS} $host '[ -f /tmp/iperf3.pid ] || /tmp/scripts/apps/iperf3 -s -D -I /tmp/iperf3.pid' &>/dev/null)
    ssh_error_handler "$host" "${error_info}"
}

# 停止每一台主机上正在运行的iperf服务端
function kill_all_iperf3() {
    host=$1
    error_info=$(ssh ${SSH_DEFAULT_OPTIONS} $host '[ -f /tmp/iperf3.pid ] && kill $(cat /tmp/iperf3.pid)' &>/dev/null)
    ssh_error_handler "$host" "${error_info}"
}

# 通过ssh运行iperf3带宽测试
function iperf3_test() {
    client=$1   # 客户端
    server=$2   # 服务端
    iperf3_output_file=${RESULT_DIR}/$client.iperf3   # iperf3运行结果输出文件
    iperf3_result_file=${RESULT_DIR}/$client.iperf3_result # 经过处理后，获取到的带宽信息存放文件
    iperf3_error=$(ssh ${SSH_DEFAULT_OPTIONS} $client "/tmp/scripts/apps/iperf3 -c $server -t 10 -f m" 2>&1 1>${iperf3_output_file})
    if [ -z "${iperf3_error}" ]; then 
        grep -E 'sender|receiver' ${iperf3_output_file}| awk '{print $7$8}' | xargs > ${iperf3_result_file}
    else
        echo "$client: iperf3 error: ${iperf3_error}" >> ${ERROR_LOG}
    fi
}

# 所有主机运行iperf3测试，考虑到并行获取数据的准确性以及iperf3仅监听了一个端口，采用遍历的方式进行测试
function run_iperf3_test() {
    # 获取所有物理机，虚拟机不进行测试
    physical_server_list=()
    for result_file in ${RESULT_DIR}/* ; do 
        _host=$(basename "$result_file" | awk -F'.json' '{print $1}')   # 通过输出结果的文件名获取主机名
        if grep -i 'server_type' ${result_file} | grep -iq 'physical'; then # 判断是否为物理机
            physical_server_list+=(${_host}) 
        else
            echo "${_host}: info: virtual machine will not perform iperf3 test" >> ${ERROR_LOG}
        fi
    done
    if [[ ${#physical_server_list[@]} == 0 ]] || [[ ${#physical_server_list[@]} == 1 ]]; then
        echo "没有发现物理机或仅有1台，将不执行带宽测试"
        return
    fi

    local counter=0  # 局部变量，完成台数的计数器
    echo -n "开始进行网络带宽测试... "
    for ((i=0;i<${#physical_server_list[@]};i++)) ; do # 对所有的物理机进行遍历测试，如'a','b','c'三台，则采用a->b b->c c->a的形式进行测试
        e=$((i+1)) # i:client的索引，e:server的索引
        if ((e==${#physical_server_list[@]})); then # 当client为最后一台时，server的索引变为0
            e=0
        fi 
        tput sc; tput civis                     # 记录光标位置,及隐藏光标
        echo -ne "已完成$counter/${#physical_server_list[@]}台"   # 显示进度
        iperf3_test ${physical_server_list[$i]} ${physical_server_list[$e]}
        ((counter++))
        tput rc                                 # 恢复光标到记录位置
    done
    echo -ne "已完成$counter/${#physical_server_list[@]}台"   # 显示进度
    tput el; tput cnorm
    echo
}

# 控制ssh多进程运行的函数
function multi_process_running() {
    exec_function=$1   # 传入的以多进程执行的函数名称
    local counter=0
    while ((counter < ${#ALL_HOSTS_ARRAY[@]})); do
        temp_host_list=($(echo ${ALL_HOSTS_ARRAY[@]:$counter:$PROCESS_COUNT}))  # 每次取n个进程，即同时执行n个进程，n为传入的并行数量
        for host in ${temp_host_list[@]} ; do 
            ${exec_function} $host 2>>${ERROR_LOG} &
        done
        wait # 等待进程结束
        counter=$((counter+PROCESS_COUNT))
    done
    for host in $(cat ${IGNORE_HOSTS}); do   # 读取失败的主机，并从主机数组中去掉
    ALL_HOSTS=$(echo "${ALL_HOSTS}" | grep -v "\<$host\>")
        ALL_HOSTS_ARRAY=(${ALL_HOSTS})
    done
}

# 清理分发的脚本以及一些其他的临时文件
function clean_script() {
    host=$1
    clean_error=$(ssh ${SSH_DEFAULT_OPTIONS} $host "rm -rf /tmp/scripts; sudo rm -f /data/io_test_file && sudo rm -f /tmp/io_test_file" 2>&1)
    if [ ! -z "${clean_error}" ]; then 
        echo "$host: error: ${clean_error}" >> ${ERROR_LOG}
    fi
}

# 执行收集信息的脚本
function running_script() {
    host=$1
    result_file=${RESULT_DIR}/$host.json
    rm -f ${result_file}
    error_info=$(ssh ${SSH_DEFAULT_OPTIONS} $host 'bash /tmp/scripts/run.sh get_json' 2>&1 1>>${result_file})
    if ! echo ${error_info} | grep -q -E '.*#$|cat'; then  # 判断错误日志为上面的脚本执行产生的或者为ssh本身产生的
        ssh_error_handler "$host" "${error_info}"
    else
        echo "${error_info}" | while read info ; do
            echo "$host: $(echo $info | tr -d '#')" >> ${ERROR_LOG}
        done
    fi
}

# 统计最终的成功运行和失败情况
function running_result_count() {
    success_number=${#ALL_HOSTS_ARRAY[@]}
    fail_number=$(cat ${IGNORE_HOSTS} | wc -l)
    total_number=$((success_number+fail_number))
    echo -e "总计:${total_number}\t成功:${success_number}\t失败:${fail_number}\t运行日志:${ERROR_LOG}"
}

# 脚本帮助
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

# 脚本参数解析
function args_parser() {
    hosts_file_option=false
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
                if [ ! -s ${HOSTS_FILE} ] ; then
                    echo "empty host file ${HOSTS_FILE}"
                    exit
                fi
                hosts_file_option=true
                ;;
            s) 
                SPECIFY_HOSTS=$OPTARG
                if echo ${HOSTS_FILE} | grep -q '^-.*' ; then
                    usage
                    exit
                fi 
                echo ${SPECIFY_HOSTS}> ${SPECIFY_HOST_FILE}  # 将指定的主机名写入一个文件
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

# 结果处理
function python_output() {
    if [ -n "$PYTHON_EXEC" ] ; then
        $PYTHON_EXEC $BASE_DIR/process_hosts_info.py ${OUTPUT_FORMAT} ${HOSTS_FILE} 2>>${ERROR_LOG}
    else
        echo "No python found, output failed"
        return 1
    fi
}

# 总的调度函数
function main() {
    if [ -z "${ALL_HOSTS}" ] ; then
        error_info=$(/bin/bash $BASE_DIR/scripts/run.sh get_json 2>&1 1>${RESULT_DIR}/localhost.json)
        sudo rm -f /data/io_test_file && sudo rm -f /tmp/io_test_file
        if [ -n "${error_info}" ] ; then
            echo "${error_info}" | while read info ; do
                echo "localhost: $(echo $info | tr -d '#')" >> ${ERROR_LOG}
            done
        fi
        return 1
    else
        multi_process_running pre_checking
        multi_process_running distribute_script
        echo -n "开始收集主机信息"
        multi_process_running running_script
        echo -n " 已完成"
        echo
        multi_process_running run_all_iperf3
        run_iperf3_test
        multi_process_running kill_all_iperf3
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
