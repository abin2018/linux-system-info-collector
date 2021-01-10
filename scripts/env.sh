#!/bin/bash

BASEDIR=$(cd $(dirname $0) ; pwd)
IO_TEST_DIR=$BASEDIR/.io_test
IO_TEST_FILE=${IO_TEST_DIR}/io_test_result
APP_DIR=$BASEDIR/apps
LIB_DIR=${APP_DIR}/lib
FIO_OUTPUT_FILE_SIZE=1G

[ $(id -u) -eq 0 ] && echo ${LIB_DIR} > ${APP_DIR}/lib.conf && ldconfig -f ${APP_DIR}/lib.conf
[ -d ${IO_TEST_DIR} ] || mkdir ${IO_TEST_DIR}
