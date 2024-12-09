#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8
setup_path=/datadisk

# 检测磁盘数量，如果只有一块硬盘，则退出
sysDisk=$(cat /proc/partitions | grep -v name | grep -v ram | awk '{print $4}' | grep -v '^$' | grep -v '[0-9]$' | grep -v 'vda' | grep -v 'xvda' | grep -v 'sda' | grep -e 'vd' -e 'sd' -e 'xvd')
if [ -z "$sysDisk" ]; then
    echo -e "ERROR! This server has only one hard drive, exiting."
    echo -e "此服务器只有一块磁盘, 无法挂载"
    echo -e "Bye-bye"
    exit 1
fi

# 检测 /datadisk 目录是否已挂载磁盘，如果已挂载，则退出
mountDisk=$(df -P | awk '{print $6}' | grep -w "$setup_path")
if [ -n "$mountDisk" ]; then
    echo -e "datadisk directory has already been mounted, exiting."
    echo -e "datadisk目录已被挂载, 不执行任何操作"
    echo -e "Bye-bye"
    exit 1
fi




# 数据盘自动分区并挂载
fdiskP() {
    # 遍历所有磁盘（除了已经挂载的）
    for i in $(lsblk -d -o NAME | grep -E 'sd|vd'); do
        echo "Processing /dev/$i"

        # 如果分区不存在，则创建分区
        if ! fdisk -l /dev/$i | grep -q "${i}1"; then
            echo "No partition found on /dev/$i, creating a new partition."
            # 创建一个新的主分区并保存
            echo -e "n\np\n1\n\n\nw" | fdisk /dev/$i
            sleep 5
        fi

        # 格式化新分区
        if [ ! -e "/dev/${i}1" ]; then
            echo "Partition /dev/${i}1 does not exist. Skipping."
            continue
        fi

        # 格式化分区
        mkfs.ext4 /dev/${i}1

        # 创建挂载目录
        if [ ! -d "$setup_path" ]; then
            mkdir -p "$setup_path"
        fi

        # 更新 /etc/fstab，确保不会重复添加
        if ! grep -q "/dev/${i}1" /etc/fstab; then
            echo "Adding /dev/${i}1 to /etc/fstab."
            echo "/dev/${i}1    $setup_path    ext4    defaults    0 0" >> /etc/fstab
        fi

        # 挂载分区
        mount /dev/${i}1 $setup_path
        if [ $? -eq 0 ]; then
            echo "/dev/${i}1 mounted successfully to $setup_path."
        else
            echo "Failed to mount /dev/${i}1."
        fi

        # 刷新文件系统
        mount -a
        df -h
        break
    done
}

# 调用分区和挂载函数
fdiskP

# 输出挂载状态
echo -e ""
echo -e "Done"
echo -e "挂载成功"
