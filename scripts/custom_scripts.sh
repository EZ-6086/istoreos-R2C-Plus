#!/bin/bash

echo "开始执行自定义配置脚本..."

# 进入OpenWrt源码目录
cd istoreos/openwrt

# 创建文件系统覆盖目录
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/config
mkdir -p files/etc/init.d
mkdir -p files/root
mkdir -p files/www

# 1. 设置网络配置（IP: 192.168.101.1）
cat > files/etc/config/network << 'EOF'
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd00:101::/48'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.101.1'
	option netmask '255.255.255.0'
	option ip6assign '60'
	option delegate '0'
	option force_link '1'

config interface 'wan'
	option device 'eth1'
	option proto 'dhcp'
	option peerdns '0'
	list dns '114.114.114.114'
	list dns '8.8.8.8'

config interface 'wan6'
	option device 'eth1'
	option proto 'dhcpv6'
EOF

# 2. 设置DHCP配置
cat > files/etc/config/dhcp << 'EOF'
config dnsmasq
	option domainneeded '1'
	option boguspriv '1'
	option filterwin2k '0'
	option localise_queries '1'
	option rebind_protection '1'
	option rebind_localhost '1'
	option local '/lan/'
	option domain 'lan'
	option expandhosts '1'
	option nonegcache '0'
	option authoritative '1'
	option readethers '1'
	option leasefile '/tmp/dhcp.leases'
	option noresolv '0'
	option localservice '1'
	option cachelocal '1'
	option cachesize '1000'
	option ednspacket_max '1232'
	option port '53'
	list server '114.114.114.114'
	list server '8.8.8.8'

config dhcp 'lan'
	option interface 'lan'
	option start '100'
	option limit '150'
	option leasetime '12h'
	option dhcpv4 'server'
	option dhcpv6 'server'
	option ra 'server'
	option ra_management '1'
	list dhcp_option '6,192.168.101.1,114.114.114.114,8.8.8.8'
	list dhcp_option '3,192.168.101.1'

config dhcp 'wan'
	option interface 'wan'
	option ignore '1'

config odhcpd 'odhcpd'
	option maindhcp '0'
	option leasefile '/tmp/hosts/odhcpd'
	option leasetrigger '/usr/sbin/odhcpd-update'
	option loglevel '4'
EOF

# 3. 设置防火墙配置
cat > files/etc/config/firewall << 'EOF'
config defaults
	option syn_flood '1'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option disable_ipv6 '0'

config zone
	option name 'lan'
	list network 'lan'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'ACCEPT'
	option masq '1'
	option mtu_fix '1'

config zone
	option name 'wan'
	list network 'wan'
	list network 'wan6'
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option masq '1'
	option mtu_fix '1'

config forwarding
	option src 'lan'
	option dest 'wan'

config rule
	option name 'Allow-DHCP-Renew'
	option src 'wan'
	option proto 'udp'
	option dest_port '68'
	option target 'ACCEPT'
	option family 'ipv4'

config rule
	option name 'Allow-Ping'
	option src 'wan'
	option proto 'icmp'
	option icmp_type 'echo-request'
	option family 'ipv4'
	option target 'ACCEPT'

config rule
	option name 'Allow-IGMP'
	option src 'wan'
	option proto 'igmp'
	option family 'ipv4'
	option target 'ACCEPT'

config rule
	option name 'Allow-DHCPv6'
	option src 'wan'
	option proto 'udp'
	option src_ip 'fc00::/6'
	option dest_port '546'
	option family 'ipv6'
	option target 'ACCEPT'

config rule
	option name 'Allow-MLD'
	option src 'wan'
	option proto 'icmp'
	option src_ip 'fe80::/10'
	list icmp_type '130/0'
	list icmp_type '131/0'
	list icmp_type '132/0'
	list icmp_type '143/0'
	option family 'ipv6'
	option target 'ACCEPT'

