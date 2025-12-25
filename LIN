# 创建完整的一键编译脚本
cat > /opt/build/build-all.sh << 'EOF'
#!/bin/bash
# iStoreOS R2C Plus 一键编译脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}!${NC} $1"; }

# 检查环境
check_environment() {
    log "检查系统环境..."
    
    # 检查系统
    if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
        warning "非Ubuntu 22.04系统，可能不兼容"
    fi
    
    # 检查磁盘空间
    local available=$(df -BG /opt | awk 'NR==2{print $4}' | tr -d 'G')
    if [ "$available" -lt 30 ]; then
        error "磁盘空间不足，需要至少30GB，当前可用${available}GB"
    fi
    
    # 检查内存
    local mem=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$mem" -lt 8 ]; then
        warning "内存小于8GB，编译可能会很慢"
    fi
    
    success "环境检查通过"
}

# 安装依赖
install_dependencies() {
    log "安装编译依赖..."
    
    sudo apt update
    sudo apt install -y \
        build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
        gettext git libncurses5-dev libssl-dev python3 python3-pip python3-setuptools \
        rsync subversion swig time xsltproc zlib1g-dev file unzip wget curl \
        ccache ecj fastjar java-propose-classpath libelf-dev nodejs \
        python3-distutils qemu-utils rename libxml-parser-perl \
        libjson-perl libfile-slurp-perl cmake pkg-config \
        automake autoconf libtool u-boot-tools cpio
    
    pip3 install --user pyelftools
    
    success "依赖安装完成"
}

# 获取源码
get_sources() {
    log "获取源码..."
    
    cd /opt/build
    
    if [ ! -d "istoreos" ]; then
        git clone --depth=1 -b main https://github.com/istoreos/istoreos.git
        success "克隆iStoreOS完成"
    else
        warning "iStoreOS目录已存在，跳过克隆"
    fi
    
    cd istoreos
    
    if [ ! -d "openwrt" ]; then
        git clone --depth=1 -b openwrt-24.10 https://github.com/openwrt/openwrt.git
        success "克隆OpenWrt完成"
    else
        warning "OpenWrt目录已存在，跳过克隆"
    fi
    
    success "源码获取完成"
}

# 配置编译环境
setup_build() {
    log "配置编译环境..."
    
    cd /opt/build/istoreos/openwrt
    
    # 配置feeds
    cat > feeds.conf.custom << 'FEEDS_EOF'
src-git friendlywrt https://github.com/friendlyarm/friendlywrt.git;master-v24.10
src-git istore https://github.com/linkease/istore.git;main
src-git packages https://git.openwrt.org/feed/packages.git;openwrt-24.10
src-git luci https://git.openwrt.org/project/luci.git;openwrt-24.10
src-git routing https://git.openwrt.org/feed/routing.git;openwrt-24.10
src-git telephony https://git.openwrt.org/feed/telephony.git;openwrt-24.10
FEEDS_EOF
    
    cat feeds.conf.custom >> feeds.conf
    
    # 更新feeds
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    
    # 使用配置文件
    if [ -f "/opt/build/configs/r2cplus.config" ]; then
        cp /opt/build/configs/r2cplus.config .config
        make defconfig
        success "配置文件已应用"
    else
        warning "未找到配置文件，请手动配置"
        make menuconfig
    fi
    
    success "编译环境配置完成"
}

# 下载软件包
download_packages() {
    log "下载软件包..."
    
    cd /opt/build/istoreos/openwrt
    
    for i in {1..3}; do
        log "下载尝试 $i/3..."
        if make download -j$(nproc); then
            success "包下载成功"
            return 0
        elif [ $i -eq 3 ]; then
            error "包下载失败，请检查网络"
        else
            warning "下载失败，60秒后重试..."
            sleep 60
        fi
    done
}

# 开始编译
start_compile() {
    log "开始编译..."
    
    cd /opt/build/istoreos/openwrt
    
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
    
    # 编译
    time make -j${jobs} V=s 2>&1 | tee build.log | grep -E "(error|Error|installing|Compiling|Linking)" | tail -50
    
    success "编译完成"
}

# 检查结果
check_results() {
    log "检查编译结果..."
    
    cd /opt/build/istoreos/openwrt
    
    if find bin/targets -name "*.img" 2>/dev/null | grep -q .; then
        echo ""
        echo "🎉 编译成功！生成的固件:"
        find bin/targets -name "*.img" -o -name "*.gz" | xargs ls -lh
        
        # 复制到输出目录
        mkdir -p /opt/build/output
        find bin/targets -type f \( -name "*.img" -o -name "*.gz" \) -exec cp {} /opt/build/output/ \;
        
        success "固件已保存到 /opt/build/output/"
        
        # 生成信息文件
        cat > /opt/build/output/build-info.txt << INFO_EOF
编译时间: $(date)
主机: $(hostname)
固件列表:
$(find /opt/build/output -type f -name "*.img" -o -name "*.gz" | while read f; do
  echo "  - $(basename "$f") ($(du -h "$f" | cut -f1))"
done)

刷机指南:
1. 使用 balenaEtcher (https://www.balena.io/etcher/)
2. 或者使用 dd 命令: sudo dd if=固件.img of=/dev/sdX bs=4M

首次启动:
- IP地址: 192.168.101.1
- 用户名: root
- 密码: admin
INFO_EOF
        
        return 0
    else
        error "编译失败，未找到固件文件"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${GREEN}=== iStoreOS R2C Plus 一键编译 ===${NC}"
    echo ""
    
    # 执行步骤
    check_environment
    install_dependencies
    get_sources
    setup_build
    download_packages
    start_compile
    check_results
    
    echo ""
    echo -e "${GREEN}✨ 所有步骤完成！ ✨${NC}"
    echo ""
    echo "固件位置: /opt/build/output/"
    echo "刷机工具推荐: balenaEtcher"
    echo "首次启动: http://192.168.101.1"
    echo ""
}

# 运行主函数
main "$@"
EOF

# 赋予执行权限并运行
chmod +x /opt/build/build-all.sh
cd /opt/build
./build-all.sh
