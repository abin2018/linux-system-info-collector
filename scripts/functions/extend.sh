#!/bin/bash

# Check Distribute Info
function get_dist_by_rhrelease() {
    echo $(cat /etc/redhat-release)
}

function get_dist_by_issue() {
    echo $(cat /etc/issue | head -1 | awk '{print $1" "$2" "$3}')
}

function get_dist_by_osrelease() {
    echo $(cat /etc/os-release | grep "PRETTY_NAME" | awk -F'=' '{print $2}' | tr -d '"')
}

function get_dist_info() {
    if [ -f /etc/redhat-release ] ; then
        get_dist_by_rhrelease
    elif [ -f /etc/os-release ] ; then
        get_dist_by_osrelease
    elif [ -f /etc/issue ] ; then
        get_dist_by_issue
    else
        echo "Unknown"
    fi
}

# Check Server Type
function get_server_type_by_sdv() {
    virtual_check_result=$(systemd-detect-virt)
    if [[ ${virtual_check_result} == "none" ]] ; then
        echo "Physical"
    elif [[ ${virtual_check_result} == "docker" ]] ; then
        echo "Docker"
    else
        echo "Virtual(${virtual_check_result})"
    fi
}

function get_server_type_by_dmidecode() {
    system-manufacturer=$(dmidecode -s system-manufacturer | grep -v '^#')
    if echo ${system-manufacturer} | grep -Ei 'vmware|alibaba|innotek GmbH|qemu'; then
        echo "Virtual(${system-manufacturer})"
    else
        echo "Physical"
    fi
}

function get_server_type() {
    which systemd-detect-virt >/dev/null 2>&1
    systemd_detect_virt_check=$?
    which dmidecode
    dmidecode_chedck=$?
    if ((systemd_detect_virt_check == 0)); then
        get_server_type_by_sdv()
    elif ((dmidecode_chedck == 0)); then
        get_server_type_by_dmidecode
    else
        echo "Unknown"
    fi
}

# Check Raid Info
function get_raid_info() {
    if ! $(nopasswd_sudo_checker); then
        logger_writer "warning" "sudo nopasswd privileges is needed for raid checking" >&2
        return 1
    fi

    #检查是否有raid卡且是否为支持的RAID卡产品
    raid_card_info=$($APP_DIR/lspci | grep 'RAID')
    if [ -z "${raid_card_info}" ] ; then
        logger_writer "warning" "No raid card found" >&2
        return 2
    elif echo ${raid_card_info} | grep -q -i "megaraid" ; then
        get_raid_info_megaraid
    elif echo ${raid_card_info} | grep -q -i "adaptec" ; then
        get_raid_info_adaptec
    else
        logger_writer "warning" "Raid card not be supported" >&2
        return 3
    fi
}

function get_raid_info_megaraid() {
    all_raid_info=$(sudo ${APP_DIR}/MegaCli64 -LdPdInfo -aALL -NoLog)
    OLD_IFS=$IFS
    IFS=$'\n'
    all_vds=$(echo "${all_raid_info}" | grep 'Virtual Drive')
    for vd in ${all_vds} ; do 
        vd_pretty_name=$(echo $vd | awk -F '(' '{print $1}' | awk -F ':' '{print $2}' | tr -d ' ')
        result=$(echo "${all_raid_info}" | sed -n "/$vd/,/Media Type.*/p")
        raid_level=$(echo "$result" | grep "RAID Level" | awk -F':' '{print $2}' | awk -F',' '{print $1}' | awk -F'-' '{print $2}')
        number_of_drivers=$(echo "$result" | grep "Number Of Drives" | awk -F':' '{print $2}' | tr -d ' ')
        pd_disk_interface=$(echo "$result" | grep "PD Type" | awk -F':' '{print $2}' | tr -d ' ')
        pd_disk_type_keyword=$(echo "${result}" | grep 'Media Type' | awk -F ':' '{print $2}')
        write_cache_policy=$(echo "${result}" | grep 'Current Cache Policy' | awk -F',' '{print $4}')
        if echo ${write_cache_policy} | grep -qi 'No Write Cache'; then
            write_cache_policy="No_Write_Cache"
        else
            write_cache_policy="Write_Cache_OK"
        fi
        if [[ ${pd_disk_type_keyword} == " Hard Disk Device" ]] ; then
            pd_disk_type="HDD"
        elif [[ ${pd_disk_type_keyword} == " Solid State Device" ]] ; then
            pd_disk_type="SSD"
        else
            pd_disk_type="UNKNOWN"
        fi
        pd_type="${pd_disk_type}-${pd_disk_interface}"
        raw_size_hex=$(echo "$result" | grep "Raw Size" | sed -n 's/.*\(0x.*\) .*/\1/p')
        raw_size_dec=$(echo "${raw_size_hex}" | awk '{print strtonum($1)}')
        raw_size=$(bytes_unit_trans $((raw_size_dec*512)))
        echo -n "vd${vd_pretty_name}:${number_of_drivers}:${raw_size}:${pd_type}:RAID${raid_level}:${write_cache_policy}#"
    done
    echo
    IFS=${OLD_IFS}
}

function get_raid_info_adaptec() {
    all_raid_info=$(sudo ${APP_DIR}/arcconf getconfig 1 LD)
    OLD_IFS=$IFS
    IFS=$'\n'
    all_lds=$(echo "${all_raid_info}" | grep 'Logical Device number')
    for ld in ${all_lds} ; do 
        ld_pretty_name=$(echo $ld | awk -F 'Logical Device number' '{print $2}' | tr -d ' ')
        result=$(echo "${all_raid_info}" | sed -n "/$ld/,/^$/p")
        raid_level=$(echo "$result" | grep "RAID level" | awk -F':' '{print $2}' | tr -d ' ')
        all_segments=$(echo "$result" | grep "Segment")
        number_of_segments=$(echo "${all_segments}" | wc -l)
        pd_disk_interface=$(echo "${all_segments}" | head -1 | awk -F'[(,]' '{print $3}' | tr -d ' ')
        pd_disk_type=$(echo "${all_segments}" | head -1 | awk -F'[(,]' '{print $4}' | tr -d ' ')
        pd_type="${pd_disk_type}-${pd_disk_interface}"
        raw_size_unit_mb=$(echo "${all_segments}" | head -1 | awk -F'[(,]' '{print $2}' | grep -oE '[0-9]+')
        raw_size=$(bytes_unit_trans $((raw_size_unit_mb*1024*1024)))
        write_cache_policy=$(echo "${result}" | grep -i 'write-cache status' | awk -F':' '{print $2}' | tr -d ' ')
        if echo ${write_cache_policy} | grep -qi 'off'; then
            write_cache_policy="Write_Cache_Off"
        else
            write_cache_policy="Write_Cache_On"
        fi
        echo -n "ld${ld_pretty_name}:${number_of_segments}:${raw_size}:${pd_type}:RAID${raid_level}:${write_cache_policy}#"
    done
    echo
    IFS=${OLD_IFS}
}

