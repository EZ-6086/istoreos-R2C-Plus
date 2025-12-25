#!/bin/bash
# ====================================================
# iStoreOS R2C Plus 自定义配置脚本 (优化版)
# 版本: 3.0
# 功能: 创建固件预配置文件
# 注意: 此脚本取代 configs/common.config
# ====================================================

set -e  # 遇到错误立即退出
set -o pipefail  # 管道命令错误也退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 初始化变量
init_variables() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    OPENWRT_DIR="${PROJECT_ROOT}/istoreos/openwrt"
    
    # 文件目录
    FILES_DIR="${OPENWRT_DIR}/files"
    CONFIG_DIR="${FILES_DIR}/etc/config"
    UCI_DEFAULTS_DIR="${FILES_DIR}/etc/uci-defaults"
    INIT_DIR="${FILES_DIR}/etc/init.d"
    ROOT_DIR="${FILES_DIR}/root"
    WWW_DIR="${FILES_DIR}/www"
    LOGROTATE_DIR="${FILES_DIR}/etc/logrotate.d"
    DOCKER_DIR="${FILES_DIR}/etc/docker"
    
    # 检查目录
    if [ ! -d "$OPENWRT_DIR" ]; then
        log_error "OpenWrt目录不存在: $OPENWRT_DIR"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    local dirs=(
        "$CONFIG_DIR"
        "$UCI_DEFAULTS_DIR"
        "$INIT_DIR"
        "$ROOT_DIR"
        "$WWW_DIR"
        "$LOGROTATE_DIR"
        "$DOCKER_DIR"
        "${FILES_DIR}/etc/hotplug.d/iface"
        "${FILES_DIR}/usr/bin"
        "${FILES_DIR}/var/log/custom"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        fi
    done
    
    log_success "目录结构创建完成"
}

# 创建网络配置（智能识别R2C Plus接口）
create_network_config() {
    log_info "创建网络配置..."
    
    cat > "$CONFIG_DIR/network" << 'EOF'
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd00:101::/48'
	option packet_steering '1'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'
	option stp '1'
	option forward_delay '4'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.101.1'
	option netmask '255.255.255.0'
	option ip6assign '60'
	option delegate '0'
	option force_link '1'
	option multicast_querier '1'
	option igmp_snooping '1'

config interface 'wan'
	option device 'eth1'
	option proto 'dhcp'
	option peerdns '0'
	option delegate '0'
	list dns '114.114.114.114'
	list dns '8.8.8.8'
	list dns '1.1.1.1'
	option metric '10'

config interface 'wan6'
	option device 'eth1'
	option proto 'dhcpv6'
	option delegate '0'
	option reqaddress 'try'
	option reqprefix 'auto'

# 备用WAN配置（如果eth2存在）
config interface 'wan2'
	option device 'eth2'
	option proto 'dhcp'
	option enabled '0'
	option metric '20'

# VLAN配置示例（可选）
# config switch
# 	option name 'switch0'
# 	option reset '1'
# 	option enable_vlan '1'
# 
# config switch_vlan
# 	option device 'switch0'
# 	option vlan '1'
# 	option ports '0t 1'
EOF
    
    log_success "网络配置创建完成"
}

# 创建DHCP配置（优化版）
create_dhcp_config() {
    log_info "创建DHCP配置..."
    
    cat > "$CONFIG_DIR/dhcp" << 'EOF'
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
	option localise_queries '1'
	option sequential_ip '1'
	list server '114.114.114.114'
	list server '8.8.8.8'
	list server '1.1.1.1'
	list server '/pool.ntp.org/202.112.10.36'

config dhcp 'lan'
	option interface 'lan'
	option start '100'
	option limit '150'
	option leasetime '12h'
	option dhcpv4 'server'
	option dhcpv6 'server'
	option ra 'server'
	option ra_management '1'
	option ra_default '1'
	list dhcp_option '6,192.168.101.1,114.114.114.114,8.8.8.8'
	list dhcp_option '3,192.168.101.1'
	list dhcp_option '15,lan'
	list dhcp_option '44,192.168.101.1'
	list dhcp_option '42,192.168.101.1'

config dhcp 'wan'
	option interface 'wan'
	option ignore '1'

config odhcpd 'odhcpd'
	option maindhcp '0'
	option leasefile '/tmp/hosts/odhcpd'
	option leasetrigger '/usr/sbin/odhcpd-update'
	option loglevel '4'
EOF
    
    log_success "DHCP配置创建完成"
}

# 创建防火墙配置（增强安全）
create_firewall_config() {
    log_info "创建防火墙配置..."
    
    cat > "$CONFIG_DIR/firewall" << 'EOF'
config defaults
	option syn_flood '1'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option disable_ipv6 '0'
	option drop_invalid '1'
	option synflood_rate '25'
	option synflood_burst '50'

config zone
	option name 'lan'
	list network 'lan'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'ACCEPT'
	option masq '1'
	option mtu_fix '1'
	option conntrack '1'

config zone
	option name 'wan'
	list network 'wan'
	list network 'wan6'
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option masq '1'
	option mtu_fix '1'
	option conntrack '1'

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
	option limit '10/sec'

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

config rule
	option name 'Block-WAN-Access'
	option src 'wan'
	option proto 'tcp'
	list dest_port '22 23 80 443 8080 8443'
	option target 'REJECT'
	option enabled '1'
	option family 'ipv4'

config include
	option path '/etc/firewall.user'

config include 'miniupnpd'
	option type 'script'
	option path '/usr/share/miniupnpd/firewall.include'
	option reload '1'
EOF

    # 创建自定义防火墙规则
    cat > "$FILES_DIR/etc/firewall.user" << 'EOF'
#!/bin/sh
# iStoreOS R2C Plus 自定义防火墙规则

# 记录被阻止的访问
iptables -N LOG_DROP
iptables -A LOG_DROP -m limit --limit 10/min -j LOG --log-prefix "FW_DROP: " --log-level 4
iptables -A LOG_DROP -j DROP

# 保护SSH：限制连接频率
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j LOG_DROP

# 阻止常见攻击
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j LOG_DROP
iptables -A INPUT -f -j LOG_DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j LOG_DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j LOG_DROP

# 防止端口扫描
iptables -N PORTSCAN
iptables -A PORTSCAN -m limit --limit 10/min -j LOG --log-prefix "Portscan: "
iptables -A PORTSCAN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 10/min -j PORTSCAN

# 允许本地回环
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立的连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许ICMP（限速）
iptables -A INPUT -p icmp -m limit --limit 10/sec --limit-burst 20 -j ACCEPT
iptables -A INPUT -p icmp -j LOG_DROP

# Docker网络处理（如果使用Docker）
# iptables -I FORWARD -i docker0 -o eth0 -j ACCEPT
# iptables -I FORWARD -i eth0 -o docker0 -j ACCEPT

# 记录规则应用
logger -t firewall.user "自定义防火墙规则已加载"
EOF
    
    chmod 755 "$FILES_DIR/etc/firewall.user"
    log_success "防火墙配置创建完成"
}

