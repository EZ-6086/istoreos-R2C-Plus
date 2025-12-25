#!/bin/bash
# ====================================================
# iStoreOS R2C Plus 自定义配置脚本
# 版本: 3.1 - 精简优化版
# 功能: 创建固件预配置文件，优化磁盘使用
# ====================================================

set -e
set -o pipefail

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

# 初始化变量
init_variables() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    OPENWRT_DIR="${PROJECT_ROOT}/istoreos/openwrt"
    
    if [ ! -d "$OPENWRT_DIR" ]; then
        echo "OpenWrt目录不存在: $OPENWRT_DIR"
        exit 1
    fi
    
    FILES_DIR="${OPENWRT_DIR}/files"
    CONFIG_DIR="${FILES_DIR}/etc/config"
    UCI_DEFAULTS_DIR="${FILES_DIR}/etc/uci-defaults"
    ROOT_DIR="${FILES_DIR}/root"
    
    # 创建目录
    mkdir -p "$CONFIG_DIR" "$UCI_DEFAULTS_DIR" "$ROOT_DIR"
}

# 创建最小化网络配置
create_minimal_network_config() {
    log_info "创建网络配置..."
    
    cat > "$CONFIG_DIR/network" << 'EOF'
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

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

config interface 'wan'
	option device 'eth1'
	option proto 'dhcp'
	option peerdns '0'
	list dns '114.114.114.114'
	list dns '8.8.8.8'
EOF
    
    log_success "网络配置创建完成"
}

# 创建最小化DHCP配置
create_minimal_dhcp_config() {
    log_info "创建DHCP配置..."
    
    cat > "$CONFIG_DIR/dhcp" << 'EOF'
config dnsmasq
	option domainneeded '1'
	option boguspriv '1'
	option localise_queries '1'
	option rebind_protection '1'
	option local '/lan/'
	option domain 'lan'
	option authoritative '1'
	option leasefile '/tmp/dhcp.leases'
	option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
	list server '114.114.114.114'
	list server '8.8.8.8'

config dhcp 'lan'
	option interface 'lan'
	option start '100'
	option limit '150'
	option leasetime '12h'
	option dhcpv4 'server'
	list dhcp_option '6,192.168.101.1,114.114.114.114,8.8.8.8'
	list dhcp_option '3,192.168.101.1'

config dhcp 'wan'
	option interface 'wan'
	option ignore '1'
EOF
    
    log_success "DHCP配置创建完成"
}

# 创建最小化防火墙配置
create_minimal_firewall_config() {
    log_info "创建防火墙配置..."
    
    cat > "$CONFIG_DIR/firewall" << 'EOF'
config defaults
	option syn_flood '1'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'

config zone
	option name 'lan'
	list network 'lan'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'ACCEPT'
	option masq '1'

config zone
	option name 'wan'
	list network 'wan'
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option masq '1'

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

config include
	option path '/etc/firewall.user'
EOF

    # 创建基本防火墙规则
    cat > "$FILES_DIR/etc/firewall.user" << 'EOF'
#!/bin/sh
# 基本防火墙规则

# 阻止外部访问管理界面
iptables -A input_wan -p tcp --dport 80 -j DROP
iptables -A input_wan -p tcp --dport 443 -j DROP
iptables -A input_wan -p tcp --dport 22 -j DROP

# 允许本地回环
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立的连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
EOF
    
    chmod 755 "$FILES_DIR/etc/firewall.user"
    log_success "防火墙配置创建完成"
}

# 创建基本启动配置
create_basic_uci_defaults() {
    log_info "创建UCI默认配置..."
    
    cat > "$UCI_DEFAULTS_DIR/99-basic-config" << 'EOF'
#!/bin/sh

# 设置时区
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system

# 设置主机名
uci set system.@system[0].hostname='R2CPlus-iStoreOS'
uci commit system

# 设置主题
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set luci.main.lang='zh_cn'
uci commit luci

# 设置root密码（默认admin）
echo -e "admin\nadmin" | passwd root 2>/dev/null

# 添加iStore软件源
mkdir -p /etc/opkg
cat > /etc/opkg/customfeeds.conf << 'EOL'
src/gz istore https://istore.linkease.com/repo/all/store
src/gz friendlywrt https://github.com/friendlyarm/friendlywrt/raw/master-master-24.10/packages/rockchip/armv8
EOL

# 重启服务
/etc/init.d/network restart
/etc/init.d/dnsmasq restart

# 删除自己（只运行一次）
rm -f /etc/uci-defaults/99-basic-config

exit 0
EOF
    chmod 755 "$UCI_DEFAULTS_DIR/99-basic-config"
    
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
   用户名: root
   密码: admin
   
   重要: 首次登录请立即修改密码！
   ------------------------------------
EOF
    
    log_success "SSH欢迎信息创建完成"
}

