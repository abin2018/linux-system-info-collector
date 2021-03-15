#!/bin/bash
# Some functions

function nopasswd_sudo_checker() {
    if [ $UID -ne 0 ] ; then
        if sudo -l -n 2>/dev/null | grep "User $USER" -A 1 | grep -q 'NOPASSWD'; then
           echo true
        else
           echo false
        fi
    else
        echo true
    fi
}

function logger_writer() {
    log_level=$1
    log_content=$2
    source_tag="#"
    echo "${log_level}: ${log_content}${source_tag}"
}

function string_splitter() {
    string=$1
    delimiter=$2
    if [ -z "$delimiter" ] ; then
        delimiter="#"
    fi
    echo $(echo $string | tr $delimiter ' ')
}

function bytes_unit_trans() {
    size=$1
    if awk -W version  2>/dev/null | grep -q 'mawk' ; then
        echo "$size" | awk -f ${BASE_DIR}/functions/trans_mawk.awk
    else
        echo "$size" | awk -f ${BASE_DIR}/functions/trans_gawk.awk
    fi
}