config rule
	option name 'Allow-ICMPv6-Input'
	option src 'wan'
	option proto 'icmp'
	list icmp_type 'echo-request'
	list icmp_type 'echo-reply'
	list icmp_type 'destination-unreachable'
	list icmp_type 'packet-too-big'
	list icmp_type 'time-exceeded'
	list icmp_type 'bad-header'
	list icmp_type 'unknown-header-type'
	list icmp_type 'router-solicitation'
	list icmp_type 'neighbour-solicitation'
	list icmp_type 'router-advertisement'
	list icmp_type 'neighbour-advertisement'
	option limit '1000/sec'
	option family 'ipv6'
	option target 'ACCEPT'

config rule
	option name 'Allow-ICMPv6-Forward'
	option src 'wan'
	option dest '*'
	option proto 'icmp'
	list icmp_type 'echo-request'
	list icmp_type 'echo-reply'
	list icmp_type 'destination-unreachable'
	list icmp_type 'packet-too-big'
	list icmp_type 'time-exceeded'
	list icmp_type 'bad-header'
	list icmp_type 'unknown-header-type'
	option limit '1000/sec'
	option family 'ipv6'
	option target 'ACCEPT'

config include
	option path '/etc/firewall.user'
EOF

# 4. 创建自定义防火墙规则
cat > files/etc/firewall.user << 'EOF'
# 自定义防火墙规则
# 允许SSH访问
iptables -A input_wan -p tcp --dport 22 -j ACCEPT

# 允许Web管理访问
iptables -A input_wan -p tcp --dport 80 -j REJECT
iptables -A input_wan -p tcp --dport 443 -j REJECT

# 允许UPnP
iptables -A input_wan -p udp --dport 1900 -j ACCEPT
iptables -A input_wan -p tcp --dport 5000 -j ACCEPT

# 允许NTP
iptables -A input_wan -p udp --dport 123 -j ACCEPT
EOF

# 5. 创建启动脚本
cat > files/etc/uci-defaults/99-custom-config << 'EOF'
#!/bin/sh

# 设置时区
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system

# 默认主题
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set luci.main.lang='zh_cn'
uci commit luci

# 设置主机名
uci set system.@system[0].hostname='R2CPlus-iStoreOS'
uci set system.@system[0].timezone='CST-8'
uci commit system

# 网络配置
uci set network.lan.ipaddr='192.168.101.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.101.1'
uci set network.lan.dns='192.168.101.1 114.114.114.114 8.8.8.8'
uci commit network

# DHCP配置
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci commit dhcp

# 无线配置（如果有）
if [ -f /etc/config/wireless ]; then
    uci set wireless.@wifi-device[0].disabled='0'
    uci set wireless.@wifi-iface[0].ssid='R2CPlus-iStoreOS'
    uci set wireless.@wifi-iface[0].encryption='psk2'
    uci set wireless.@wifi-iface[0].key='12345678'
    uci commit wireless
fi

# 启用BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo "net.core.rmem_max=2500000" >> /etc/sysctl.conf
echo "net.core.wmem_max=2500000" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling=1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_sack=1" >> /etc/sysctl.conf
sysctl -p 2>/dev/null

# 创建iStoreOS目录结构
mkdir -p /mnt/sda1/istore
ln -sf /mnt/sda1/istore /iStore 2>/dev/null || true

# 添加软件源
cat > /etc/opkg/customfeeds.conf << 'EOL'
src/gz istore https://istore.linkease.com/repo/all/store
src/gz istore_extra https://istore.linkease.com/repo/all/extra
src/gz friendlywrt https://github.com/friendlyarm/friendlywrt/raw/master-master-24.10/packages/rockchip/armv8
EOL

# 设置root密码（密码：admin）
echo -e "admin\nadmin" | passwd root 2>/dev/null

# 禁用IPv6防火墙（可选，根据需要开启）
# uci set firewall.@defaults[0].disable_ipv6='1'
# uci commit firewall

