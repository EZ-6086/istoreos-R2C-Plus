# R2C Plus iStoreOS 定制固件

基于 iStoreOS 和 FriendlyWrt 24.10 的定制固件，专为 NanoPi R2C Plus 优化。

##特性

-✅ 默认IP地址：192.168.101.1
-✅ 集成 iStore 应用商店
-✅ FriendlyWrt 24.10 兼容性
-✅ Docker 容器支持
-✅ iStoreX 插件系统
-✅ Argon 主题界面
-✅ 完整的 USB 网卡驱动
-✅ 性能优化配置

##快速开始

### 编译固件

1. 分叉 本仓库
2. 进入仓库的 Actions 页面
3. 选择 "为 R2C Plus 构建 iStoreOS" 工作流
4. 点击 "Run workflow" 开始编译
5.等待约2-3小时完成编译
6. 在 Artifacts 中下载固件

### 刷机步骤

1. 使用 balenaEtcher 将固件写入 SD 卡
2. 将 SD 卡插入 R2C Plus
3. 连接网络：
   - 本地网络接口: eth0 (192.168.101.1)
   - USB 网卡: eth1 (WAN口，自动获取IP)
4. 上电启动
5. 访问 http://192.168.101.1
6. 用户名: root
7. 密码: 管理员

##默认配置

- **管理地址**: 192.168.101.1
- **用户名**: root
- **密码**: 管理员
- **DHCP 范围**: 192.168.101.100 - 192.168.101.250
- **时区**: 亚洲/上海 (CST-8)
- **语言**: 简体中文

## 包含的软件包

- iStore 应用商店
- Docker & Docker Compose
- Samba4 文件共享
- AdGuard 家庭版
- 智能DNS
-WireGuard VPN
- OpenVPN
- Aria2 下载器
- 网络监控工具
- 性能优化工具

## 文件结构
	├── .github/workflows/ # GitHub Actions 配置
	├── configs/ # 编译配置文件
	│ ├── r2cplus.config # R2C Plus 专用配置
	│ └── common.config # 通用配置
	├── patches/ # 内核补丁
	│ └── r2cplus-boot.patch # R2C Plus 引导补丁
	├── scripts/ # 构建脚本
	│ ├── apply_patches.sh # 应用补丁脚本
	│ └── custom_scripts.sh # 自定义配置脚本
	└── README.md # 说明文档


##自定义配置

可以通过修改以下文件自定义固件：

1. `configs/r2cplus.config` - 软件包选择
2. `scripts/custom_scripts.sh` - 系统配置
3. `patches/r2cplus-boot.patch` - 内核补丁

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

## 常见问题

### Q: 编译失败怎么办？
A: 检查 Actions 日志，常见问题：
- 网络超时：重试编译
- 依赖缺失：确保所有feeds配置正确
- 空间不足：GitHub Runner有空间限制

### Q: 刷机后无法启动？
A: 尝试以下步骤：
1. 检查SD卡质量
2. 重新写入固件
3. 尝试不同版本的uboot

### Q: USB网卡不识别？
A: 确保已安装正确的驱动：
- r8152: kmod-usb-net-rtl8152
- asix: kmod-usb-net-asix
- cdc_ether: kmod-usb-net-cdc-ether

## 更新日志

### v1.0.0
- 初始版本发布
- 基于 iStoreOS 和 FriendlyWrt 24.10
- 默认IP改为 192.168.101.1
- 完整的 R2C Plus 支持

## 许可证

本项目基于 GPL-2.0 许可证开源。

## 贡献

欢迎提交 Issue 和 Pull Request 来改善此项目。

## 致谢

- [iStoreOS](https://github.com/istoreos/istoreos)
- [FriendlyWrt](https://github.com/friendlyarm/friendlywrt)
- [OpenWrt](https://openwrt.org/)

- [FriendlyARM](https://www.friendlyarm.com/)




