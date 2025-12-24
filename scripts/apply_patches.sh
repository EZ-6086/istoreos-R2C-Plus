#!/bin/bash
# ====================================================
# iStoreOS R2C Plus 补丁应用脚本
# 版本: 2.1
# 功能: 自动化应用补丁和配置硬件支持
# 注意: 此脚本应与优化后的补丁文件配合使用
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
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "所需命令 '$1' 未安装"
        exit 1
    fi
}

# 初始化变量
init_variables() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 项目根目录 (假设脚本在 scripts/ 目录下)
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    
    # 目录路径
    OPENWRT_DIR="${PROJECT_ROOT}/istoreos/openwrt"
    PATCHES_DIR="${PROJECT_ROOT}/patches"
    BACKUP_DIR="${PROJECT_ROOT}/backups"
    
    # 备份时间戳
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # 检查目录是否存在
    if [ ! -d "$OPENWRT_DIR" ]; then
        log_error "OpenWrt 目录不存在: $OPENWRT_DIR"
        exit 1
    fi
    
    if [ ! -d "$PATCHES_DIR" ]; then
        log_warning "补丁目录不存在: $PATCHES_DIR"
        mkdir -p "$PATCHES_DIR"
        log_info "已创建补丁目录"
    fi
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
}

# 备份原始文件
backup_files() {
    local backup_name="pre-patch-backup-${TIMESTAMP}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "备份原始文件到: $backup_path"
    
    # 备份关键目录
    mkdir -p "$backup_path"
    
    # 备份设备定义文件
    if [ -f "${OPENWRT_DIR}/target/linux/rockchip/image/armv8.mk" ]; then
        cp "${OPENWRT_DIR}/target/linux/rockchip/image/armv8.mk" "$backup_path/"
    fi
    
    # 备份网络配置
    if [ -d "${OPENWRT_DIR}/target/linux/rockchip/armv8/base-files" ]; then
        cp -r "${OPENWRT_DIR}/target/linux/rockchip/armv8/base-files" "$backup_path/" 2>/dev/null || true
    fi
    
    # 创建备份记录
    cat > "$backup_path/backup-info.txt" << EOF
备份时间: $(date)
备份原因: 应用 R2C Plus 补丁前备份
补丁脚本版本: 2.1
包含文件:
  - target/linux/rockchip/image/armv8.mk
  - target/linux/rockchip/armv8/base-files/etc/board.d/*
  - target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/*
EOF
    
    log_success "备份完成"
}

# 检查补丁文件
check_patches() {
    local patch_count=0
    
    log_info "检查补丁文件..."
    
    if [ ! -d "$PATCHES_DIR" ]; then
        log_error "补丁目录不存在: $PATCHES_DIR"
        return 1
    fi
    
    # 统计补丁文件
    for patch in "$PATCHES_DIR"/*.patch; do
        if [ -f "$patch" ]; then
            patch_count=$((patch_count + 1))
            log_info "找到补丁: $(basename "$patch")"
        fi
    done
    
    if [ $patch_count -eq 0 ]; then
        log_warning "未找到任何补丁文件"
        return 1
    fi
    
    log_success "找到 $patch_count 个补丁文件"
    return 0
}

# 应用补丁文件
apply_patches() {
    local applied_count=0
    local failed_count=0
    local skipped_count=0
    
    log_info "开始应用补丁..."
    
    # 进入 OpenWrt 目录
    cd "$OPENWRT_DIR" || {
        log_error "无法进入目录: $OPENWRT_DIR"
        return 1
    }
    
    # 检查git状态
    if [ -d ".git" ]; then
        git status --short > "${BACKUP_DIR}/git-status-${TIMESTAMP}.txt" 2>/dev/null || true
    fi
    
    # 应用所有补丁
    for patch in "$PATCHES_DIR"/*.patch; do
        if [ ! -f "$patch" ]; then
            continue
        fi
        
        local patch_name=$(basename "$patch")
        log_info "正在应用补丁: $patch_name"
        
        # 检查补丁是否已应用
        if patch -p1 --dry-run < "$patch" &> /dev/null; then
            # 可以应用
            if patch -p1 < "$patch" &> "${BACKUP_DIR}/patch-${patch_name%.*}-${TIMESTAMP}.log"; then
                log_success "补丁应用成功: $patch_name"
                applied_count=$((applied_count + 1))
                
                # 记录应用详情
                echo "=== 补丁 $patch_name 应用详情 ===" >> "${BACKUP_DIR}/patch-summary-${TIMESTAMP}.txt"
                head -n 20 "$patch" >> "${BACKUP_DIR}/patch-summary-${TIMESTAMP}.txt" 2>/dev/null
                echo "" >> "${BACKUP_DIR}/patch-summary-${TIMESTAMP}.txt"
            else
                log_error "补丁应用失败: $patch_name"
                failed_count=$((failed_count + 1))
                
                # 保存错误信息
                patch -p1 < "$patch" 2>&1 | tail -n 20 > "${BACKUP_DIR}/patch-error-${patch_name%.*}-${TIMESTAMP}.log"
            fi
        else
            log_warning "补丁可能已应用或存在冲突: $patch_name"
            skipped_count=$((skipped_count + 1))
        fi
    done
    
    # 输出统计
    echo ""
    log_info "补丁应用统计:"
    log_info "  成功: $applied_count"
    log_info "  失败: $failed_count"
    log_info "  跳过: $skipped_count"
    
    if [ $failed_count -gt 0 ]; then
        log_error "有补丁应用失败，请检查日志"
        return 1
    fi
    
    return 0
}

# 验证补丁应用结果
verify_patches() {
    log_info "验证补丁应用结果..."
    
    local verification_passed=0
    
    # 检查设备定义是否存在
    if grep -q "friendlyarm_nanopi-r2c-plus" target/linux/rockchip/image/armv8.mk 2>/dev/null; then
        log_success "✓ R2C Plus 设备定义已添加"
        verification_passed=$((verification_passed + 1))
    else
        log_error "✗ R2C Plus 设备定义未找到"
    fi
    
    # 检查网络配置
    if [ -f target/linux/rockchip/armv8/base-files/etc/board.d/02_network ]; then
        if grep -q "nanopi-r2c-plus" target/linux/rockchip/armv8/base-files/etc/board.d/02_network 2>/dev/null; then
            log_success "✓ R2C Plus 网络配置已添加"
            verification_passed=$((verification_passed + 1))
        else
            log_warning "⚠ R2C Plus 网络配置未找到"
        fi
    fi
    
    # 检查热插拔配置
    local hotplug_files=$(find target/linux/rockchip/armv8/base-files/etc/hotplug.d -name "*r2c*" -o -name "*rk3328*" 2>/dev/null | wc -l)
    if [ $hotplug_files -gt 0 ]; then
        log_success "✓ 热插拔配置存在"
        verification_passed=$((verification_passed + 1))
    else
        log_warning "⚠ 热插拔配置未找到"
    fi
    
    # 总体验证
    if [ $verification_passed -ge 2 ]; then
        log_success "补丁验证通过"
        return 0
    else
        log_error "补丁验证失败"
        return 1
    fi
}

# 创建备用配置（如果补丁应用失败）
create_fallback_config() {
    log_info "创建备用配置..."
    
    # 只在补丁验证失败时执行
    if verify_patches 2>/dev/null; then
        log_info "补丁验证通过，跳过备用配置"
        return 0
    fi
    
    log_warning "补丁验证失败，创建备用配置"
    
    local base_files_dir="target/linux/rockchip/armv8/base-files"
    mkdir -p "${base_files_dir}/etc/board.d"
    mkdir -p "${base_files_dir}/etc/hotplug.d/net"
    
    # 1. 添加设备定义到 armv8.mk
    if ! grep -q "friendlyarm_nanopi-r2c-plus" target/linux/rockchip/image/armv8.mk 2>/dev/null; then
        log_info "添加 R2C Plus 设备定义..."
        
        # 找到合适的位置插入（在 nanopi-r2s 之后）
        local insert_line=$(grep -n "TARGET_DEVICES += friendlyarm_nanopi-r2s" target/linux/rockchip/image/armv8.mk | tail -1 | cut -d: -f1)
        
        if [ -n "$insert_line" ]; then
            # 使用优化的设备定义
            sed -i "${insert_line}a\\
\\
define Device/friendlyarm_nanopi-r2c-plus\\
  DEVICE_VENDOR := FriendlyARM\\
  DEVICE_MODEL := NanoPi R2C Plus\\
  SOC := rk3328\\
  UBOOT_DEVICE_NAME := nanopi-r2c-plus-rk3328\\
  IMAGE/sysupgrade.img.gz := boot-combined | boot-script nanopi-r2c-plus | sdcard-img | gzip | append-metadata\\
  DEVICE_PACKAGES := kmod-usb-net-rtl8152 kmod-r8169 kmod-ata-ahci kmod-ata-core\\
    kmod-usb-storage kmod-usb-storage-uas kmod-usb-net-cdc-ether kmod-usb-net-asix\\
    kmod-usb-net-asix-ax88179 kmod-crypto-rockchip kmod-hw-random-rockchip\\
    kmod-mmc kmod-dwmmc-rockchip kmod-phy-realtek\\
  SUPPORTED_DEVICES += nanopi-r2c-plus\\
endef\\
TARGET_DEVICES += friendlyarm_nanopi-r2c-plus" target/linux/rockchip/image/armv8.mk
        else
            # 追加到文件末尾
            cat >> target/linux/rockchip/image/armv8.mk << 'EOF'

define Device/friendlyarm_nanopi-r2c-plus
  DEVICE_VENDOR := FriendlyARM
  DEVICE_MODEL := NanoPi R2C Plus
  SOC := rk3328
  UBOOT_DEVICE_NAME := nanopi-r2c-plus-rk3328
  IMAGE/sysupgrade.img.gz := boot-combined | boot-script nanopi-r2c-plus | sdcard-img | gzip | append-metadata
  DEVICE_PACKAGES := kmod-usb-net-rtl8152 kmod-r8169 kmod-ata-ahci kmod-ata-core
    kmod-usb-storage kmod-usb-storage-uas kmod-usb-net-cdc-ether kmod-usb-net-asix
    kmod-usb-net-asix-ax88179 kmod-crypto-rockchip kmod-hw-random-rockchip
    kmod-mmc kmod-dwmmc-rockchip kmod-phy-realtek
  SUPPORTED_DEVICES += nanopi-r2c-plus
endef
TARGET_DEVICES += friendlyarm_nanopi-r2c-plus
EOF
        fi
        log_success "设备定义已添加"
    fi
    
    # 2. 添加网络配置
    local network_file="${base_files_dir}/etc/board.d/02_network"
    if [ ! -f "$network_file" ]; then
        touch "$network_file"
        chmod +x "$network_file"
        
        # 添加 shebang
        echo '#!/bin/sh' > "$network_file"
        echo '' >> "$network_file"
        echo '. /lib/functions.sh' >> "$network_file"
        echo '. /lib/functions/system.sh' >> "$network_file"
        echo '' >> "$network_file"
    fi
    
    if ! grep -q "nanopi-r2c-plus" "$network_file" 2>/dev/null; then
        log_info "添加 R2C Plus 网络配置..."
        
        # 在 case 语句中添加
        if grep -q "^case.*board_name" "$network_file"; then
            # 找到 case 语句的结束位置
            local case_end=$(grep -n "^esac" "$network_file" | head -1 | cut -d: -f1)
            
            if [ -n "$case_end" ]; then
                # 在 esac 前插入
                sed -i "${case_end}i\\
	friendlyarm,nanopi-r2c-plus)\\
		ucidef_set_interface_lan \"eth0\" \"192.168.101.1\" \"255.255.255.0\"\\
		# 检测 USB 网卡\\
		for iface in eth1 eth2; do\\
			[ -e \"/sys/class/net/\${iface}\" ] \&\& ucidef_set_interface_wan \"\${iface}\" \&\& break\\
		done\\
		;;" "$network_file"
            fi
        else
            # 添加完整的 case 语句
            cat >> "$network_file" << 'EOF'

case "$(board_name)" in
friendlyarm,nanopi-r2c-plus)
    ucidef_set_interface_lan "eth0" "192.168.101.1" "255.255.255.0"
    # 检测 USB 网卡
    for iface in eth1 eth2; do
        [ -e "/sys/class/net/${iface}" ] && ucidef_set_interface_wan "${iface}" && break
    done
    ;;
esac
EOF
        fi
        log_success "网络配置已添加"
    fi
    
    # 3. 添加热插拔配置（简化版）
    local hotplug_file="${base_files_dir}/etc/hotplug.d/net/10-r2cplus-net"
    if [ ! -f "$hotplug_file" ]; then
        log_info "创建热插拔配置..."
        
        cat > "$hotplug_file" << 'EOF'
#!/bin/sh

[ "$ACTION" = "add" ] || exit 0

. /lib/functions.sh

case "$(board_name)" in
friendlyarm,nanopi-r2c-plus)
    # USB 网卡热插拔支持
    case "$INTERFACE" in
        eth1|eth2)
            logger -t r2cplus-hotplug "USB网卡 $INTERFACE 插入"
            
            # 检查是否已配置为WAN
            if ! uci get network.wan 2>/dev/null; then
                uci set network.wan=interface
                uci set network.wan.device="$INTERFACE"
                uci set network.wan.proto="dhcp"
                uci commit network
                logger -t r2cplus-hotplug "已配置 $INTERFACE 为WAN口"
            fi
            ;;
    esac
    ;;
esac

exit 0
EOF
        chmod +x "$hotplug_file"
        log_success "热插拔配置已创建"
    fi
    
    # 4. 创建系统优化脚本
    local sysopt_file="${base_files_dir}/etc/board.d/01_r2cplus_sysopt"
    if [ ! -f "$sysopt_file" ]; then
        log_info "创建系统优化配置..."
        
        cat > "$sysopt_file" << 'EOF'
#!/bin/sh

. /lib/functions.sh

case "$(board_name)" in
friendlyarm,nanopi-r2c-plus)
    # 系统启动时的优化设置
    logger -t r2cplus-sysopt "应用R2C Plus优化设置"
    
    # CPU性能优化（启动时）
    echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || true
    
    # 启用所有CPU核心
    for cpu in /sys/devices/system/cpu/cpu[1-9]*/online; do
        [ -f "$cpu" ] && echo 1 > "$cpu" 2>/dev/null || true
    done
    
    # 内存优化
    echo 0 > /proc/sys/vm/swappiness 2>/dev/null || true
    echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null || true
    
    # 网络优化
    for iface in /sys/class/net/eth*; do
        [ -d "$iface" ] && ethtool -K "$(basename "$iface")" rx on tx on 2>/dev/null || true
    done
    
    # 设置串口控制台
    echo ttyS2 > /sys/devices/virtual/tty/console/active 2>/dev/null || true
    
    logger -t r2cplus-sysopt "优化设置完成"
    ;;
esac

exit 0
EOF
        chmod +x "$sysopt_file"
        log_success "系统优化配置已创建"
    fi
    
    log_success "备用配置创建完成"
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    
    # 删除备份目录中的临时文件（保留日志）
    find "$BACKUP_DIR" -name "*.tmp" -delete 2>/dev/null || true
    
    log_success "清理完成"
}