# 重启服务
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

# 删除自己，只运行一次
rm -f /etc/uci-defaults/99-custom-config

exit 0
EOF
chmod 755 files/etc/uci-defaults/99-custom-config

# 6. 创建SSH欢迎信息
cat > files/etc/banner << 'EOF'
  ___ _   _ _____ ___ _   _  ___ 
 |_ _| \ | |_   _|_ _| \ | |/ __|
  | ||  \| | | |  | ||  \| |\__ \
  | || |\  | | |  | || |\  | ___) |
 |___|_| \_| |_| |___|_| \_||____/ 

 Welcome to iStoreOS for R2C Plus
      Custom Build $(date +%Y%m%d)
      LAN IP: 192.168.101.1
   Default Password: admin
------------------------------------
EOF

# 7. 创建性能监控脚本
cat > files/root/system_monitor.sh << 'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

while true; do
    clear
    echo -e "${BLUE}===== R2C Plus 系统监控 =====${NC}"
    echo -e "系统时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "运行时间: $(uptime -p | sed 's/up //')"
    echo ""
    
    # CPU信息
    CPU_TEMP=$(sensors 2>/dev/null | grep -E 'temp1|Core' | awk '{print $2}' | head -1)
    CPU_LOAD=$(uptime | awk -F'[a-z]:' '{print $2}' | xargs)
    echo -e "${GREEN}CPU 信息:${NC}"
    echo -e "  温度: ${CPU_TEMP:-N/A}"
    echo -e "  负载: ${CPU_LOAD}"
    echo ""
    
    # 内存信息
    MEM_TOTAL=$(free -m | awk 'NR==2{printf "%.1f", $2/1024}')
    MEM_USED=$(free -m | awk 'NR==2{printf "%.1f", $3/1024}')
    MEM_PERCENT=$(free | awk 'NR==2{printf "%.2f%%", $3 * 100/$2}')
    echo -e "${GREEN}内存信息:${NC}"
    echo -e "  总量: ${MEM_TOTAL} GB"
    echo -e "  已用: ${MEM_USED} GB (${MEM_PERCENT})"
    echo ""
    
    # 网络信息
    echo -e "${GREEN}网络接口:${NC}"
    ip -o addr show | grep -E 'eth|wlan' | awk '{print $2": "$4}' | while read line; do
        echo -e "  $line"
    done
    echo ""
    
    # 磁盘信息
    echo -e "${GREEN}磁盘使用:${NC}"
    df -h | grep -E '^/dev/|overlay' | awk '{print $1": "$3"/"$2" ("$5")"}' | while read line; do
        echo -e "  $line"
    done
    echo ""
    
    # Docker状态
    if command -v docker &> /dev/null; then
        DOCKER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
        echo -e "${GREEN}Docker 容器:${NC} ${DOCKER_COUNT} 个运行中"
    fi
    
    echo -e "${YELLOW}按 Ctrl+C 退出监控${NC}"
    sleep 5
done
EOF
chmod +x files/root/system_monitor.sh

