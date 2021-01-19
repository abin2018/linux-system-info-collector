#!/usr/bin/env python
#-*- coding:utf8 -*-

import os
import json
import sys

BASEDIR = os.path.dirname(os.path.abspath(__file__))

def get_host_info_dict(host_info_file):
    info_dict = {}
    with open(host_info_file) as f:
        info_dict = json.load(f)
    return info_dict

def output_json(result_dir):
    output_list = []
    for file in os.listdir(result_dir):
        host = os.path.splitext(file)[0]
	file_path = os.path.join(result_dir, file)
	info_dict = get_host_info_dict(file_path)
        output_list.append(info_dict)
    print(json.dumps(output_list, indent=4))

def output_table(result_dir):
    out_tag_title = "|%-15s|%-15s|%-20s|%-19s|%-14s|%s|%-8s|%-52s|%-23s|%-23s|"
    out_tag = "|%-15s|%-13s|%-18s|%-20s|%s|%-3s|%-6s|%-50s|%-20s|%-20s|"
    print('-'*164)
    print(out_tag_title % ("IP", "厂商", "型号","类型", "操作系统", "CPU", "内存", "网卡", "硬盘", "RAID"))
    for file in os.listdir(result_dir):
        host = os.path.splitext(file)[0]
	file_path = os.path.join(result_dir, file)
	info_dict = get_host_info_dict(file_path)
        info_dict['host'] = host
	print('-'*164)
	print(out_tag % (
            info_dict["host"], info_dict["product_info"]["sys_vendor"], info_dict["product_info"]["product_name"],
            info_dict["server_type"], info_dict["os_info"], info_dict["cpu_info"]["cpu_processor_count"], 
            info_dict["memory_info"], ' '.join(['{}({})'.format(i["interface_name"], i["interface_speed"]) for i in info_dict["net_interface_info"]]),
            #' '.join(['{}:{}({})'.format(i["disk_name"], i["disk_size"], i["disk_type"]) for i in info_dict["disk_info"]]),
            "sda:6.0TB(SATA) sdb:6.0TB(SATA)\n"+" "*440+"sdc:6.0TB(SATA) sdd:6.0TB(SATA)\n"+" "*440+"sde:6.0TB(SATA) sdf:6.0TB(SATA)\n"+" "*440+"sdg:600GB(SATA)"+" "*16,
            ' '.join(['{}:{}*{}({} {})'.format(i["vd_name"], i["number_of_drivers"], i["raw_size"], i["pd_type"], i["raid_level"]) for i in info_dict["raid_info"]]),
	))
    print('-'*164)


if __name__ == '__main__':
    try:
        output_format = sys.argv[1]
    except Exception:
        print("Usage: {} output_format".format(__file__))
        sys.exit()
    result_dir = os.path.join(BASEDIR, '.result')
    if output_format == 'json':
        output_json(result_dir)
    else:
        output_table(result_dir)