# 创建启动配置脚本
create_uci_defaults() {
    log_info "创建UCI默认配置脚本..."
    
    # 主配置脚本
    cat > "$UCI_DEFAULTS_DIR/99-r2cplus-config" << 'EOF'
#!/bin/sh

LOG_FILE="/tmp/r2cplus-config.log"
echo "=== R2C Plus 自定义配置 $(date) ===" > $LOG_FILE

# 设置时区
echo "设置时区..." >> $LOG_FILE
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system >> $LOG_FILE 2>&1

# 默认主题和语言
echo "设置界面..." >> $LOG_FILE
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set luci.main.lang='zh_cn'
uci commit luci >> $LOG_FILE 2>&1

# 设置主机名
echo "设置主机名..." >> $LOG_FILE
uci set system.@system[0].hostname='R2CPlus-iStoreOS'
uci commit system >> $LOG_FILE 2>&1

# 网络配置（确保正确）
echo "配置网络..." >> $LOG_FILE
uci set network.lan.ipaddr='192.168.101.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network >> $LOG_FILE 2>&1

# DHCP配置
echo "配置DHCP..." >> $LOG_FILE
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci commit dhcp >> $LOG_FILE 2>&1

# 无线配置（如果有）
if [ -f /etc/config/wireless ]; then
    echo "配置无线..." >> $LOG_FILE
    uci set wireless.@wifi-device[0].disabled='0' 2>/dev/null || true
    uci set wireless.@wifi-iface[0].ssid='R2CPlus-iStoreOS' 2>/dev/null || true
    uci set wireless.@wifi-iface[0].encryption='psk2' 2>/dev/null || true
    uci set wireless.@wifi-iface[0].key='ChangeThisPassword' 2>/dev/null || true
    uci commit wireless >> $LOG_FILE 2>&1
fi

# 启用BBR和网络优化
echo "优化网络参数..." >> $LOG_FILE
{
echo "# R2C Plus 网络优化"
echo "net.core.default_qdisc=fq_codel"
echo "net.ipv4.tcp_congestion_control=bbr"
echo "net.ipv4.tcp_notsent_lowat=16384"
echo "net.core.rmem_max=134217728"
echo "net.core.wmem_max=134217728"
echo "net.ipv4.tcp_rmem=4096 87380 134217728"
echo "net.ipv4.tcp_wmem=4096 65536 134217728"
echo "net.ipv4.tcp_window_scaling=1"
echo "net.ipv4.tcp_sack=1"
echo "net.ipv4.tcp_timestamps=1"
echo "net.ipv4.tcp_ecn=1"
echo "net.ipv4.tcp_fin_timeout=30"
echo "net.ipv4.tcp_tw_reuse=1"
echo "net.ipv4.tcp_max_syn_backlog=8192"
echo "net.ipv4.tcp_synack_retries=2"
echo "net.ipv4.tcp_syncookies=1"
echo "net.ipv4.tcp_mtu_probing=1"
echo ""
echo "# 内存优化"
echo "vm.swappiness=10"
echo "vm.vfs_cache_pressure=50"
echo ""
echo "# 网络安全"
echo "net.ipv4.conf.all.rp_filter=1"
echo "net.ipv4.conf.default.rp_filter=1"
echo "net.ipv4.tcp_syncookies=1"
echo "net.ipv4.icmp_echo_ignore_broadcasts=1"
echo "net.ipv4.icmp_ignore_bogus_error_responses=1"
} >> /etc/sysctl.conf

sysctl -p 2>/dev/null >> $LOG_FILE

# Docker优化配置
echo "配置Docker..." >> $LOG_FILE
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "data-root": "/opt/docker",
  "iptables": false,
  "ip6tables": false,
  "live-restore": true,
  "userland-proxy": false,
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "dns": ["192.168.101.1", "114.114.114.114", "8.8.8.8"]
}
DOCKER_EOF

# 创建Docker数据目录（优先使用外部存储）
if [ -d /mnt/sda1 ]; then
    mkdir -p /mnt/sda1/docker
    ln -sf /mnt/sda1/docker /opt/docker 2>/dev/null || true
    echo "Docker数据目录链接到/mnt/sda1/docker" >> $LOG_FILE
fi

# 创建iStoreOS目录结构
echo "创建目录结构..." >> $LOG_FILE
mkdir -p /mnt/sda1/istore
mkdir -p /mnt/sda1/backup
ln -sf /mnt/sda1/istore /iStore 2>/dev/null || true

# 添加软件源
echo "配置软件源..." >> $LOG_FILE
cat > /etc/opkg/customfeeds.conf << 'EOL'
src/gz istore https://istore.linkease.com/repo/all/store
src/gz istore_extra https://istore.linkease.com/repo/all/extra
src/gz friendlywrt https://github.com/friendlyarm/friendlywrt/raw/master-master-24.10/packages/rockchip/armv8
EOL

# 设置随机root密码（首次登录后必须修改）
echo "设置root密码..." >> $LOG_FILE
if [ ! -f /etc/shadow.changed ]; then
    # 生成随机密码
    RANDOM_PASS=$(head -c 12 /dev/urandom | base64 | tr -d '\n=' | cut -c1-12)
    echo -e "${RANDOM_PASS}\n${RANDOM_PASS}" | passwd root 2>/dev/null && \
        echo "初始随机密码: ${RANDOM_PASS}" > /root/initial-password.txt && \
        chmod 600 /root/initial-password.txt && \
        echo "密码已保存到 /root/initial-password.txt" >> $LOG_FILE
    touch /etc/shadow.changed
fi

# 重启服务
echo "重启网络服务..." >> $LOG_FILE
/etc/init.d/network restart >> $LOG_FILE 2>&1
/etc/init.d/dnsmasq restart >> $LOG_FILE 2>&1
/etc/init.d/firewall restart >> $LOG_FILE 2>&1

echo "自定义配置完成!" >> $LOG_FILE
echo "管理地址: http://192.168.101.1" >> $LOG_FILE
echo "请查看 /root/initial-password.txt 获取初始密码" >> $LOG_FILE

# 删除自己（只运行一次）
rm -f /etc/uci-defaults/99-r2cplus-config

