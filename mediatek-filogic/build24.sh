#!/bin/bash
source shell/custom-packages.sh
# 该文件实际为imagebuilder容器内的build.sh

echo "✅ 编译固件大小为: $ROOTFS_PARTSIZE MB"

if [ -n "$CUSTOM_PACKAGES" ]; then
  echo "✅ 你选择了第三方软件包：$CUSTOM_PACKAGES"
    # 下载 run 文件仓库
    echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
    git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo
    
    # 拷贝 run/arm64 下所有 run 文件和ipk文件 到 extra-packages 目录
    mkdir -p /home/build/immortalwrt/extra-packages
    cp -r /tmp/store-run-repo/run/arm64/* /home/build/immortalwrt/extra-packages/
    
    echo "✅ Run files copied to extra-packages:"
    ls -lh /home/build/immortalwrt/extra-packages/*.run
    # 解压并拷贝ipk到packages目录
    sh shell/prepare-packages.sh
    ls -lah /home/build/immortalwrt/packages/
    # 添加架构优先级信息
    sed -i '1i\
    arch aarch64_generic 10\n\
    arch aarch64_cortex-a53 15' repositories.conf
else
  echo "⚪️ 未选择任何第三方软件包"
fi
# yml 传入的路由器型号 PROFILE
echo "Building for profile: $PROFILE"
echo "Include Docker: $INCLUDE_DOCKER"
echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入pppoe变量————>pppoe-settings文件
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting build process..."


# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl luci luci-i18n-base-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
#PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
#24.10.0
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
# 文件管理器
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
# 静态文件服务器dufs(推荐)
# PACKAGES="$PACKAGES luci-i18n-dufs-zh-cn"
# 增加几个必备组件 方便用户安装iStore
PACKAGES="$PACKAGES fdisk"
PACKAGES="$PACKAGES sgdisk"
PACKAGES="$PACKAGES script-utils"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"

# 第三方软件包 合并
# ======== shell/custom-packages.sh =======
if [ "$PROFILE" = "glinet_gl-axt1800" ] || [ "$PROFILE" = "glinet_gl-ax1800" ]; then
    # 这2款 暂时不支持第三方插件的集成 snapshot版本太高 opkg换成apk包管理器 6.12内核 
    echo "Model:$PROFILE not support third-parted packages"
    PACKAGES="$PACKAGES -luci-i18n-diskman-zh-cn luci-i18n-homeproxy-zh-cn"
else
    echo "Other Model:$PROFILE"
    PACKAGES="$PACKAGES $CUSTOM_PACKAGES"
fi

# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "true" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash core
    echo "👉 Download clash meta"
    # Meta内核版本
    CLASH_META_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.13/mihomo-linux-arm64-v1.19.13.gz"
    wget -qO- $CLASH_META_URL | gunzip -c > files/etc/openclash/core/clash_meta
    # 给内核赋权
    chmod +x files/etc/openclash/core/clash*
    
    # Download GeoIP and GeoSite
    echo "👉 Download GeoIP and GeoSite"
    GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    wget -qO- $GEOIP_URL > files/etc/openclash/GeoIP.dat
    wget -qO- $GEOSITE_URL > files/etc/openclash/GeoSite.dat
    
    # Download China IP database
    echo "👉 Download China IP database"
    COUNTRY_LITE_URL=https://github.com/alecthw/mmdb_china_ip_list/releases/download/202508110312/Country-lite.mmdb
    COUNTRY_FULL_URL=https://github.com/alecthw/mmdb_china_ip_list/releases/download/202508110312/Country.mmdb
    wget -qO- $COUNTRY_FULL_URL > files/etc/openclash/Country.mmdb
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 判断是否使用XR30 Led配置文件
if [ "$USE_XR30_LED_DTS" = "true" ]; then
    cp mediatek-filogic/dtsi/mt7981-cmcc-xr30-emmc.dtsi target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek/mt7981-cmcc-rax3000m.dtsi
    echo "✅ 使用XR30Led配置文件"
else
    echo "⚪️ 使用默认Led配置文件"
fi


# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files"
#make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
