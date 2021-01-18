#!/bin/bash

#Output function
function output_json() {
    arr_element_counter=1
    echo "{"
    product_info=($(string_splitter "$(get_product_info)"))
    echo "    \"product_info\": {
        \"sys_vendor\": \"${product_info[0]}\", 
        \"product_name\": \"${product_info[1]}\"
    },"
    server_type=$(get_server_type)
    echo "    \"server_type\": \"${server_type}\","
    kernel_version=$(get_kernel_info)
    echo "    \"kernel_version\": \"${kernel_version}\","
    os_info=$(get_dist_info)
    echo "    \"os_info\": \"${os_info}\","
    cpu_info=($(string_splitter $(get_cpu_info)))
    echo "    \"cpu_info\": {
        \"model_name\": \"${cpu_info[0]}\", 
        \"cpu_physical_count\": \"${cpu_info[1]}\", 
        \"cpu_cores_count\": \"${cpu_info[2]}\", 
        \"cpu_processor_count\": \"${cpu_info[3]}\"
    },"
    memory_info=$(get_memory_info)
    echo "    \"memory_info\": \"${memory_info}\","
    cpu_info=($(string_splitter $(get_cpu_info)))
    net_interface_info=($(string_splitter $(get_net_interface_info)))
    echo -n "    \"net_interface_info\": ["
    for net in ${net_interface_info[@]}; do
	net_info=($(string_splitter "$net" ":"))
	if [[ ${arr_element_counter} -eq ${#net_interface_info[@]} ]] ; then
	    echo -n "
        {
            \"interface_name\": \"${net_info[0]}\", 
            \"interface_speed\": \"${net_info[1]}\"
        }"
	else
	    echo -n "
        {
            \"interface_name\": \"${net_info[0]}\", 
            \"interface_speed\": \"${net_info[1]}\"
        }, "
	fi
	((arr_element_counter++))
    done
    echo "
    ],"
    arr_element_counter=1
    disk_info=($(string_splitter $(get_disk_info)))
    echo -n "    \"disk_info\": ["
    for disk in ${disk_info[@]}; do
	disk_info_single=($(string_splitter "$disk" ":"))
	if [[ ${arr_element_counter} -eq ${#disk_info[@]} ]] ; then
	    echo -n "
        {
            \"disk_name\": \"${disk_info_single[0]}\", 
            \"disk_size\": \"${disk_info_single[1]}\", 
            \"disk_type\": \"${disk_info_single[2]}\"
        }"
	else
	    echo -n "
        {
            \"disk_name\": \"${disk_info_single[0]}\", 
            \"disk_size\": \"${disk_info_single[1]}\", 
            \"disk_type\": \"${disk_info_single[2]}\"
        }, "
        fi
	((arr_element_counter++))
    done
    echo "
    ],"
    arr_element_counter=1
    raid_info=($(string_splitter $(get_raid_info)))
    echo -n "    \"raid_info\": ["
    for raid in ${raid_info[@]}; do
	raid_info_single=($(string_splitter "$raid" ":"))
	if [[ ${arr_element_counter} -eq ${#raid_info[@]} ]] ; then
	    echo -n "
        {
            \"vd_name\": \"${raid_info_single[0]}\", 
            \"number_of_drivers\": \"${raid_info_single[1]}\", 
            \"raw_size\": \"${raid_info_single[2]}\", 
            \"pd_type\": \"${raid_info_single[3]}\", 
            \"raid_level\": \"${raid_info_single[4]}\"}"
	else
	    echo -n "
        {
            \"vd_name\": \"${raid_info_single[0]}\", 
            \"number_of_drivers\": \"${raid_info_single[1]}\", 
            \"raw_size\": \"${raid_info_single[2]}\", 
            \"pd_type\": \"${raid_info_single[3]}\", 
            \"raid_level\": \"${raid_info_single[4]}\"
        },"
        fi
	((arr_element_counter++))
    done
    echo "
    ]"
    arr_element_counter=1
    echo "}"
}

