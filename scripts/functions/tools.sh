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
    echo "$size" | awk '{
        if ($1 < 1024) {
            print $1
        } else if ($1 < 1024**2) {
            if ($1 % 1024 == 0) {
                print $1/1024"KB"
            } else {
                printf("%%.0fKB\n",$1/1000)
            }
        } else if ($1 < 1024**3) {
            if ($1 % (1024**2) == 0) {
                print $1/(1024**2)"MB"
            } else {
                printf("%.0fMB\n",$1/(1000**2))
            }
        } else if ($1 < 1024**4) {
            if ($1 % (1024**3) == 0) {
                print $1/(1024**3)"GB"
            } else {
                printf("%.0fGB\n",$1/(1000**3))
            }
        } else if ($1 < 1024**5) {
            if ($1 % (1024**4) == 0) {
                print $1/(1024**4)"TB"
            } else {
                printf("%.1fTB\n",$1/(1000**4))
            }
        } else if ($1 < 1024**6) {
            if ($1 % (1024**5) == 0) {
                print $1/(1024**5)"PB"
            } else {
                printf("%.1fPB\n",$1/(1000**5))
            }
        } else {
            print "Too big"
        }
    }'
}