# 创建基本监控脚本
create_basic_monitor_script() {
    log_info "创建监控脚本..."
    
    cat > "$ROOT_DIR/check-system.sh" << 'EOF'
#!/bin/bash
# 基本系统检查脚本

echo "=== 系统状态检查 ==="
echo "时间: $(date)"
echo "运行时间: $(uptime -p)"
echo "负载: $(uptime | awk -F'[a-z]:' '{print $2}' | xargs)"
echo ""
echo "内存使用:"
free -h
echo ""
echo "磁盘使用:"
df -h / | grep -v Filesystem
echo ""
echo "网络接口:"
ip -o link show | grep -E 'eth|br' | awk '{print $2 ": " $9}'
echo ""
echo "服务状态:"
for service in network firewall dnsmasq; do
    if /etc/init.d/$service enabled >/dev/null 2>&1; then
        status=$(/etc/init.d/$service status 2>/dev/null | grep -o 'running' || echo 'stopped')
        echo "  $service: $status"
    fi
done
EOF
    chmod +x "$ROOT_DIR/check-system.sh"
    
    log_success "监控脚本创建完成"
}

# 创建首次启动脚本
create_first_boot_script() {
    log_info "创建首次启动脚本..."
    
    cat > "$UCI_DEFAULTS_DIR/10-firstboot" << 'EOF'
#!/bin/sh

# 检查是否已经执行过
if [ -f /etc/firstboot_complete ]; then
    exit 0
fi

echo "正在执行首次启动配置..."

# 扩展overlay分区
if [ -d /sys/class/block/mmcblk0 ]; then
    resize2fs /dev/mmcblk0p2 2>/dev/null || true
fi

# 创建必要的目录
mkdir -p /mnt/sda1/istore
mkdir -p /var/log/custom

# 设置完成标记
touch /etc/firstboot_complete

echo "首次启动配置完成！"
echo "请访问 http://192.168.101.1 进行设置"

# 删除自己
rm -f /etc/uci-defaults/10-firstboot

exit 0
EOF
    chmod 755 "$UCI_DEFAULTS_DIR/10-firstboot"
    
    log_success "首次启动脚本创建完成"
}

# 创建构建信息文件
create_build_info() {
    log_info "创建构建信息文件..."
    
    cat > "$FILES_DIR/etc/istoreos-build-info" << 'EOF'
# iStoreOS for NanoPi R2C Plus 构建信息
BUILD_DATE=$(date +%Y-%m-%d)
BUILD_VERSION="3.1-minimal"
BASE_SYSTEM="iStoreOS + FriendlyWrt 24.10"
TARGET_DEVICE="FriendlyARM NanoPi R2C Plus"
KERNEL_VERSION="6.6"
ARCHITECTURE="aarch64"
BUILD_TYPE="minimal"
MAINTAINER="GitHub Actions"
REPOSITORY="https://github.com/EZ-6086/istoreos-R2C-Plus"
EOF
    
    # 更新构建日期
    sed -i "s/BUILD_DATE=\$(date +%Y-%m-%d)/BUILD_DATE=$(date +%Y-%m-%d)/" "$FILES_DIR/etc/istoreos-build-info"
    
    log_success "构建信息文件创建完成"
}

# 主函数
main() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}   iStoreOS R2C Plus 最小化配置生成工具   ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    # 初始化
    init_variables
    
    # 创建最小化配置
    create_minimal_network_config
    create_minimal_dhcp_config
    create_minimal_firewall_config
    create_basic_uci_defaults
    create_ssh_banner
    create_basic_monitor_script
    create_first_boot_script
    create_build_info
    
    # 统计
    local file_count=$(find "$FILES_DIR" -type f | wc -l)
    local dir_count=$(find "$FILES_DIR" -type d | wc -l)
    
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}        最小化配置生成完成！            ${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "生成统计:"
    echo "  - 总文件数: $file_count"
    echo "  - 目录数: $dir_count"
    echo ""
    echo "配置内容:"
    echo "  ✓ 基本网络配置"
    echo "  ✓ 基本DHCP服务"
    echo "  ✓ 基本防火墙"
    echo "  ✓ SSH欢迎信息"
    echo "  ✓ 系统检查脚本"
    echo "  ✓ 首次启动配置"
    echo ""
    echo "注意: 这是最小化配置，更多功能可通过iStore在线安装"
    echo -e "${BLUE}==========================================${NC}"
}

# 运行主函数
main "$@"