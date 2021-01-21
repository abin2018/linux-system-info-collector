#!/bin/bash

BASE_DIR=$(cd $(dirname $0) ; pwd)
APP_DIR=$BASE_DIR/apps
FUNCTION_DIR=$BASE_DIR/functions
source $FUNCTION_DIR/env.sh
source $FUNCTION_DIR/tools.sh
source $FUNCTION_DIR/extend.sh
source $FUNCTION_DIR/basic.sh
source $FUNCTION_DIR/output.sh

# Usage function
function usage() {
    echo -e "Usage: bash $0 command
-----------------------------------
Valid command:
    get_product_info
    get_kernel_info
    get_server_type 
    get_os_info 
    get_cpu_info 
    get_memory_info
    get_net_interface_info
    get_disk_info
	get_raid_info
    get_all
    get_json"
}


# Main function
function main() {
    case $1 in 
	get_product_info) 
		    get_product_info
		    ;;
	get_kernel_info) 
		    get_kernel_info
		    ;;
	get_server_type) 
		    get_server_type
		    ;;
	get_dist_info) 
		    get_dist_info
		    ;;
	get_cpu_info) 
		    get_cpu_info
		    ;;
	get_memory_info) 
		    get_memory_info
		    ;;
	get_net_interface_info) 
		    get_net_interface_info
		    ;;
	get_disk_info) 
		    get_disk_info
		    ;;
	get_raid_info) 
		    get_raid_info
		    ;;
	get_json) 
		    output_json
		    ;;
	get_all) 
		    get_product_info
		    get_kernel_info
		    get_server_type
		    get_dist_info
		    get_cpu_info
		    get_memory_info
		    get_net_interface_info
		    get_disk_info
		    ;;
	*) 
		    usage
    esac
}

# Main
if [ $#  -ne 1 ] ; then
    usage
else
    cmd=$1
    main $cmd 
fi
