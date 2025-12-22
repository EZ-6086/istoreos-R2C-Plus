#!/bin/bash

echo "开始应用R2C Plus补丁..."

# 进入OpenWrt源码目录
cd istoreos/openwrt

# 应用所有补丁
if [ -d "../../patches" ]; then
    for patch in ../../patches/*.patch; do
        if [ -f "$patch" ]; then
            echo "应用补丁: $(basename $patch)"
            if git apply --check "$patch" 2>/dev/null; then
                git apply "$patch"
                echo "补丁应用成功"
            else
                echo "警告: 补丁可能已应用或存在冲突，跳过"
            fi
        fi
    done
fi

# 确保R2C Plus设备定义存在
if ! grep -q "friendlyarm_nanopi-r2c-plus" target/linux/rockchip/image/armv8.mk 2>/dev/null; then
    echo "添加R2C Plus设备支持..."
    cat << 'EOF' >> target/linux/rockchip/image/armv8.mk

define Device/friendlyarm_nanopi-r2c-plus
  DEVICE_VENDOR := FriendlyARM
  DEVICE_MODEL := NanoPi R2C Plus
  SOC := rk3328
  UBOOT_DEVICE_NAME := nanopi-r2c-plus-rk3328
  IMAGE/sysupgrade.img.gz := boot-combined | boot-script nanopi-r2c-plus | sdcard-img | gzip | append-metadata
  DEVICE_PACKAGES := kmod-usb-net-rtl8152 kmod-r8169 kmod-ata-ahci kmod-ata-core
  SUPPORTED_DEVICES += nanopi-r2c-plus
endef
TARGET_DEVICES += friendlyarm_nanopi-r2c-plus
EOF
fi

# 更新网络配置
mkdir -p target/linux/rockchip/armv8/base-files/etc/board.d
mkdir -p target/linux/rockchip/armv8/base-files/etc/hotplug.d/net

# 添加R2C Plus网络配置
if [ ! -f "target/linux/rockchip/armv8/base-files/etc/board.d/02_network" ]; then
    touch target/linux/rockchip/armv8/base-files/etc/board.d/02_network
fi

if ! grep -q "nanopi-r2c-plus" target/linux/rockchip/armv8/base-files/etc/board.d/02_network; then
    echo "添加R2C Plus网络配置..."
    cat << 'EOF' >> target/linux/rockchip/armv8/base-files/etc/board.d/02_network

nanopi-r2c-plus)
    ucidef_set_interfaces_lan "eth0"
    
    # 如果有USB网卡，则作为WAN口
    if [ -e "/sys/class/net/eth1" ]; then
        ucidef_set_interface_wan "eth1"
    fi
    
    # 启用硬件加速
    ethtool -K eth0 rx on tx on 2>/dev/null || true
    
    # 设置MTU
    ip link set dev eth0 mtu 1500 2>/dev/null || true
    
    ;;
EOF
fi

# 添加R2C Plus热插拔配置
if [ ! -f "target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/10-r2cplus-net" ]; then
    echo "创建R2C Plus热插拔配置..."
    cat << 'EOF' > target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/10-r2cplus-net
#!/bin/sh

[ "$ACTION" = "add" ] || exit 0

. /lib/functions.sh
. /lib/functions/network.sh

case "$(board_name)" in
friendlyarm,nanopi-r2c-plus)
    # 检测USB网卡插入
    if [ "$INTERFACE" = "eth1" ]; then
        logger -t r2cplus "USB网卡检测到，设置为WAN口"
        uci set network.wan.device="eth1"
        uci set network.wan.proto="dhcp"
        uci commit network
        /etc/init.d/network reload
    fi
    ;;
esac

exit 0
EOF
    chmod +x target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/10-r2cplus-net
fi

# 添加R2C Plus的uboot配置
if [ ! -f "target/linux/rockchip/armv8/base-files/etc/board.d/01_r2cplus_uboot" ]; then
    echo "创建R2C Plus U-Boot配置..."
    cat << 'EOF' > target/linux/rockchip/armv8/base-files/etc/board.d/01_r2cplus_uboot
#!/bin/sh

. /lib/functions.sh
. /lib/functions/system.sh

case "$(board_name)" in
friendlyarm,nanopi-r2c-plus)
    # 设置串口控制台
    echo "ttyS2" > /sys/devices/virtual/tty/console/active
    
    # 优化性能设置
    echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || true
    
    # 启用所有CPU核心
    echo 1 > /sys/devices/system/cpu/cpu1/online 2>/dev/null || true
    echo 1 > /sys/devices/system/cpu/cpu2/online 2>/dev/null || true
    echo 1 > /sys/devices/system/cpu/cpu3/online 2>/dev/null || true
    
    # 内存优化
    echo 0 > /proc/sys/vm/swappiness
    echo 100 > /proc/sys/vm/vfs_cache_pressure
    
    ;;
esac

exit 0
EOF
    chmod +x target/linux/rockchip/armv8/base-files/etc/board.d/01_r2cplus_uboot
fi

echo "R2C Plus补丁应用完成！"