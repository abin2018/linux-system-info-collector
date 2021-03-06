#!/usr/bin/env python
#-*- coding:utf8 -*-

import os
import json
import sys
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_JSON_FILE = os.path.join('/tmp/', 'server_info.json')

def get_host_info_dict(host_info_file):
    info_dict = {}
    try:
        with open(host_info_file) as f:
            info_dict = json.load(f)
    except Exception as e:
        sys.stderr.write('{}: file {}:{}\n'.format(__file__, host_info_file, e))
        return
    return info_dict

def output_json(result_dir, hosts_list, out_put_json_file=OUTPUT_JSON_FILE):
    output_list = []
    json_file_list = [ f for f in os.listdir(result_dir) ]
    for host in hosts_list:
        json_file = "{}.json".format(host)
        if json_file not in json_file_list:
            continue
        file_path = os.path.join(result_dir, json_file)
        info_dict = get_host_info_dict(file_path)
        info_dict['host'] = host
        if info_dict is None:
            continue
        output_list.append(info_dict)
    with open(out_put_json_file, 'w') as f:
        json.dump(output_list, f)
        print("JSON文件已导出到{}".format(out_put_json_file))

def full_field(rows, ilist):
    for i in range((rows - len(ilist))):
        ilist.append(' '*22)

def os_info_parser(os_info):
    try:
        os_name = os_info.split()[0]
        version_regex = r'\d+(\.\d+)?(\.\d+)?'
        version = re.search(version_regex, os_info).group()
    except Exception:
        return os_info
    return os_name+' '+version

def output_table(result_dir, hosts_list):
    out_tag_title = "|%-15s|%-24s|%-27s|%-22s|%-44s|%s|%-8s|%-24s|%-24s|%-35s|"
    out_tag = "|%-15s|%-22s|%-25s|%-20s|%-40s|%-3s|%-6s|%-22s|%-22s|%-35s|"
    print('-'*221)
    print(out_tag_title % ("IP", "厂商", "型号","类型", "操作系统", "CPU", "内存", "网卡", "硬盘", "RAID"))
    print('-'*221)
    json_file_list = [ f for f in os.listdir(result_dir) ]
    for host in hosts_list:
        json_file = "{}.json".format(host)
        if json_file not in json_file_list:
            continue
        file_path = os.path.join(result_dir, json_file)
        info_dict = get_host_info_dict(file_path)
        if info_dict is None:
            continue
        info_dict["os_info"] = os_info_parser(info_dict["os_info"])
        info_dict['host'] = host
        line_fix = [info_dict["host"], info_dict["product_info"]["sys_vendor"], info_dict["product_info"]["product_name"],
                             info_dict["server_type"], info_dict["os_info"], info_dict["cpu_info"]["cpu_processor_count"],info_dict["memory_info"]]
        net_interface_list = ['{}({})'.format(i["interface_name"], i["interface_speed"]) for i in info_dict["net_interface_info"]]
        disk_list = ['{}:{}({})'.format(i["disk_name"], i["disk_size"], i["disk_type"]) for i in info_dict["disk_info"]]
        raid_list = ['{}:{}*{}({} {})'.format(i["vd_name"], i["number_of_drivers"], i["raw_size"], i["pd_type"], i["raid_level"]) for i in info_dict["raid_info"]]
        rows = max(len(net_interface_list), len(disk_list), len(raid_list))
        full_field(rows, net_interface_list)
        full_field(rows, disk_list)
        full_field(rows, raid_list)
        line_fix.append(net_interface_list[0])
        line_fix.append(disk_list[0])
        line_fix.append(raid_list[0])
        print(out_tag % tuple(line_fix))
        for i in range(1, rows):
            output_line = [" "*15, " "*22, " "*18, " "*20, " "*40, " "*3, " "*6, net_interface_list[i], disk_list[i], raid_list[i]]
            print(out_tag % tuple(output_line))
        print('-'*221)


if __name__ == '__main__':
    try:
        output_format = sys.argv[1]
    except Exception:
        print("Usage: {} output_format".format(__file__))
        sys.exit()
    try:
        hosts_file = sys.argv[2]
        if '.empty' in hosts_file:
            hosts_list = ['localhost']
        else:
            with open(hosts_file) as f:
                hosts_list = [ line.strip() for line in f.readlines() ]
    except Exception:
        hosts_list = ['localhost']
    result_dir = os.path.join(BASE_DIR, '.result')
    if output_format == 'json':
        output_json(result_dir, hosts_list)
    else:
        output_table(result_dir, hosts_list)