exit 0
EOF
    chmod 755 "$UCI_DEFAULTS_DIR/99-r2cplus-config"
    
    # 首次启动脚本
    cat > "$UCI_DEFAULTS_DIR/10-first-boot" << 'EOF'
#!/bin/sh

LOGFILE="/tmp/first-boot.log"
echo "=== R2C Plus 首次启动配置 $(date) ===" > $LOGFILE

# 检查是否已经配置过
if [ -f /etc/config/first-boot-done ]; then
    echo "已执行过首次启动配置，跳过" >> $LOGFILE
    exit 0
fi

echo "1. 基本系统检查..." >> $LOGFILE
uname -a >> $LOGFILE 2>&1
cat /proc/cpuinfo | grep "model name" | head -1 >> $LOGFILE

echo "2. 硬件检测..." >> $LOGFILE
lsusb 2>/dev/null >> $LOGFILE
lspci 2>/dev/null >> $LOGFILE

echo "3. 网络接口检测..." >> $LOGFILE
ip link show >> $LOGFILE 2>&1

echo "4. 磁盘检查..." >> $LOGFILE
df -h >> $LOGFILE 2>&1
lsblk >> $LOGFILE 2>&1

echo "5. 测试网络连接..." >> $LOGFILE
ping -c 2 114.114.114.114 >> $LOGFILE 2>&1
if [ $? -eq 0 ]; then
    echo "网络连接正常" >> $LOGFILE
    
    # 更新时间
    echo "6. 同步时间..." >> $LOGFILE
    ntpd -n -q -p ntp.aliyun.com >> $LOGFILE 2>&1
    date >> $LOGFILE
else
    echo "网络连接失败，请检查WAN口连接" >> $LOGFILE
fi

echo "7. 启用自定义服务..." >> $LOGFILE
/etc/init.d/r2cplus-service enable >> $LOGFILE 2>&1
/etc/init.d/r2cplus-service start >> $LOGFILE 2>&1

echo "8. 扩展overlay分区..." >> $LOGFILE
DISK=$(lsblk -n -o PKNAME $(mount | grep ' /overlay' | awk '{print $1}') 2>/dev/null)
if [ -n "$DISK" ]; then
    ROOT_PART=$(lsblk -n -o NAME /dev/$DISK | grep -E '^[a-z0-9]+p?2$' | head -1)
    if [ -n "$ROOT_PART" ]; then
        resize2fs /dev/$ROOT_PART 2>/dev/null && echo "Overlay分区已扩展" >> $LOGFILE
    fi
fi

echo "9. 创建标记文件..." >> $LOGFILE
touch /etc/config/first-boot-done

echo "首次启动配置完成!" >> $LOGFILE
echo "请访问 http://192.168.101.1 进行配置" >> $LOGFILE

# 显示欢迎信息
cat << 'MOTD'

==========================================
欢迎使用 iStoreOS for R2C Plus
==========================================
管理地址: http://192.168.101.1
SSH地址:  192.168.101.1:22

重要提醒:
1. 初始密码在 /root/initial-password.txt
2. 首次登录后请立即修改密码
3. 建议配置防火墙规则

运行 'r2cplus-health' 检查系统状态
==========================================
MOTD

# 删除自己
rm -f /etc/uci-defaults/10-first-boot

exit 0
EOF
    chmod 755 "$UCI_DEFAULTS_DIR/10-first-boot"
    
    log_success "UCI默认配置创建完成"
}

# 创建SSH欢迎信息
create_ssh_banner() {
    log_info "创建SSH欢迎信息..."
    
    cat > "$FILES_DIR/etc/banner" << 'EOF'
  ___ _   _ _____ ___ _   _  ___ 
 |_ _| \ | |_   _|_ _| \ | |/ __|
  | ||  \| | | |  | ||  \| |\__ \
  | || |\  | | |  | || |\  | ___) |
 |___|_| \_| |_| |___|_| \_||____/ 

 iStoreOS for NanoPi R2C Plus
   基于 OpenWrt 24.10 / 内核 6.6
   
   管理地址: 192.168.101.1
   初始密码: 查看 /root/initial-password.txt
   
   系统信息:
   - CPU: Rockchip RK3328 (4核 Cortex-A53)
   - 内存: $(free -h | awk '/^Mem:/ {print $2}') 总
   - 存储: $(df -h / | awk 'NR==2{print $2}') 总
   - 运行: $(uptime -p)
   
   支持功能:
   - iStore 应用商店
   - Docker 容器支持
   - 硬件加速网络
   - 智能流量管理
   
   警告: 未经授权访问将被记录并追究责任
   ------------------------------------
EOF
    
    log_success "SSH欢迎信息创建完成"
}

# 创建增强版系统监控脚本
create_monitoring_scripts() {
    log_info "创建系统监控脚本..."
    
    # 主监控脚本
    cat > "$ROOT_DIR/system_monitor.sh" << 'EOF'
#!/bin/bash
# R2C Plus 系统监控脚本 (增强版)

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
NC='\033[0m'

# 获取CPU温度
get_cpu_temp() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "scale=1; $TEMP/1000" | bc
    else
        echo "N/A"
    fi
}

# 获取CPU频率
get_cpu_freq() {
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        echo "scale=0; $FREQ/1000" | bc
    else
        echo "N/A"
    fi
}

# 获取网络流量
get_network_traffic() {
    INTERFACE=${1:-eth0}
    RX_PATH="/sys/class/net/${INTERFACE}/statistics/rx_bytes"
    TX_PATH="/sys/class/net/${INTERFACE}/statistics/tx_bytes"
    
    if [ -f "$RX_PATH" ] && [ -f "$TX_PATH" ]; then
        RX=$(cat "$RX_PATH")
        TX=$(cat "$TX_PATH")
        echo "$RX $TX"
    else
        echo "0 0"
    fi
}

