#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Honor Fur-602 本地编译脚本
# 硬件规格: MT7981 (Filogic 820) + DDR3 512MB + SPI-NAND 256MB
#
# 用法:
#   ./build.sh          # 首次编译
#   ./build.sh clean    # 清理编译产物
#   ./build.sh rebuild  # 重新编译
#   ./build.sh menuconfig  # 配置内核

set -e

WRT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
WRT_CONFIG="honor_fur-602"
WRT_DATE="$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")"
WRT_MARK="local"
WRT_THEME="aurora"
WRT_NAME="CWRT"
WRT_SSID="CWRT"
WRT_WORD="12345678"
WRT_IP="192.168.10.1"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_err() { echo -e "${RED}[ERROR]${NC} $1"; }

cd "$WRT_DIR"

case "${1:-}" in
    clean)
        echo_info "清理编译产物..."
        make clean -j$(nproc) 2>/dev/null || true
        rm -f build.log
        echo_info "清理完成"
        exit 0
        ;;
    rebuild)
        echo_info "重新编译..."
        make clean -j$(nproc) 2>/dev/null || true
        rm -f build.log
        ;;
    menuconfig)
        echo_info "启动配置菜单..."
        make menuconfig
        # 保存配置
        cp .config "$BUILD_DIR/config.seed"
        echo_info "配置已保存到 $BUILD_DIR/config.seed"
        exit 0
        ;;
esac

echo "=========================================="
echo " Honor Fur-602 本地编译"
echo "=========================================="
echo "源码路径:   $WRT_DIR"
echo "目标设备:   $WRT_CONFIG"
echo "内存:       DDR3 512MB"
echo "闪存:       SPI-NAND 256MB"
echo "日期:       $WRT_DATE"
echo "=========================================="

# 检查是否存在预设配置
if [ -f "$BUILD_DIR/config.seed" ]; then
    echo_info "使用预设配置: $BUILD_DIR/config.seed"
    cp "$BUILD_DIR/config.seed" .config
else
    echo_info "使用默认配置..."

    # 基础配置
    cat > .config << 'CONFIG_EOF'
# 平台
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
# 设备
CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_honor_fur-602=y
# 基础
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_TARGET_ROOTFS_INITRAMFS=n
CONFIG_CCACHE=y
CONFIG_DEVEL=y
# 中文支持
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-${WRT_THEME}=y
CONFIG_PACKAGE_luci-app-${WRT_THEME}-config=y
# 科学插件
CONFIG_PACKAGE_luci-app-homeproxy=y
# 常用插件
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-mini-diskmanager=y
CONFIG_PACKAGE_luci-app-wolultra=y
CONFIG_PACKAGE_luci-app-eqos-mtk=y
CONFIG_PACKAGE_luci-app-mtwifi-cfg=y
CONFIG_PACKAGE_luci-app-turboacc-mtk=y
# 工具
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_coremark=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_openssl-util=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_nand-utils=y
CONFIG_PACKAGE_usb-modeswitch=y
CONFIG_EOF
fi

# 初始化 feeds (如果尚未执行)
if [ ! -d "./feeds" ] || [ ! -f "./feeds.tmp" ]; then
    echo_info "初始化 feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    touch feeds.tmp
fi

# 生成 defconfig
echo_info "生成 defconfig..."
make defconfig -j$(nproc)

# 下载包
echo_info "下载依赖包..."
make download -j$(nproc) 2>&1 || make download -j1 V=s

# 编译固件
echo_info "开始编译固件..."
echo "=========================================="

if make -j$(nproc) 2>&1 | tee build.log; then
    echo "=========================================="
    echo_info "编译成功!"
    echo_info "输出目录: $WRT_DIR/bin/targets/mediatek/filogic/"
    echo_info "编译日志: $WRT_DIR/build.log"
    echo "=========================================="

    # 列出固件文件
    echo_info "固件文件列表:"
    find "$WRT_DIR/bin/targets/" -type f -name "*.bin" -o -name "*.itb" -o -name "*.tar" 2>/dev/null | sort
else
    echo_err "编译失败! 查看日志: $WRT_DIR/build.log"
    exit 1
fi