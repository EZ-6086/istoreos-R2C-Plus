# 创建脚本文件
cd /opt/build
cat > build-all.sh << 'EOF'
#!/bin/bash
# iStoreOS R2C Plus 一键编译脚本（最终版）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 工作目录配置
WORKDIR="/opt/build"
OPENWRT_DIR="$WORKDIR/istoreos/openwrt"
OUTPUT_DIR="$WORKDIR/output"

# 日志函数
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
warning() { echo -e "${YELLOW}!${NC} $1"; }

# 检查环境
check_environment() {
    log "检查编译环境..."
    
    # 检查是否为Ubuntu 22.04
    if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
        warning "非Ubuntu 22.04系统，可能不兼容"
    fi
    
    # 检查磁盘空间
    local available=$(df -BG /opt | awk 'NR==2{print $4}' | tr -d 'G')
    if [ "$available" -lt 30 ]; then
        error "磁盘空间不足，需要至少30GB，当前可用${available}GB"
        exit 1
    fi
    
    # 检查内存
    local mem=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$mem" -lt 4 ]; then
        warning "内存小于4GB，编译可能会很慢"
    fi
    
    # 检查必要命令
    local commands=("git" "make" "gcc" "curl" "wget")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "缺少必要命令: $cmd"
            exit 1
        fi
    done
    
    success "环境检查通过"
}

# 安装依赖
install_dependencies() {
    log "安装编译依赖..."
    
    # 更新系统
    sudo apt update
    sudo apt upgrade -y
    
    # 安装OpenWrt编译依赖
    sudo apt install -y \
        build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
        gettext git libncurses5-dev libssl-dev python3 python3-pip python3-setuptools \
        rsync subversion swig time xsltproc zlib1g-dev file unzip wget curl \
        ccache ecj fastjar java-propose-classpath libelf-dev nodejs \
        python3-distutils qemu-utils rename libxml-parser-perl \
        libjson-perl libfile-slurp-perl cmake pkg-config \
        automake autoconf libtool u-boot-tools cpio
    
    # 安装Python包
    pip3 install --user pyelftools
    
    success "依赖安装完成"
}

# 获取源码
get_sources() {
    log "获取源码..."
    
    cd $WORKDIR
    
    # 克隆iStoreOS源码
    if [ ! -d "istoreos" ]; then
        git clone --depth=1 -b main https://github.com/istoreos/istoreos.git
        success "克隆iStoreOS完成"
    else
        warning "iStoreOS目录已存在，跳过克隆"
    fi
    
    cd istoreos
    
    # 克隆OpenWrt源码
    if [ ! -d "openwrt" ]; then
        git clone --depth=1 -b openwrt-24.10 https://github.com/openwrt/openwrt.git
        success "克隆OpenWrt完成"
    else
        warning "OpenWrt目录已存在，跳过克隆"
    fi
    
    success "源码获取完成"
}

# 配置feeds
configure_feeds() {
    log "配置feeds..."
    
    cd $OPENWRT_DIR
    
    # 创建feeds配置
    cat > feeds.conf.custom << 'FEEDS_EOF'
src-git friendlywrt https://github.com/friendlyarm/friendlywrt.git;master-v24.10
src-git istore https://github.com/linkease/istore.git;main
src-git packages https://git.openwrt.org/feed/packages.git;openwrt-24.10
src-git luci https://git.openwrt.org/project/luci.git;openwrt-24.10
src-git routing https://git.openwrt.org/feed/routing.git;openwrt-24.10
src-git telephony https://git.openwrt.org/feed/telephony.git;openwrt-24.10
FEEDS_EOF
    
    # 合并feeds配置
    cp feeds.conf.default feeds.conf
    cat feeds.conf.custom >> feeds.conf
    
    # 更新和安装feeds
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    
    success "Feeds配置完成"
}

