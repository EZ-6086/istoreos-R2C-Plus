#!/bin/bash

# 在编译前执行的脚本
cd istoreos/openwrt

# 创建自定义文件系统
mkdir -p files/etc/uci-defaults
mkdir -p files/root

# 设置默认配置
cat > files/etc/uci-defaults/99-custom << 'EOF'
#!/bin/sh

# 设置时区
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system

# 默认主题
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# 启用BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# R2C Plus性能优化
echo "net.core.rmem_max=2500000" >> /etc/sysctl.conf
echo "net.core.wmem_max=2500000" >> /etc/sysctl.conf

# 创建iStoreOS目录结构
mkdir -p /mnt/sda1/istore
ln -sf /mnt/sda1/istore /iStore

# 添加软件源
cat > /etc/opkg/customfeeds.conf << 'EOL'
src/gz istore https://istore.linkease.com/repo/all/store
src/gz istore_extra https://istore.linkease.com/repo/all/extra
src/gz friendlywrt https://github.com/friendlyarm/friendlywrt/raw/master-master-24.10/packages/rockchip/armv8
EOL

exit 0
EOF
chmod 755 files/etc/uci-defaults/99-custom

# 添加SSH欢迎信息
cat > files/etc/banner << 'EOF'
  ___ _   _ _____ ___ _   _  ___ 
 |_ _| \ | |_   _|_ _| \ | |/ __|
  | ||  \| | | |  | ||  \| |\__ \
  | || |\  | | |  | || |\  | ___) |
 |___|_| \_| |_| |___|_| \_||____/ 

 Welcome to iStoreOS for R2C Plus
      Custom Build $(date +%Y%m%d)
EOF

# 添加性能监控脚本
cat > files/root/system_monitor.sh << 'EOF'
#!/bin/sh

while true; do
    clear
    echo "===== System Monitor ====="
    echo "CPU Load: $(uptime | awk -F'[a-z]:' '{print $2}')"
    echo "Memory: $(free -m | awk 'NR==2{printf "%.2f%%", $3 * 100/$2}')"
    echo "Temperature: $(sensors | grep temp1 | awk '{print $2}')"
    echo "Network:"
    ifconfig | grep -E 'eth[0-9]|wlan[0-9]' | awk '/inet / {print $2}'
    sleep 5
done
EOF
chmod +x files/root/system_monitor.sh