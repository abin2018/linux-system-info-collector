## 功能

1. 本脚本主要用于获取Linux系统各项常见硬件和系统配置，具体如下：

| 英文名称           | 中文说明                                                   |
| ------------------ | ---------------------------------------------------------- |
| sys_vendor         | 主机厂商                                                   |
| product_name       | 主机型号                                                   |
| server_type        | 主机类型(物理机、虚拟机)                                   |
| kernel_version     | 内核版本信息                                               |
| os_info            | 操作系统(发行版)信息                                       |
| cpu_info           | CPU相关(包括型号、个数、核数以及逻辑CPU数量)               |
| memory_info        | 内存大小                                                   |
| net_interface_info | 网络信息(主机中已激活的网卡的信息)                         |
| disk_info          | 磁盘大小信息和类型信息                                     |
| raid_info          | 主机(仅物理机)的RAID配置信息(目前支持LSI和Adaptec的RAID卡) |

## 一些优势

1. 尽可能解决不同Linux发行版的兼容性问题，尽量使用读取文件的形式来获取系统的信息，少使用命令，除了操作系统、主机类型和RAID信息之外，其余信息都可以通过读取文件获取。

2. 解决了一直困扰的容量单位问题，由于工业上和计算机体系中的进制转换的不同，导致在系统中获取信息后，难以转换成真实的大小，本工具借助与实际经验，编写了更符合实际的转换函数，尽最大可能还原真实的大小（有些转换失败的也存在）。

3. 输出支持json和命令行表格两种输出，方便对数据做进一步的处理。比如对数据做统计、输出等。

4. 如果在多台机器上做了SSH互信，则可支持多台系统并行获取信息，提高收集信息速度，默认进程数为5个，可根据实际情况进行调整。

5. 做了相关功能的拆分，便于进一步的扩展，比如可以针对不同的RAID卡写不同的采集命令，按照一个统一格式的输出即可。

   > 查看RAID卡的命令:  ```lspci | grep RAID```
## 用法

1. 各文件说明

   .
   ├── log                                      -- 错误日志目录，每次执行会自动生成
   ├── process_hosts_info.py    -- 处理输出结果的脚本
   ├── README.md                     -- 帮助文档
   ├── run.sh                                 -- 主入口文件
   └── scripts                                 -- 所有脚本和文件所在的目录
       ├── apps                                -- 收集RAID信息时需要借助的工具
       │   └── MegaCli64                 -- LSI RAID卡工具

   ​    │   └── arcconf                       -- Adaptec RAID卡工具

   ​    ├── functions                        -- 所有功能函数的集合
   ​    │   ├── basic.sh                     -- 可以明确的，不依赖于发行版的一些信息，如硬盘、CPU等
   ​    │   ├── env.sh                        -- 一些变量的配置
   ​    │   ├── extend.sh                  -- 可能依赖于发行版的一些信息，如RAID、发行版本号等
   ​    │   ├── output.sh                  -- run.sh执行结果的输出，输出为json格式
   ​    │   └── tools.sh                     -- 一些如单位转换等的工具函数 
   ​    └── run.sh                             -- 收集脚本的入口文件

2. 用法

   > 除了raid信息外，其余均不需要使用root用户获取，对于RAID信息，只需要执行用户具有免密sudo权限即可。

   2.1 命令行参数：

   ```
   Usage: run.sh [ARGS] [OPTION]
   options
      ?                         show this help
     -f format                  set the output format, valid option is 'json' or 'table', default is 'table'
     -h hostfile                specify a text file that contains all hosts
     -s host                    specify a single host
     -c process_count           specify the process number running at the same time
   ```

   > ?     显示帮助
   >
   > -f    可选，指定输出的格式，默认为table，可以指定为json
   >
   >-h   可选，指定一个包含多个主机的文件，一行一个
   >
   >-s    可选，指定一个主机，可以为主机名或者IP地址
   >
   >-c    可选，同时运行的收集进程数，默认为5个，最大为20，可以根据实际情况调整 

   2.2 用法举例
   ​      2.2.1 直接执行，不加任何参数，默认收集本机localhost信息 

```shell
bash run.sh
```

​            2.2.2 指定-h 参数，收集指定文件中的主机的信息
   ```shell
   bash run.sh -h /tmp/hosts
   ```
>输出结果会显示成功和失败的数量以及运行过程中的日志，对于失败的可以查看日志

​            2.2.3 指定-f json参数，将信息导出为json文件

```shell
bash run.sh -h /tmp/hosts -f json
```

> 默认导出的路径为/tmp/server_info.json

​             2.2.4 指定-s 参数，收集指定的主机信息

```shell
bash run.sh -s node2
```