# 生成报告
generate_report() {
    local report_file="${BACKUP_DIR}/patch-report-${TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
==========================================
R2C Plus 补丁应用报告
==========================================
应用时间: $(date)
脚本版本: 2.1
OpenWrt目录: $OPENWRT_DIR
补丁目录: $PATCHES_DIR

应用状态: $([ $? -eq 0 ] && echo "成功" || echo "失败")

补丁文件:
$(ls -la "$PATCHES_DIR"/*.patch 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes)"}' || echo "  无")

验证结果:
  设备定义: $(grep -q "friendlyarm_nanopi-r2c-plus" target/linux/rockchip/image/armv8.mk 2>/dev/null && echo "存在" || echo "缺失")
  网络配置: $(grep -q "nanopi-r2c-plus" target/linux/rockchip/armv8/base-files/etc/board.d/02_network 2>/dev/null && echo "存在" || echo "缺失")
  热插拔配置: $(find target/linux/rockchip/armv8/base-files/etc/hotplug.d -name "*r2c*" -o -name "*rk3328*" 2>/dev/null | grep -q . && echo "存在" || echo "缺失")

备份文件位置: $BACKUP_DIR/pre-patch-backup-${TIMESTAMP}

下一步操作:
  1. 运行 make menuconfig 检查配置
  2. 选择 Target Profile: FriendlyARM NanoPi R2C Plus
  3. 编译固件: make -j\$(nproc)

注意事项:
  如果编译失败，请检查:
    - 补丁是否与OpenWrt版本兼容
    - 设备定义是否正确
    - 网络配置是否有冲突

报告生成时间: $(date)
==========================================
EOF
    
    log_success "报告已生成: $report_file"
    cat "$report_file"
}

# 主函数
main() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}    iStoreOS R2C Plus 补丁应用工具    ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    # 检查必要命令
    check_command "patch"
    check_command "git"
    check_command "sed"
    
    # 初始化
    init_variables
    
    # 备份
    backup_files
    
    # 检查补丁
    if ! check_patches; then
        log_warning "未找到补丁文件，将创建基础配置"
        create_fallback_config
        verify_patches
        generate_report
        exit 0
    fi
    
    # 应用补丁
    if ! apply_patches; then
        log_error "补丁应用失败，尝试创建备用配置"
        create_fallback_config
    fi
    
    # 验证
    verify_patches
    
    # 清理
    cleanup
    
    # 生成报告
    generate_report
    
    echo ""
    log_success "补丁应用流程完成！"
    echo -e "${GREEN}请运行 make menuconfig 检查配置${NC}"
}

# 异常处理
trap 'log_error "脚本被中断"; exit 1' INT TERM
trap 'cleanup' EXIT

# 运行主函数
main "$@"