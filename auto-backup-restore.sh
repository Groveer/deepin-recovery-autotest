#!/bin/bash

# 自动化备份还原测试脚本
# 共测试200轮
# 测试顺序为系统备份->自定义还原->全盘备份->自定义还原->恢复出厂设置（保留用户数据）->恢复出厂设置（不保留用户数据）

# 备份路径
backup_path="/media/backup"
# 备份分区设备路径
backup_device_path="/dev/null"

# 测试总轮数
test_count=200

# 当前测试轮数
test_index=0

# 测试模块，为空则从系统备份开始
# system_backup         系统备份
# manual_backup         全盘备份
# manual_restore1       自定义还原系统备份
# manual_restore2       自定义还原全盘备份
# system_restore1   系统还原保留用户数据
# system_restore2 系统还原不保留用户数据
# end_file_check  检查系统还原不保留用户数据文件存在情况
test_mode="system_backup"

restore_path=
# 获取文件内容
function getValue() {
    while read line
    do
        k=${line%=*}
        v=${line#*=}
        [ ${k} = "index" ] && test_index=${v}
        [ ${k} = "mode" ] && test_mode=${v}
    done < ${auto_test_file}
}

function getConf() {
    while read line
    do
        k=${line%=*}
        v=${line#*=}
        [ ${k} = "file_path" ] && backup_path=${v}
        [ ${k} = "device_path" ] && backup_device_path=${v}
        [ ${k} = "count" ] && count=${v}
    done < "/recovery/recovery.conf"
}

# 获取备份文件路径
function getRestorePath() {
for line in $(ls ${backup_file_path})
do
    if [[ ${line} = "2021"* ]]; then
         restore_path=${line}
         break
    fi
done
}

# 判断是否跑完后配置，通过判断是否安装了安装器进行判断
while true
do
  result=$(dpkg -L deepin-installer 2>&1)
  [[ $result = "dpkg-"* ]] && break;
  echo "deepin-installer not uninstall, check it again after 2s!"
  sleep 2s
done

# 暂停30秒后开始配置备份还原
echo "sleep 30s for wait bengin work"
sleep 30s
getConf
auto_test_file="${backup_path}/auto_test_recovery"
auto_test_log="${backup_path}/auto_test_recovery.log"
result_file_log="${backup_path}/result_file.log"
backup_file_path=${backup_path}/backup

echo "auto_test_file:$auto_test_file"
echo "auto_test_log:$auto_test_log"

if [ ! -d ${backup_path} ]; then
    mkdir -p ${backup_path}
fi

umount ${backup_device_path}
sleep 5s
mount ${backup_device_path} ${backup_path}
# 判断备份路径是否存在
if [ -z "${backup_path}" ]; then
    echo "Please set backup path！"
    exit -1
fi


if [ ! -d ${backup_file_path} ]; then
    mkdir -p ${backup_file_path}
fi

echo "backup file path:${backup_file_path}"
file_exist=false
# 判断文件保存路径是否存在    
if [ -s ${auto_test_file} ]; then
    getValue
    file_exist=true
fi

# 如果配置文件存在
if [ ${file_exist} = "true" ]; then
    case ${test_mode} in
        "system_backup")
            test_mode="manual_restore1"
            ;;
        "manual_restore1")
            test_mode="manual_backup"
            ;;
        "manual_backup")
            test_mode="manual_restore2"
            ;;
        "manual_restore2")
            test_mode="system_restore1"
            ;;
        "system_restore1")
            test_mode="system_restore2"
            ;;
        "system_restore2")
            test_mode="end_file_check"
            ;;
        "end_file_check")
            test_mode="system_backup"
            test_index=$(expr ${test_index} + 1)
            ;;
    esac
fi

if [ ${test_index} -ge ${test_count} ]; then
    echo "Test Finished!" >> ${auto_test_log}
    exit 0
fi