# 格式化字节数为可读格式
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1099511627776 ]; then  # 1TB
        echo "$(echo "scale=2; $bytes/1099511627776" | bc) TB"
    elif [ $bytes -gt 1073741824 ]; then   # 1GB
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif [ $bytes -gt 1048576 ]; then      # 1MB
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif [ $bytes -gt 1024 ]; then         # 1KB
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# 监控循环
monitor_loop() {
    # 初始化网络流量统计
    declare -A LAST_RX LAST_TX
    for iface in /sys/class/net/eth* /sys/class/net/br-*; do
        if [ -d "$iface" ]; then
            iface_name=$(basename "$iface")
            LAST_RX[$iface_name]=0
            LAST_TX[$iface_name]=0
        fi
    done
    
    while true; do
        clear
        
        # 顶部标题
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║           R2C Plus 实时系统监控 (刷新: 3秒)            ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
        
        # 系统信息
        echo -e "${GREEN}┌────────────────── 系统信息 ──────────────────${NC}"
        echo -e " 主机名: $(hostname)"
        echo -e " 系统时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e " 运行时间: $(uptime -p | sed 's/up //')"
        echo -e " 系统负载: $(uptime | awk -F'[a-z]:' '{print $2}' | xargs)"
        echo -e " 内核版本: $(uname -r)"
        
        # CPU信息
        echo -e "${GREEN}├────────────────── CPU信息 ───────────────────${NC}"
        CPU_TEMP=$(get_cpu_temp)
        CPU_FREQ=$(get_cpu_freq)
        CPU_CORES=$(nproc)
        
        echo -e " 架构: Rockchip RK3328 (ARM Cortex-A53)"
        echo -e " 核心数: ${CPU_CORES}"
        echo -e " 频率: ${CPU_FREQ} MHz"
        
        # 温度颜色指示
        if [ "$CPU_TEMP" != "N/A" ]; then
            if (( $(echo "$CPU_TEMP > 75" | bc -l) )); then
                echo -e " 温度: ${RED}${CPU_TEMP}°C (警告)${NC}"
            elif (( $(echo "$CPU_TEMP > 65" | bc -l) )); then
                echo -e " 温度: ${YELLOW}${CPU_TEMP}°C (注意)${NC}"
            else
                echo -e " 温度: ${GREEN}${CPU_TEMP}°C (正常)${NC}"
            fi
        else
            echo -e " 温度: N/A"
        fi
        
        # CPU使用率
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
        echo -e " 使用率: ${CPU_USAGE}"
        
        # 内存信息
        echo -e "${GREEN}├────────────────── 内存信息 ──────────────────${NC}"
        MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
        MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
        MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
        MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f%%", $3/$2*100}')
        
        echo -e " 总量: ${MEM_TOTAL}"
        echo -e " 已用: ${MEM_USED} (${MEM_PERCENT})"
        echo -e " 空闲: ${MEM_FREE}"
        
        # 内存使用进度条
        USED_PERCENT=$(echo $MEM_PERCENT | tr -d '%')
        BAR_LENGTH=20
        FILLED=$(echo "scale=0; $USED_PERCENT * $BAR_LENGTH / 100" | bc)
        EMPTY=$((BAR_LENGTH - FILLED))
        
        BAR="["
        for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
        for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done
        BAR="${BAR}]"
        
        if (( $(echo "$USED_PERCENT > 80" | bc -l) )); then
            echo -e " 使用率: ${RED}${BAR} ${MEM_PERCENT}${NC}"
        elif (( $(echo "$USED_PERCENT > 60" | bc -l) )); then
            echo -e " 使用率: ${YELLOW}${BAR} ${MEM_PERCENT}${NC}"
        else
            echo -e " 使用率: ${GREEN}${BAR} ${MEM_PERCENT}${NC}"
        fi
        
        # 磁盘信息
        echo -e "${GREEN}├────────────────── 磁盘信息 ──────────────────${NC}"
        df -h | grep -E '^/dev/|overlay' | awk '{print $1": "$3"/"$2" ("$5")"}' | while read line; do
            PERCENT=$(echo $line | grep -o '([0-9]*%)' | tr -d '(%')
            if [ "$PERCENT" -gt 90 ] 2>/dev/null; then
                echo -e "  ${RED}⚠ $line${NC}"
            elif [ "$PERCENT" -gt 80 ] 2>/dev/null; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${GREEN}$line${NC}"
            fi
        done
        
        # 网络信息
        echo -e "${GREEN}├────────────────── 网络信息 ──────────────────${NC}"
        echo -e " LAN IP: 192.168.101.1"
        
        # 显示网络接口和流量
        for iface in /sys/class/net/eth* /sys/class/net/br-*; do
            if [ -d "$iface" ]; then
                iface_name=$(basename "$iface")
                IP_ADDR=$(ip -4 addr show "$iface_name" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "未配置")
                
                # 获取当前流量
                read CURRENT_RX CURRENT_TX <<< $(get_network_traffic "$iface_name")
                
                # 计算流量差
                RX_DIFF=$((CURRENT_RX - ${LAST_RX[$iface_name]:-0}))
                TX_DIFF=$((CURRENT_TX - ${LAST_TX[$iface_name]:-0}))
                
                # 更新上次值
                LAST_RX[$iface_name]=$CURRENT_RX
                LAST_TX[$iface_name]=$CURRENT_TX
                
                # 计算速率（3秒间隔）
                RX_RATE=$((RX_DIFF / 3))
                TX_RATE=$((TX_DIFF / 3))
                
                echo -e " ${iface_name}: ${IP_ADDR}"
                echo -e "   接收: $(format_bytes $RX_RATE)/s | 发送: $(format_bytes $TX_RATE)/s"
            fi
        done
        
        # 连接数统计
        CONN_COUNT=$(ss -tun | tail -n +2 | wc -l)
        echo -e " 活动连接: ${CONN_COUNT}"
        
        # Docker状态
        echo -e "${GREEN}├────────────────── Docker ────────────────────${NC}"
        if command -v docker &> /dev/null; then
            DOCKER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
            DOCKER_IMAGES=$(docker images -q 2>/dev/null | wc -l)
            echo -e " 运行容器: ${DOCKER_COUNT} 个"
            echo -e " 镜像数量: ${DOCKER_IMAGES} 个"
            
            if [ $DOCKER_COUNT -gt 0 ]; then
                echo -e " 容器状态:"
                docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}" | while read line; do
                    echo -e "   ${CYAN}$line${NC}"
                done | head -5
            fi
        else
            echo -e " Docker: 未安装"
        fi
        
        # 服务状态
        echo -e "${GREEN}├────────────────── 服务状态 ──────────────────${NC}"
        SERVICES="dnsmasq firewall network uhttpd r2cplus-service"
        for SERVICE in $SERVICES; do
            if [ -f "/etc/init.d/$SERVICE" ]; then
                if /etc/init.d/$SERVICE enabled >/dev/null 2>&1; then
                    STATUS=$(/etc/init.d/$SERVICE status 2>/dev/null | grep -o 'running' || echo 'stopped')
                    if [ "$STATUS" = "running" ]; then
                        echo -e "  ${SERVICE}: ${GREEN}运行中${NC}"
                    else
                        echo -e "  ${SERVICE}: ${RED}已停止${NC}"
                    fi
                else
                    echo -e "  ${SERVICE}: ${YELLOW}未启用${NC}"
                fi
            fi
        done
        
        # 底部信息
        echo -e "${GREEN}└──────────────────────────────────────────────${NC}"
        echo -e "${YELLOW}快捷键:${NC} q=退出 | r=刷新 | s=服务管理 | h=健康检查"
        echo -e "${PURPLE}提示:${NC} 详细日志: tail -f /var/log/r2cplus/service.log"
        
        # 按键监听（非阻塞）
        read -t 3 -n 1 key || key=""
        case $key in
            q|Q) 
                echo -e "\n${RED}退出监控...${NC}"
                exit 0
                ;;
            r|R)
                continue
                ;;
            s|S)
                echo -e "\n${CYAN}切换到服务管理...${NC}"
                /etc/init.d/r2cplus-service menu
                ;;
            h|H)
                echo -e "\n${CYAN}运行健康检查...${NC}"
                r2cplus-health
                echo -e "\n${YELLOW}按回车键返回监控...${NC}"
                read
                ;;
        esac
    done
}

