# iStoreOS for NanoPi R2C Plus

[![GitHub Actions](https://github.com/EZ-6086/istoreos-R2C-Plus/workflows/Build%20iStoreOS%20for%20R2C%20Plus/badge.svg)](https://github.com/EZ-6086/istoreos-R2C-Plus/actions)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

专为 FriendlyARM NanoPi R2C Plus 优化的 iStoreOS 固件，基于 OpenWrt 24.10 和 iStoreOS。

## ✨ 特性

- ✅ 完整的 iStore 应用商店支持
- ✅ FriendlyWrt 24.10 兼容性
- ✅ 硬件加速网络转发
- ✅ Argon 现代化主题界面
- ✅ BBR 网络优化算法
- ✅ Docker 容器支持（完整版）
- ✅ 自动硬件识别和配置

## 📦 构建类型

### 1. 精简版 (minimal) - **默认**
- 最小化系统，适合GitHub Actions构建
- 禁用所有大型软件包
- 仅包含基础功能
- 可通过iStore在线安装额外功能

### 2. 完整版 (full)
- 包含大部分常用功能
- 保留iStore完整生态
- 仍然禁用Docker等大型包

### 3. Docker版 (docker)
- 包含Docker支持
- 需要更多磁盘空间
- 建议本地构建

## 🚀 快速开始

### GitHub Actions 云编译

1. Fork 本仓库
2. 进入 Actions 页面
3. 选择 "Build iStoreOS for R2C Plus"
4. 点击 "Run workflow"
5. 选择构建类型（推荐使用 minimal）
6. 等待编译完成，下载固件

### 本地构建

```bash
# 克隆仓库
git clone https://github.com/EZ-6086/istoreos-R2C-Plus.git
cd istoreos-R2C-Plus

# 运行构建脚本
./scripts/apply_patches.sh
./scripts/custom_scripts.sh

# 进入OpenWrt目录
cd istoreos/openwrt

# 配置
make menuconfig
# 选择: Target System -> Rockchip ARMv8
# 选择: Subtarget -> RK33xx
# 选择: Target Profile -> FriendlyARM NanoPi R2C Plus

# 编译
make -j$(nproc)


## 📁 文件结构
	istoreos-R2C-Plus/
	├── .github/workflows/      # GitHub Actions配置
	├── configs/                # 编译配置文件
	│   ├── r2cplus.config      # 完整配置
	│   └── r2cplus-minimal.config # 精简配置
	├── patches/                # 内核补丁
	├── scripts/                # 构建脚本
	└── README.md              # 说明文档

### 🔧 自定义配置
可以通过修改以下文件自定义固件：

configs/r2cplus.config - 完整功能配置

configs/r2cplus-minimal.config - 精简配置

scripts/custom_scripts.sh - 系统配置

patches/r2cplus-boot.patch - 内核补丁

### 📊 磁盘空间优化
为在 GitHub Actions 上成功构建，本配置：

❌ 禁用了 Docker 相关包

❌ 禁用了 Python3 相关包

❌ 禁用了 Node.js 相关包

❌ 禁用了 Git/Golang 开发工具

❌ 禁用了 Samba 文件共享

❌ 禁用了 CUPS 打印服务器

✅ 保留了 iStore 核心功能

✅ 保留了基础网络功能

✅ 保留了硬件加速支持

### 🔐 默认设置
管理地址: http://192.168.101.1

用户名: root

密码: admin

SSH端口: 22

重要：首次登录后请立即修改默认密码！

### 🛠️ 故障排除
GitHub Actions 构建失败
磁盘空间不足

使用 "minimal" 构建类型

检查配置文件是否禁用了大型包

编译超时

默认超时240分钟

可修改 .github/workflows/build-firmware.yml 中的 timeout-minutes

下载失败

GitHub Actions 会自动重试3次

可检查网络连接

刷机后问题
无法启动

确保使用正确的固件文件（sysupgrade.img.gz）

参考 FriendlyARM 官方刷机教程

网络不工作

检查网线连接

默认 LAN 口为 eth0

WAN 口自动检测（eth1 或 eth2）

### 特别提示 
因精力有限不提供任何技术支持和教程等相关问题解答，不保证完全无 BUG！

本人不对任何人因使用本固件所遭受的任何理论或实际的损失承担责任！

本固件禁止用于任何商业用途，请务必严格遵守国家互联网使用相关法律规定！

### 📄 许可证
本项目基于 GPL-3.0 许可证开源。

### 🙏 致谢
iStoreOS - 提供应用商店生态

FriendlyWrt - 提供硬件支持

OpenWrt - 优秀的路由器系统

所有贡献者和测试者


	## 📋 使用说明

	### 1. **首次使用**
	1. Fork 本仓库到你的 GitHub 账户
	2. 进入 Actions 页面，启用工作流
	3. 手动触发构建，选择 "minimal" 类型
	4. 等待约 2-3 小时完成构建
	5. 下载固件文件

	### 2. **刷机步骤**
	1. 使用 balenaEtcher 或 dd 命令刷入固件
	2. 插入 TF 卡到 R2C Plus
	3. 连接网线和电源
	4. 访问 http://192.168.101.1
	5. 使用 root/admin 登录

	### 3. **扩展功能**
	固件内置 iStore，可以通过应用商店安装：
	- Docker 容器
	- 网络工具
	- 媒体服务器
	- 其他插件

	## 🎯 优化成果

	通过以上优化，预计可以：

	1. **减少磁盘使用**: 500-700MB
	2. **减少内存使用**: 1-2GB 编译内存
	3. **缩短编译时间**: 30-40%
	4. **提高成功率**: GitHub Actions 构建成功率 >90%

	这个配置是专门为 GitHub Actions 环境优化的，应该能在标准的 14GB SSD 环境中成功构建。如果需要完整功能，建议在本地机器或拥有更多资源的 CI 环境中使用完整版配置。