# 8. 创建默认Web页面
cat > files/www/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>R2C Plus iStoreOS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Microsoft YaHei', Arial, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 600px;
            width: 90%;
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
            font-size: 2.5em;
        }
        .logo {
            font-size: 4em;
            margin-bottom: 20px;
            color: #667eea;
        }
        .info-box {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
            text-align: left;
        }
        .info-box h3 {
            color: #667eea;
            margin-bottom: 10px;
        }
        .btn {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 25px;
            margin: 10px;
            transition: all 0.3s;
            border: 2px solid #667eea;
        }
        .btn:hover {
            background: white;
            color: #667eea;
        }
        .btn-secondary {
            background: #6c757d;
            border-color: #6c757d;
        }
        .btn-secondary:hover {
            background: white;
            color: #6c757d;
        }
        .tips {
            color: #666;
            font-size: 0.9em;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>R2C Plus iStoreOS</h1>
        <p>基于 iStoreOS 和 FriendlyWrt 24.10 的定制固件</p>
        
        <div class="info-box">
            <h3>📱 管理界面</h3>
            <p>请访问: <a href="http://192.168.101.1" target="_blank">http://192.168.101.1</a></p>
            <p>默认用户名: <strong>root</strong></p>
            <p>默认密码: <strong>admin</strong></p>
        </div>
        
        <div class="info-box">
            <h3>🔧 主要特性</h3>
            <ul style="padding-left: 20px;">
                <li>iStore 应用商店支持</li>
                <li>FriendlyWrt 24.10 兼容性</li>
                <li>Docker 容器支持</li>
                <li>iStoreX 插件系统</li>
                <li>Argon 主题界面</li>
            </ul>
        </div>
        
        <div>
            <a href="http://192.168.101.1" class="btn">进入管理界面</a>
            <a href="http://192.168.101.1/cgi-bin/luci/admin/istore" class="btn btn-secondary">打开 iStore</a>
        </div>
        
        <div class="tips">
            <p>💡 提示: 首次登录请立即修改默认密码！</p>
            <p>📅 构建日期: __BUILD_DATE__</p>
        </div>
    </div>
    
    <script>
        // 更新构建日期
        document.querySelector('.tips p:last-child').innerHTML = 
            document.querySelector('.tips p:last-child').innerHTML.replace('__BUILD_DATE__', new Date().toLocaleDateString('zh-CN'));
    </script>
</body>
</html>
EOF

# 9. 创建服务脚本
cat > files/etc/init.d/custom-service << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    echo "Starting custom services..."
    
    # 启用性能优化
    echo 1 > /proc/sys/net/ipv4/tcp_window_scaling
    echo 1 > /proc/sys/net/ipv4/tcp_sack
    
    # 设置CPU调度
    echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || true
    
    # 创建必要目录
    mkdir -p /var/log/custom
    mkdir -p /tmp/custom
    
    # 启动自定义监控
    /root/system_monitor.sh > /dev/null 2>&1 &
    
    echo "Custom services started."
}

stop() {
    echo "Stopping custom services..."
    killall system_monitor.sh 2>/dev/null || true
    echo "Custom services stopped."
}
EOF
chmod +x files/etc/init.d/custom-service

# 10. 创建首次启动脚本
cat > files/etc/uci-defaults/10-first-boot << 'EOF'
#!/bin/sh

# 首次启动配置
LOGFILE="/tmp/first-boot.log"

echo "=== 首次启动配置 $(date) ===" > $LOGFILE

# 检查是否已经配置过
if [ -f /etc/config/first-boot-done ]; then
    echo "已执行过首次启动配置，跳过" >> $LOGFILE
    exit 0
fi

echo "1. 设置root密码" >> $LOGFILE
echo -e "admin\nadmin" | passwd root >> $LOGFILE 2>&1

echo "2. 配置网络" >> $LOGFILE
uci set network.lan.ipaddr='192.168.101.1' >> $LOGFILE 2>&1
uci commit network >> $LOGFILE 2>&1

echo "3. 配置SSH" >> $LOGFILE
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci commit dropbear
/etc/init.d/dropbear restart >> $LOGFILE 2>&1

echo "4. 启用服务" >> $LOGFILE
/etc/init.d/custom-service enable >> $LOGFILE 2>&1
/etc/init.d/custom-service start >> $LOGFILE 2>&1

echo "5. 创建标记文件" >> $LOGFILE
touch /etc/config/first-boot-done

echo "首次启动配置完成" >> $LOGFILE
echo "管理地址: http://192.168.101.1" >> $LOGFILE
echo "用户名: root, 密码: admin" >> $LOGFILE

# 删除自己
rm -f /etc/uci-defaults/10-first-boot

exit 0
EOF
chmod 755 files/etc/uci-defaults/10-first-boot

echo "自定义配置脚本执行完成！"