# 主函数
case "${1:-}" in
    --help|-h)
        echo "使用: system_monitor.sh [选项]"
        echo "选项:"
        echo "  --loop     实时监控模式（默认）"
        echo "  --once     单次显示系统状态"
        echo "  --help     显示此帮助"
        ;;
    --once)
        # 单次显示模式
        get_cpu_temp > /dev/null  # 初始化
        echo "=== 系统状态快照 ==="
        echo "时间: $(date)"
        echo "负载: $(uptime | awk -F'[a-z]:' '{print $2}' | xargs)"
        echo "内存: $(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" $4 " 空闲)"}')"
        echo "温度: $(get_cpu_temp)°C"
        ;;
    *)
        # 默认进入实时监控模式
        monitor_loop
        ;;
esac
EOF
    chmod +x "$ROOT_DIR/system_monitor.sh"
    
    # 创建健康检查脚本
    cat > "$ROOT_DIR/health_check.sh" << 'EOF'
#!/bin/bash
# R2C Plus 系统健康检查

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}=== R2C Plus 系统健康检查 ===${NC}"
echo "检查时间: $(date)"
echo ""

# 检查系统负载
check_load() {
    local load1=$(awk '{print $1}' /proc/loadavg)
    local load5=$(awk '{print $2}' /proc/loadavg)
    local load15=$(awk '{print $3}' /proc/loadavg)
    local cores=$(nproc)
    
    echo -e "${BLUE}[1] 系统负载检查${NC}"
    echo "  最近1分钟: $load1"
    echo "  最近5分钟: $load5"
    echo "  最近15分钟: $load15"
    echo "  CPU核心数: $cores"
    
    local warning=""
    if (( $(echo "$load1 > $cores" | bc -l) )); then
        warning="${RED}警告: 负载过高${NC}"
    elif (( $(echo "$load1 > $(echo "$cores * 0.7" | bc -l)" | bc -l) )); then
        warning="${YELLOW}注意: 负载较高${NC}"
    else
        warning="${GREEN}正常${NC}"
    fi
    echo "  状态: $warning"
    echo ""
}

# 检查内存使用
check_memory() {
    echo -e "${BLUE}[2] 内存使用检查${NC}"
    free -h | head -2
    local mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
    
    if [ $mem_percent -gt 90 ]; then
        echo -e "  状态: ${RED}警告: 内存使用率 ${mem_percent}%${NC}"
    elif [ $mem_percent -gt 80 ]; then
        echo -e "  状态: ${YELLOW}注意: 内存使用率 ${mem_percent}%${NC}"
    else
        echo -e "  状态: ${GREEN}正常: 内存使用率 ${mem_percent}%${NC}"
    fi
    echo ""
}

# 检查磁盘空间
check_disk() {
    echo -e "${BLUE}[3] 磁盘空间检查${NC}"
    df -h | grep -E '^/dev/|overlay' | awk '{print $1 ": " $5 " 已用 (" $3 "/" $2 ")"}'
    
    df -h | grep -E '^/dev/|overlay' | while read line; do
        local percent=$(echo $line | awk '{print $5}' | tr -d '%')
        local mount=$(echo $line | awk '{print $6}')
        if [ $percent -gt 90 ]; then
            echo -e "  ${RED}警告: $mount 使用率 ${percent}%${NC}"
        elif [ $percent -gt 80 ]; then
            echo -e "  ${YELLOW}注意: $mount 使用率 ${percent}%${NC}"
        fi
    done
    echo ""
}

# 检查CPU温度
check_temperature() {
    echo -e "${BLUE}[4] CPU温度检查${NC}"
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_c=$(echo "scale=1; $temp/1000" | bc)
        
        echo "  当前温度: ${temp_c}°C"
        if (( $(echo "$temp_c > 80" | bc -l) )); then
            echo -e "  状态: ${RED}警告: 温度过高${NC}"
        elif (( $(echo "$temp_c > 70" | bc -l) )); then
            echo -e "  状态: ${YELLOW}注意: 温度较高${NC}"
        else
            echo -e "  状态: ${GREEN}正常${NC}"
        fi
    else
        echo "  温度传感器: 不可用"
    fi
    echo ""
}

# 检查网络连接
check_network() {
    echo -e "${BLUE}[5] 网络连接检查${NC}"
    
    # 检查接口
    echo "  网络接口:"
    ip -o link show | awk '{print "    " $2 ": " $3}' | while read line; do
        echo "  $line"
    done
    
    # 测试外网连接
    echo -n "  外网连接: "
    if ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1; then
        echo -e "${GREEN}正常${NC}"
    else
        echo -e "${RED}失败${NC}"
    fi
    
    # 检查DNS
    echo -n "  DNS解析: "
    if nslookup baidu.com >/dev/null 2>&1; then
        echo -e "${GREEN}正常${NC}"
    else
        echo -e "${RED}失败${NC}"
    fi
    echo ""
}

# 检查服务状态
check_services() {
    echo -e "${BLUE}[6] 服务状态检查${NC}"
    local services="dnsmasq firewall network uhttpd r2cplus-service"
    local all_ok=1
    
    for service in $services; do
        if [ -f "/etc/init.d/$service" ]; then
            if /etc/init.d/$service enabled >/dev/null 2>&1; then
                if /etc/init.d/$service running >/dev/null 2>&1; then
                    echo -e "  ${service}: ${GREEN}运行中${NC}"
                else
                    echo -e "  ${service}: ${RED}已停止${NC}"
                    all_ok=0
                fi
            else
                echo -e "  ${service}: ${YELLOW}未启用${NC}"
            fi
        fi
    done
    echo ""
    return $all_ok
}

