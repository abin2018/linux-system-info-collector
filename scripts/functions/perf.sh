#!/bin/bash

function get_io_test() {
    io_value=""
    for dir in ${DISK_IO_TEST_DIRS[@]}; do
        if [ ! -d "$dir" ] ; then
	    logger_writer "warning" "io test dir "$dir" not found, io test abort#" >&2
            echo ""
            continue
        fi
        io_test_info=$(sudo ${APP_DIR}/fio -filename=$dir/${DISK_IO_TEST_FILE} -direct=1 -iodepth 1 -thread -rw=randrw -rwmixread=70 -ioengine=psync -bs=16k -size=${DISK_IO_TEST_SIZE} -numjobs=20 -runtime=${DISK_IO_TEST_RUNTIME} -group_reporting -name=mytest)
        _value=$(echo ${io_test_info} | grep -E 'read:|write:' | grep -Eo 'IOPS=[0-9]+' | awk -F'=' '{print $2}' | xargs | tr ' ' ':')
	echo -n $dir:${_value}"#"
    done
}