case ${test_mode} in
    "system_backup")    #系统备份
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统备份前创建文件！" >> ${auto_test_log}
        cp -r /recovery/testfolder /home/uos/Desktop/    #桌面文件
        cp -r /recovery/testfolder /    #根目录文件
        cp -r /recovery/testfolder /boot/    #boot分区文件
        cp -r /recovery/testfolder /opt/    #opt分区文件
        cp -r /recovery/testfolder /var/    #var分区文件
        rm -rf ${backup_file_path}/*
        echo "begin system backup:${backup_file_path}"
        deepin-recovery-tool -a system_backup -p ${backup_file_path} -r || exit -1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:第${test_index}次测试，当前测试系统备份！" >> ${auto_test_log}
        ;;
    "manual_restore1")  #还原系统备份
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原前删除文件！" >> ${auto_test_log}
        rm -rf /home/uos/Desktop/testfolder    #桌面文件
        rm -rf /testfolder    #根目录文件
        rm -rf /boot/testfolder    #boot分区文件
        rm -rf /opt/testfolder    #opt分区文件
        rm -rf /var/testfolder    #var分区文件
        getRestorePath
        echo "begin manual restore:${backup_file_path}/${restore_path}"
        deepin-recovery-tool -a manual_restore -p ${backup_file_path}/${restore_path} -r || exit -1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:第${test_index}次测试，当前测试还原系统备份！" >> ${auto_test_log}
        ;;
    "manual_backup")    #全盘备份
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:检查系统还原文件！" >> ${auto_test_log}
        if [ -e "/home/uos/Desktop/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，桌面文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，桌面文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，根目录文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，根目录文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/boot/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，boot分区文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，boot分区文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/opt/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，opt分区文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，opt分区文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/var/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，var分区文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原，var分区文件不存在，测试失败！" >> ${result_file_log}
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘备份前创建文件！" >> ${auto_test_log}
        cp -r /recovery/testfolder /home/uos/Desktop/    #桌面文件
        cp -r /recovery/testfolder /    #根目录文件
        cp -r /recovery/testfolder /boot/    #boot分区文件
        cp -r /recovery/testfolder /opt/    #opt分区文件
        cp -r /recovery/testfolder /var/    #var分区文件
        rm -rf ${backup_file_path}/*
        echo "begin manual backup:${backup_file_path}"
        deepin-recovery-tool -a manual_backup -p ${backup_file_path} -r || exit -1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:第${test_index}次测试，当前测试全盘备份！" >> ${auto_test_log}
        ;;
    "manual_restore2")  #还原全盘还原
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原前删除文件！" >> ${auto_test_log}
        rm -rf /home/uos/Desktop/testfolder    #桌面文件
        rm -rf /testfolder    #根目录文件
        rm -rf /boot/testfolder    #boot分区文件
        rm -rf /opt/testfolder    #opt分区文件
        rm -rf /var/testfolder    #var分区文件
        getRestorePath
        echo "begin manual restore:${backup_file_path}/${restore_path}"
        deepin-recovery-tool -a manual_restore -p ${backup_file_path}/${restore_path} -r || exit -1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:第${test_index}次测试，当前测试还原全盘备份！" >> ${auto_test_log}
        ;;
    "system_restore1")  #系统还原保留用户数据
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:检查全盘还原文件！" >> ${auto_test_log}
        if [ -e "/home/uos/Desktop/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，桌面文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，桌面文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，根目录文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，根目录文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/boot/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，boot分区文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，boot分区文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/opt/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，opt分区文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，opt分区文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/var/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，var分区文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:全盘还原，var分区文件不存在，测试失败！" >> ${result_file_log}
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原前创建文件！" >> ${auto_test_log}
        cp -r /recovery/testfolder /home/uos/Desktop/    #桌面文件
        cp -r /recovery/testfolder /    #根目录文件
        cp -r /recovery/testfolder /boot/    #boot分区文件
        cp -r /recovery/testfolder /opt/    #opt分区文件
        cp -r /recovery/testfolder /var/    #var分区文件
        echo "begin system restore and keep user data"
        deepin-recovery-tool -a system_restore -r || exit -1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:第${test_index}次测试，当前测试系统还原并保留用户数据！" >> ${auto_test_log}
        ;;
    "system_restore2")  #系统还原不保留用户数据
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:检查系统还原保留用户数据！" >> ${auto_test_log}
        if [ -e "/home/uos/Desktop/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，桌面文件存在，测试通过！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，桌面文件不存在，测试失败！" >> ${result_file_log}
        fi
        if [ -e "/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，根目录文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，根目录文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/boot/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，boot分区文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，boot分区文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/opt/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，opt分区文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，opt分区文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/var/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，var分区文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原保留用户数据，var分区文件不存在，测试通过！" >> ${result_file_log}
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原前创建文件！" >> ${auto_test_log}
        cp -r /recovery/testfolder /home/uos/Desktop/    #桌面文件
        cp -r /recovery/testfolder /    #根目录文件
        cp -r /recovery/testfolder /boot/    #boot分区文件
        cp -r /recovery/testfolder /opt/    #opt分区文件
        cp -r /recovery/testfolder /var/    #var分区文件
        echo "begin system restore without user data"
        deepin-recovery-tool -a system_restore -f -r || exit -1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:第${test_index}次测试，当前测试系统还原并不保留用户数据！" >> ${auto_test_log}
        ;;
    "end_file_check") #最后检查文件是否清空
        echo "check file exist"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]:检查系统还原不保留用户数据！" >> ${auto_test_log}
        if [ -e "/home/uos/Desktop/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，桌面文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，桌面文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，根目录文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，根目录文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/boot/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，boot分区文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，boot分区文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/opt/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，opt分区文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，opt分区文件不存在，测试通过！" >> ${result_file_log}
        fi
        if [ -e "/var/testfolder/testfile.txt" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，var分区文件存在，测试失败！" >> ${result_file_log}
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]:系统还原不保留用户数据，var分区文件不存在，测试通过！" >> ${result_file_log}
        fi
        ;;
esac

# 将当前测试次数和测试内容写入到文件中
echo "index=${test_index}" > ${auto_test_file}
echo "mode=${test_mode}" >> ${auto_test_file}

reboot