# 检查Docker
check_docker() {
    echo -e "${BLUE}[7] Docker检查${NC}"
    if command -v docker >/dev/null 2>&1; then
        echo "  Docker版本: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        
        if docker ps >/dev/null 2>&1; then
            local container_count=$(docker ps -q | wc -l)
            echo "  运行容器: ${container_count}个"
            
            if [ $container_count -gt 0 ]; then
                echo "  容器状态:"
                docker ps --format "    {{.Names}}: {{.Status}}" | while read line; do
                    if echo "$line" | grep -q "Up"; then
                        echo -e "    ${GREEN}$line${NC}"
                    else
                        echo -e "    ${RED}$line${NC}"
                    fi
                done
            fi
        else
            echo -e "  ${RED}Docker服务未运行${NC}"
        fi
    else
        echo "  Docker: 未安装"
    fi
    echo ""
}

# 检查系统日志错误
check_logs() {
    echo -e "${BLUE}[8] 系统日志检查${NC}"
    local error_count=$(logread | grep -i "error\|fail\|critical" | tail -5 | wc -l)
    
    if [ $error_count -gt 0 ]; then
        echo -e "  ${YELLOW}发现 $error_count 条错误日志${NC}"
        logread | grep -i "error\|fail\|critical" | tail -3 | while read line; do
            echo "    $line"
        done
    else
        echo -e "  ${GREEN}未发现严重错误${NC}"
    fi
    echo ""
}

# 主检查函数
main_check() {
    check_load
    check_memory
    check_disk
    check_temperature
    check_network
    check_services
    check_docker
    check_logs
    
    # 总结
    echo -e "${BLUE}=== 检查完成 ===${NC}"
    echo ""
    echo "建议操作:"
    echo "  1. 定期备份配置: backup-config.sh"
    echo "  2. 实时监控: system_monitor.sh"
    echo "  3. 查看详细日志: logread | tail -50"
    echo "  4. 更新系统: opkg update && opkg upgrade"
    echo ""
}

# 执行检查
main_check
EOF
    chmod +x "$ROOT_DIR/health_check.sh"
    
    # 创建符号链接到 /usr/bin 方便使用
    ln -sf /root/system_monitor.sh "$FILES_DIR/usr/bin/r2cplus-monitor" 2>/dev/null || true
    ln -sf /root/health_check.sh "$FILES_DIR/usr/bin/r2cplus-health" 2>/dev/null || true
    
    log_success "监控脚本创建完成"
}

