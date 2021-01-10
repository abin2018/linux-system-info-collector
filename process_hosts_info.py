#!/usr/bin/env python
#-*- coding:utf8 -*-

import os
import json

BASEDIR = os.path.dirname(os.path.abspath(__file__))

def get_host_info(host_info_file):
    info_dict = {}
    with open(host_info_file) as f:
        all_info = [ i.strip() for i in f.readlines() ]
#	print(all_info)
	try:
            host, vendor_model, mtype, os, cpu, mem, net, disk, io = all_info
	except Exception as e:
	    print(e)
	    return {}
    info_dict["host"] = host
    vendor, model = vendor_model.split('*')
    info_dict["vendor"] = vendor
    info_dict["model"] = model
    info_dict["mtype"] = mtype
    info_dict["os"] = os
    info_dict["cpu"] = cpu
    info_dict["mem"] = mem
    info_dict["net"] = net
    info_dict["disk"] = {}
    disk_list = disk.strip().strip('_').split('_')
    if len(disk_list) == 1:
        info_dict["disk"]['system'] = disk_list[0]
        info_dict["disk"]['data'] = 'N/A'
    else:
        info_dict["disk"]['system'] = disk_list[0]
        info_dict["disk"]['data'] = disk_list[1]
    info_dict["io"] = {}
    io_list = io.strip().split()
    info_dict["io"]["read"] = io_list[0]
    info_dict["io"]["write"] = io_list[1]
    return info_dict

if __name__ == '__main__':
    result_dir = os.path.join(BASEDIR, '.result')
    out_tag_title = "|%-15s|%-15s|%-20s|%-19s|%-14s|%s|%-8s|%-52s|%-23s|%-23s|%-18s|"
    out_tag = "|%-15s|%-13s|%-18s|%-20s|%s|%-3s|%-6s|%-50s|%-20s|%-20s|%s|"
    print('-'*164)
    print(out_tag_title % ("IP", "厂商", "型号","类型", "操作系统", "CPU", "内存", "网卡", "系统盘", "数据盘", "随机读写"))
    for file in os.listdir(result_dir):
	file_path = os.path.join(result_dir, file)
	#print(json.dumps(get_host_info(file_path), indent=4))
	info_dict = get_host_info(file_path)
	print('-'*164)
	print(out_tag % (
            info_dict["host"], info_dict["vendor"], info_dict["model"], info_dict["mtype"], info_dict["os"], info_dict["cpu"],
	    info_dict["mem"], info_dict["net"], info_dict["disk"]['system'], info_dict["disk"]['data'],
	    "R:"+info_dict["io"]["read"]+" "+"W: "+info_dict["io"]["write"]
	))
    print('-'*164)