# 应用补丁
apply_patches() {
    log "应用补丁..."
    
    cd $OPENWRT_DIR
    
    # 检查是否有补丁文件
    if [ -d "$WORKDIR/patches" ]; then
        for patch in $WORKDIR/patches/*.patch; do
            if [ -f "$patch" ]; then
                log "应用补丁: $(basename $patch)"
                patch -p1 < "$patch" || warning "补丁应用失败: $(basename $patch)"
            fi
        done
    else
        warning "未找到补丁目录，跳过补丁应用"
    fi
    
    success "补丁应用完成"
}

# 应用自定义配置
apply_custom_config() {
    log "应用自定义配置..."
    
    cd $OPENWRT_DIR
    
    # 检查是否有配置文件
    if [ -f "$WORKDIR/configs/r2cplus.config" ]; then
        cp "$WORKDIR/configs/r2cplus.config" .config
        success "配置文件已应用"
    else
        warning "未找到配置文件，使用默认配置"
        # 创建基础配置
        cat > .config << 'CONFIG_EOF'
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-r2c-plus=y
CONFIG_TARGET_ROOTFS_PARTSIZE=512
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_PACKAGE_iStore=y
CONFIG_PACKAGE_luci-app-store=y
CONFIG_EOF
    fi
    
    # 生成默认配置
    make defconfig
    
    success "配置完成"
}

# 下载软件包
download_packages() {
    log "下载软件包..."
    
    cd $OPENWRT_DIR
    
    # 设置重试机制
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        log "下载尝试 $((retry_count + 1))/$max_retries..."
        
        if make download -j$(nproc); then
            success "包下载成功"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            warning "下载失败，60秒后重试..."
            sleep 60
        fi
    done
    
    error "包下载失败"
    exit 1
}

# 开始编译
start_compile() {
    log "开始编译..."
    
    cd $OPENWRT_DIR
    
    # 获取CPU核心数
    local cores=$(nproc)
    local jobs=$((cores + 1))
    
    echo ""
    echo "========================================"
    echo "编译参数:"
    echo "  核心数: $cores"
    echo "  线程数: $jobs"
    echo "  开始时间: $(date)"
    echo "========================================"
    echo ""
    
    # 清理旧的编译文件
    make clean
    
    # 开始编译（带日志记录）
    local log_file="$WORKDIR/build-$(date +%Y%m%d-%H%M%S).log"
    log "编译日志保存到: $log_file"
    
    time make -j${jobs} V=s 2>&1 | tee "$log_file" | grep -E "(error|Error|installing|Compiling|Linking)" | tail -50
    
    success "编译完成"
}

# 检查编译结果
check_results() {
    log "检查编译结果..."
    
    cd $OPENWRT_DIR
    
    # 查找生成的固件
    if find bin/targets -name "*.img" 2>/dev/null | grep -q .; then
        echo ""
        echo "🎉 编译成功！生成的固件:"
        find bin/targets -name "*.img" -o -name "*.gz" | xargs ls -lh
        
        # 创建输出目录
        mkdir -p $OUTPUT_DIR
        
        # 复制固件到输出目录
        find bin/targets -type f \( -name "*.img" -o -name "*.gz" \) -exec cp {} $OUTPUT_DIR/ \;
        
        success "固件已保存到: $OUTPUT_DIR/"
        
        # 生成构建信息
        generate_build_info
        
        return 0
    else
        error "编译失败，未找到固件文件"
        
        # 检查错误日志
        if [ -f "$WORKDIR/build.log" ]; then
            echo "最后50行错误日志:"
            tail -50 "$WORKDIR/build.log"
        fi
        
        exit 1
    fi
}

# 生成构建信息
generate_build_info() {
    log "生成构建信息..."
    
    cat > $OUTPUT_DIR/build-info.txt << EOF
iStoreOS for R2C Plus 编译结果
===========================================
编译时间: $(date)
编译主机: $(hostname)
系统版本: $(lsb_release -ds 2>/dev/null || echo "未知")
内核版本: $(uname -r)
CPU信息: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)

固件列表:
$(find $OUTPUT_DIR -type f -name "*.img" -o -name "*.gz" | while read f; do
    echo "  - $(basename "$f") ($(du -h "$f" | cut -f1))"
done)

刷机指南:
1. 使用 balenaEtcher (https://www.balena.io/etcher/)
2. 或者使用 dd 命令: sudo dd if=固件.img of=/dev/sdX bs=4M status=progress

首次启动:
- IP地址: 192.168.101.1
- 用户名: root
- 密码: admin

重要提示:
1. 首次登录后请立即修改密码
2. 建议配置防火墙规则
3. 定期备份系统配置

技术支持:
https://github.com/EZ-6086/istoreos-R2C-Plus
===========================================
EOF
    
    success "构建信息已保存: $OUTPUT_DIR/build-info.txt"
}

# 显示帮助
show_help() {
    cat << EOF
iStoreOS R2C Plus 一键编译脚本

用法: $0 [选项]

选项:
  --clean         清理编译文件重新开始
  --fast         快速模式（跳过依赖检查）
  --skip-download 跳过包下载（使用缓存）
  --config-only  只配置不编译
  --help         显示此帮助

示例:
  $0                    # 完整编译流程
  $0 --clean           # 清理后重新编译
  $0 --fast            # 快速编译（已有环境）
  $0 --config-only     # 只配置不编译

环境变量:
  WORKDIR:    工作目录（默认: $WORKDIR）
  OUTPUT_DIR: 输出目录（默认: $OUTPUT_DIR）

提示:
  1. 首次编译建议使用默认选项
  2. 编译需要约2-4小时（取决于硬件）
  3. 需要稳定的网络连接以下载包
EOF
}

# 清理编译环境
clean_build() {
    log "清理编译环境..."
    
    if [ -d "$OPENWRT_DIR" ]; then
        cd $OPENWRT_DIR
        make clean
        rm -rf tmp .config*
        success "编译环境已清理"
    else
        warning "编译目录不存在，跳过清理"
    fi
}

# 主函数
main() {
    # 解析参数
    local CLEAN_BUILD=0
    local FAST_BUILD=0
    local SKIP_DOWNLOAD=0
    local CONFIG_ONLY=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            --fast)
                FAST_BUILD=1
                shift
                ;;
            --skip-download)
                SKIP_DOWNLOAD=1
                shift
                ;;
            --config-only)
                CONFIG_ONLY=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示开始信息
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${GREEN}   iStoreOS R2C Plus 一键编译工具       ${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo ""
    
    # 清理选项
    if [ $CLEAN_BUILD -eq 1 ]; then
        clean_build
    fi
    
    # 检查环境
    check_environment
    
    # 安装依赖（除非快速模式）
    if [ $FAST_BUILD -eq 0 ]; then
        install_dependencies
    fi
    
    # 获取源码
    get_sources
    
    # 配置feeds
    configure_feeds
    
    # 应用补丁
    apply_patches
    
    # 应用配置
    apply_custom_config
    
    # 下载包（除非跳过）
    if [ $SKIP_DOWNLOAD -eq 0 ]; then
        download_packages
    fi
    
    # 只配置不编译
    if [ $CONFIG_ONLY -eq 1 ]; then
        success "配置完成，跳过编译"
        log "可以运行: cd $OPENWRT_DIR && make menuconfig"
        exit 0
    fi
    
    # 开始编译
    start_compile
    
    # 检查结果
    check_results
    
    # 显示完成信息
    echo ""
    echo -e "${GREEN}✨ 编译完成！ ✨${NC}"
    echo ""
    echo "固件位置: $OUTPUT_DIR/"
    echo "刷机工具推荐: balenaEtcher (https://www.balena.io/etcher/)"
    echo ""
    echo "首次启动提示:"
    echo "  - 管理地址: http://192.168.101.1"
    echo "  - 默认账号: root"
    echo "  - 默认密码: admin"
    echo ""
    echo "更多信息请查看: $OUTPUT_DIR/build-info.txt"
    echo ""
}

# 运行主函数
trap 'error "脚本被中断"; exit 1' INT TERM
main "$@"
EOF

# 赋予执行权限
chmod +x build-all.sh

echo "一键编译脚本创建完成！"