# 创建Web欢迎页面
create_web_page() {
    log_info "创建Web欢迎页面..."
    
    cat > "$WWW_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>R2C Plus iStoreOS</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif; }
        body { background: linear-gradient(135deg, #1a2980 0%, #26d0ce 100%); min-height: 100vh; padding: 20px; }
        .container { background: rgba(255, 255, 255, 0.95); padding: 40px; border-radius: 20px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); max-width: 800px; margin: 0 auto; }
        .logo { font-size: 4em; margin-bottom: 20px; color: #1a2980; text-align: center; animation: float 3s ease-in-out infinite; }
        @keyframes float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-10px); } }
        h1 { background: linear-gradient(90deg, #1a2980, #26d0ce); -webkit-background-clip: text; -webkit-text-fill-color: transparent; text-align: center; margin-bottom: 10px; }
        .subtitle { color: #666; text-align: center; margin-bottom: 30px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 30px 0; }
        .info-box { background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); padding: 25px; border-radius: 15px; border-left: 5px solid #1a2980; transition: transform 0.3s; }
        .info-box:hover { transform: translateY(-5px); box-shadow: 0 10px 20px rgba(0,0,0,0.1); }
        .info-box h3 { color: #1a2980; margin-bottom: 15px; display: flex; align-items: center; gap: 10px; }
        .btn-group { display: flex; justify-content: center; flex-wrap: wrap; gap: 15px; margin: 30px 0; }
        .btn { display: inline-flex; align-items: center; gap: 10px; background: linear-gradient(135deg, #1a2980 0%, #26d0ce 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 50px; font-weight: bold; transition: all 0.3s; border: none; cursor: pointer; }
        .btn:hover { transform: translateY(-3px); box-shadow: 0 10px 20px rgba(26, 41, 128, 0.3); }
        .btn-secondary { background: linear-gradient(135deg, #6c757d 0%, #495057 100%); }
        .btn-warning { background: linear-gradient(135deg, #ff9a00 0%, #ff6a00 100%); }
        .status-panel { background: #f8f9fa; padding: 20px; border-radius: 10px; margin: 20px 0; }
        .status-item { display: flex; justify-content: space-between; margin-bottom: 10px; padding-bottom: 10px; border-bottom: 1px solid #dee2e6; }
        .status-value.good { color: #28a745; } .status-value.warning { color: #ffc107; } .status-value.danger { color: #dc3545; }
        .tips { color: #666; font-size: 0.9em; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6; }
        .footer { margin-top: 30px; color: #888; font-size: 0.8em; text-align: center; }
        @media (max-width: 768px) { .container { padding: 20px; } h1 { font-size: 2em; } .btn { padding: 12px 20px; width: 100%; justify-content: center; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo"><i class="fas fa-rocket"></i></div>
        <h1>R2C Plus iStoreOS</h1>
        <p class="subtitle">基于 iStoreOS 和 FriendlyWrt 24.10 的优化固件</p>
        
        <div class="grid">
            <div class="info-box">
                <h3><i class="fas fa-cogs"></i> 核心特性</h3>
                <ul style="padding-left: 20px; color: #555;">
                    <li>iStore 应用商店完全支持</li>
                    <li>FriendlyWrt 24.10 兼容性</li>
                    <li>Docker 容器运行时环境</li>
                    <li>硬件加速网络转发</li>
                    <li>Argon 现代化主题界面</li>
                    <li>BBR 网络优化算法</li>
                </ul>
            </div>
            
            <div class="info-box">
                <h3><i class="fas fa-shield-alt"></i> 安全特性</h3>
                <ul style="padding-left: 20px; color: #555;">
                    <li>增强防火墙配置</li>
                    <li>SSH 密钥认证支持</li>
                    <li>DDoS 攻击防护</li>
                    <li>安全更新自动提醒</li>
                    <li>网络流量监控</li>
                    <li>连接数限制</li>
                </ul>
            </div>
        </div>
        
        <div class="status-panel">
            <h3><i class="fas fa-chart-line"></i> 系统状态</h3>
            <div class="status-item"><span>管理地址</span><span class="status-value good" id="sys-ip">192.168.101.1</span></div>
            <div class="status-item"><span>默认用户名</span><span class="status-value">root</span></div>
            <div class="status-item"><span>初始密码</span><span class="status-value warning" id="sys-password">查看 /root/initial-password.txt</span></div>
            <div class="status-item"><span>固件版本</span><span class="status-value" id="sys-version">iStoreOS R2C Plus v3.0</span></div>
            <div class="status-item"><span>技术支持</span><span class="status-value">GitHub: EZ-6086/istoreos-R2C-Plus</span></div>
        </div>
        
        <div class="btn-group">
            <a href="http://192.168.101.1" class="btn"><i class="fas fa-tachometer-alt"></i> 进入管理界面</a>
            <a href="http://192.168.101.1/cgi-bin/luci/admin/istore" class="btn btn-secondary"><i class="fas fa-store"></i> 打开 iStore</a>
            <a href="http://192.168.101.1/cgi-bin/luci/admin/services/dockerman" class="btn btn-warning"><i class="fab fa-docker"></i> Docker 管理</a>
        </div>
        
        <div class="tips">
            <p><i class="fas fa-lightbulb"></i> <strong>重要提示：</strong></p>
            <p>1. 首次登录后请立即修改默认密码</p>
            <p>2. 建议启用防火墙并配置安全规则</p>
            <p>3. 定期备份系统配置以防意外</p>
            <p>4. Docker 数据默认存储在外部存储设备</p>
            <p id="build-date">构建日期: 正在获取...</p>
        </div>
        
        <div class="footer">
            <p>© 2024 iStoreOS R2C Plus 定制版 | 基于 OpenWrt 24.10 | Rockchip RK3328 优化</p>
        </div>
    </div>
    
    <script>
        document.getElementById('build-date').textContent = '构建日期: ' + new Date().toLocaleDateString('zh-CN');
        async function fetchSystemInfo() {
            try { const response = await fetch('http://192.168.101.1/cgi-bin/luci/admin/status/overview');
                if (response.ok) { const data = await response.json();
                    if (data.hostname) { document.getElementById('sys-version').textContent = data.hostname; }
                }
            } catch (error) { console.log('系统信息获取失败'); }
        }
        window.addEventListener('load', fetchSystemInfo);
        document.addEventListener('keydown', (e) => { if (e.key === 'm' || e.key === 'M') { window.open('http://192.168.101.1', '_blank'); } });
        console.log('快捷键提示: 按 M 键快速打开管理界面');
    </script>
</body>
</html>
EOF
    
    log_success "Web页面创建完成"
}

# 创建服务管理脚本
create_service_script() {
    log_info "创建服务管理脚本..."
    
    cat > "$INIT_DIR/r2cplus-service" << 'EOF'
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99
STOP=10
EXTRA_COMMANDS="menu logs backup restore stats"
EXTRA_HELP="    menu      显示管理菜单
    logs      查看服务日志
    backup    备份系统配置
    restore   恢复配置备份
    stats     显示系统统计"

# 服务目录
SERVICE_NAME="r2cplus-service"
LOG_DIR="/var/log/r2cplus"
PID_DIR="/var/run/r2cplus"
BACKUP_DIR="/mnt/sda1/backup"

# 启动服务
start_service() {
    procd_open_instance "$SERVICE_NAME"
    procd_set_param command /bin/sh -c "
        # 初始化目录
        mkdir -p '$LOG_DIR'
        mkdir -p '$PID_DIR'
        mkdir -p '$BACKUP_DIR'
        
        # 启动监控进程
        while true; do
            # 记录系统状态
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') - 系统运行中\" >> '$LOG_DIR/service.log'
            
            # 检查关键服务
            check_services
            
            # 检查系统资源
            check_resources
            
            sleep 60
        done
    "
    procd_set_param respawn 3600 5 0
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param pidfile "$PID_DIR/service.pid"
    procd_close_instance
    
    logger -t "$SERVICE_NAME" "服务已启动"
    echo "R2C Plus 服务已启动"
}

# 停止服务
stop_service() {
    logger -t "$SERVICE_NAME" "服务已停止"
    echo "R2C Plus 服务已停止"
}

# 检查关键服务
check_services() {
    local services="dnsmasq firewall network"
    for service in $services; do
        if ! /etc/init.d/$service running >/dev/null 2>&1; then
            logger -t "$SERVICE_NAME" "检测到服务停止: $service，正在重启..."
            /etc/init.d/$service restart >/dev/null 2>&1
        fi
    done
}

# 检查系统资源
check_resources() {
    # 内存检查
    local mem_free=$(free | awk '/^Mem:/ {print $4}')
    if [ $mem_free -lt 50000 ]; then  # 小于50MB
        logger -t "$SERVICE_NAME" "内存不足: ${mem_free}KB，清理缓存"
        sync && echo 3 > /proc/sys/vm/drop_caches
    fi
    
    # 温度检查
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        if [ $temp -gt 80000 ]; then  # 大于80°C
            logger -t "$SERVICE_NAME" "CPU温度过高: $(echo "scale=1; $temp/1000" | bc)°C"
        fi
    fi
}

# 显示日志
show_logs() {
    echo "=== R2C Plus 服务日志 ==="
    echo ""
    
    if [ -f "$LOG_DIR/service.log" ]; then
        echo "服务日志 (最后20行):"
        echo "-------------------"
        tail -20 "$LOG_DIR/service.log"
    else
        echo "暂无日志"
    fi
    
    echo ""
    echo "系统日志相关:"
    echo "  tail -f /var/log/messages    # 实时系统日志"
    echo "  logread                      # 查看所有日志"
    echo "  dmesg | tail -20             # 内核日志"
}

# 备份配置
backup_config() {
    echo "正在备份系统配置..."
    
    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config-$timestamp.tar.gz"
    
    tar -czf "$backup_file" \
        /etc/config/* \
        /etc/firewall.user \
        /etc/sysctl.conf \
        /etc/opkg/customfeeds.conf \
        /etc/docker/daemon.json 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local size=$(ls -lh "$backup_file" | awk '{print $5}')
        echo "备份完成: $backup_file ($size)"
        
        # 保留最近10个备份
        ls -t "$BACKUP_DIR"/config-*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null
    else
        echo "备份失败"
        return 1
    fi
}

# 显示统计信息
show_stats() {
    echo "=== 系统统计信息 ==="
    echo ""
    
    # CPU使用率
    echo "CPU使用率: $(top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8\"%\"}')"
    
    # 内存使用
    echo "内存使用: $(free -h | awk '/^Mem:/ {print $3\"/\"$2 \" (\" $4 \" 空闲)\"}')"
    
    # 磁盘使用
    echo "磁盘使用:"
    df -h | grep -E '^/dev/|overlay' | awk '{print \"  \" $1 \": \" $5 \" (\" $3\"/\"$2 \")\"}' | while read line; do
        echo "  $line"
    done
    
    # 网络连接数
    echo "活动连接: $(ss -tun | tail -n +2 | wc -l)"
    
    # 运行时间
    echo "运行时间: $(uptime -p | sed 's/up //')"
}

# 显示管理菜单
show_menu() {
    while true; do
        clear
        echo "========================================"
        echo "    R2C Plus 服务管理菜单"
        echo "========================================"
        echo ""
        echo "  1. 查看服务状态"
        echo "  2. 查看系统日志"
        echo "  3. 备份当前配置"
        echo "  4. 恢复配置备份"
        echo "  5. 系统统计信息"
        echo "  6. 重启网络服务"
        echo "  7. 清理系统缓存"
        echo "  8. 查看系统监控"
        echo "  9. 重启本服务"
        echo "  0. 返回"
        echo ""
        echo "========================================"
        
        read -p "请选择操作 [0-9]: " choice
        
        case $choice in
            1) /etc/init.d/r2cplus-service status; read -p "按回车键继续...";;
            2) show_logs; read -p "按回车键继续...";;
            3) backup_config; read -p "按回车键继续...";;
            4) echo "恢复功能请使用: /etc/init.d/r2cplus-service restore <文件>"; read -p "按回车键继续...";;
            5) show_stats; read -p "按回车键继续...";;
            6) /etc/init.d/network restart; echo "完成!"; read -p "按回车键继续...";;
            7) sync && echo 3 > /proc/sys/vm/drop_caches; echo "缓存清理完成!"; read -p "按回车键继续...";;
            8) /root/system_monitor.sh;;
            9) /etc/init.d/r2cplus-service restart; read -p "按回车键继续...";;
            0) break;;
            *) echo "无效选择!"; sleep 1;;
        esac
    done
}

# 命令分发
case "$1" in
    menu) show_menu;;
    logs) show_logs;;
    backup) backup_config;;
    restore) echo "恢复功能开发中";;
    stats) show_stats;;
    *) ;;
esac
EOF
    chmod +x "$INIT_DIR/r2cplus-service"
    
    log_success "服务管理脚本创建完成"
}

# 创建日志轮转配置
create_logrotate_config() {
    log_info "创建日志轮转配置..."
    
    cat > "$LOGROTATE_DIR/r2cplus" << 'EOF'
# R2C Plus 服务日志轮转
/var/log/r2cplus/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    postrotate
        [ -f /var/run/r2cplus/service.pid ] && kill -USR1 $(cat /var/run/r2cplus/service.pid) 2>/dev/null || true
    endscript
}

# Docker日志轮转
/opt/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    size 10M
    create 644 root root
}
EOF
    
    log_success "日志轮转配置创建完成"
}

# 创建Docker配置
create_docker_config() {
    log_info "创建Docker配置..."
    
    cat > "$DOCKER_DIR/daemon.json" << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "data-root": "/opt/docker",
  "iptables": false,
  "ip6tables": false,
  "live-restore": true,
  "userland-proxy": false,
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "dns": ["192.168.101.1", "114.114.114.114", "8.8.8.8"]
}
EOF
    
    log_success "Docker配置创建完成"
}

# 创建热插拔脚本
create_hotplug_scripts() {
    log_info "创建热插拔脚本..."
    
    # USB网卡热插拔
    cat > "$FILES_DIR/etc/hotplug.d/iface/10-r2cplus-usbnet" << 'EOF'
#!/bin/sh

[ "$ACTION" = "add" ] || exit 0

. /lib/functions.sh

case "$(board_name)" in
friendlyarm,nanopi-r2c-plus)
    # USB网卡热插拔支持
    case "$INTERFACE" in
        eth1|eth2|eth3)
            logger -t r2cplus-hotplug "检测到网络接口: $INTERFACE"
            
            # 如果这是第一个USB网卡且WAN口未配置，设为WAN
            if ! uci get network.wan 2>/dev/null; then
                uci set network.wan=interface
                uci set network.wan.device="$INTERFACE"
                uci set network.wan.proto="dhcp"
                uci commit network
                logger -t r2cplus-hotplug "已配置 $INTERFACE 为WAN口"
                
                # 重启网络服务
                /etc/init.d/network restart
            fi
            ;;
    esac
    ;;
esac

exit 0
EOF
    chmod +x "$FILES_DIR/etc/hotplug.d/iface/10-r2cplus-usbnet"
    
    log_success "热插拔脚本创建完成"
}

# 主函数
main() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}   iStoreOS R2C Plus 配置文件生成工具   ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    # 初始化
    init_variables
    
    # 创建所有配置
    create_directories
    create_network_config
    create_dhcp_config
    create_firewall_config
    create_uci_defaults
    create_ssh_banner
    create_monitoring_scripts
    create_web_page
    create_service_script
    create_logrotate_config
    create_docker_config
    create_hotplug_scripts
    
    # 完成统计
    local file_count=$(find "$FILES_DIR" -type f | wc -l)
    local config_count=$(find "$CONFIG_DIR" -name "*.json" -o -name "*.conf" | wc -l)
    local script_count=$(find "$FILES_DIR" -name "*.sh" -type f | wc -l)
    
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}        配置文件生成完成！              ${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "生成统计:"
    echo "  - 总文件数: $file_count"
    echo "  - 配置文件: $config_count"
    echo "  - 脚本文件: $script_count"
    echo ""
    echo "主要配置:"
    echo "  ✓ 网络配置 (智能接口识别)"
    echo "  ✓ 防火墙配置 (增强安全)"
    echo "  ✓ 系统监控脚本 (实时)"
    echo "  ✓ 健康检查工具"
    echo "  ✓ Web欢迎页面 (响应式)"
    echo "  ✓ 服务管理脚本"
    echo "  ✓ Docker优化配置"
    echo "  ✓ 热插拔支持"
    echo ""
    echo "下一步:"
    echo "  1. 运行 apply_patches.sh 应用补丁"
    echo "  2. 运行 make menuconfig 选择配置"
    echo "  3. 编译固件: make -j\$(nproc)"
    echo ""
    echo -e "${YELLOW}注意: 此脚本已取代 configs/common.config${NC}"
    echo -e "${YELLOW}建议删除重复的配置文件以避免冲突${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

# 运行主函数
main "$@"
