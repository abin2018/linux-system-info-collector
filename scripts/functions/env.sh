#!/bin/bash
# Some variables

DISK_INCLUDE_PATTERN='(sd|vd|xvd)[a-z]$'  # Set the disk name for different system
NET_EXCLUDE_PATTERN='lo|docker|veth' # Set the network interface name to be exclude
DISK_IO_TEST_DIRS=('/tmp' '/data') # Set the io test directory
DISK_IO_TEST_FILE='io_test_file'
DISK_IO_TEST_SIZE=200M
DISK_IO_TEST_RUNTIME=10
