#!/bin/bash
source shell/custom-packages.sh
# 该文件实际为imagebuilder容器内的build.sh

if [ -n "$CUSTOM_PACKAGES" ]; then
  echo "✅ 你选择了第三方软件包：$CUSTOM_PACKAGES"
  if [ "$PROFILE" = "glinet_gl-mt3000" ]; then
    echo "❌ 检查到您集成了第三方软件包 由于mt3000闪存空间较小 不支持此操作"
    echo "✅ 系统将自动帮你注释掉shell/custom-packages.sh中的插件 目前支持第三方插件集成的机型是mt2500/mt6000等大闪存机型"
    CUSTOM_PACKAGES=""
  else
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
  fi
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
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filebrowser-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
#23.05
PACKAGES="$PACKAGES luci-i18n-opkg-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
# 增加几个必备组件 方便用户安装iStore
PACKAGES="$PACKAGES fdisk"
PACKAGES="$PACKAGES script-utils"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"
# 第三方软件包 合并
# ======== shell/custom-packages.sh =======
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "true" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
    # Download China IP data
    wget -q https://github.com/alecthw/mmdb_china_ip_list/releases/download/202508110312/Country.mmdb -O > files/etc/openclash/Country.mmdb
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 判断是否使用XR30 Led配置文件
if [ "$USE_XR30_LED_DTS" = "true" ]; then
    cp mediatek-filogic/dtsi/mt7981-cmcc-xr30-emmc.dtsi target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek/mt7981-cmcc-rax3000m.dtsi
    echo "✅ 使用XR30 Led配置文件"
fi


# 设置WiFi驱动版本，默认为v7.6.6.2
if [ "$WIFI_DRIVER_VERSION" == "v7.6.6.1" ]; then
  sed -i 's/CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7672=y/CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7661=y/g' .config
fi
if [ "$WIFI_DRIVER_FIRMWARE" == "default" ]; then
  sed -i 's/CONFIG_MTK_MT_WIFI_MT7981_20240823=y/CONFIG_MTK_MT_WIFI_MT7981_DEFAULT_FIRMWARE=y/g' .config
else
  sed -i 's/CONFIG_MTK_MT_WIFI_MT7981_20240823=y/CONFIG_MTK_MT_WIFI_MT7981_${firmware}=y/g' .config
fi


###############################################################
if [ "$USE_NX30PRO_EEPROM" == "default" ]; then
  echo "✅ 使用nx30pro的高功率eeprom"
  # 修复 EEPROM 文件冲突 (使用 kmod-mt_wifi 的 EEPROM)
  if [ -f "target/linux/mediatek/mt7981/base-files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin" ]; then
    echo "移除 base-files 中的 EEPROM 文件以避免冲突"
    rm -f target/linux/mediatek/mt7981/base-files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin
  fi
  # 恢复原始的 EEPROM 提取代码
  if [ -f "target/linux/mediatek/mt7981/base-files/lib/preinit/90_extract_caldata" ]; then
    sed -i 's/# caldata_extract_mmc/caldata_extract_mmc/' target/linux/mediatek/mt7981/base-files/lib/preinit/90_extract_caldata
  fi
  # 确保 kmod-mt_wifi 中的 EEPROM 安装代码存在
  if [ -f "package/mtk/drivers/mt_wifi/Makefile" ]; then
    if ! grep -q "MT7981_iPAiLNA_EEPROM\.bin" package/mtk/drivers/mt_wifi/Makefile; then
      echo "恢复 kmod-mt_wifi 中的 EEPROM 安装代码"
              
      # 备份原始 Makefile
      cp package/mtk/drivers/mt_wifi/Makefile package/mtk/drivers/mt_wifi/Makefile.backup
              
      # 添加 EEPROM 安装代码
      if grep -q "define Package/.*/install" package/mtk/drivers/mt_wifi/Makefile; then
        sed -i '/define Package\/\$(PKG_NAME)\/install/a\\t$(INSTALL_DIR) $(1)/lib/firmware\n\t$(INSTALL_DATA) ./files/mt7981-default-eeprom/MT7981_iPAiLNA_EEPROM.bin $(1)/lib/firmware/' package/mtk/drivers/mt_wifi/Makefile
      else
        cat >> package/mtk/drivers/mt_wifi/Makefile << 'EOF'

  define Package/$(PKG_NAME)/install
    $(INSTALL_DIR) $(1)/lib/firmware
    $(INSTALL_DATA) ./files/mt7981-default-eeprom/MT7981_iPAiLNA_EEPROM.bin $(1)/lib/firmware/
  endef
  EOF
      fi
    fi
  fi
  # 确保 EEPROM 文件存在
  if [ ! -f "package/mtk/drivers/mt_wifi/files/mt7981-default-eeprom/MT7981_iPAiLNA_EEPROM.bin" ]; then
    echo "创建 EEPROM 文件目录"
    mkdir -p package/mtk/drivers/mt_wifi/files/mt7981-default-eeprom
          
    # 使用 NX30Pro 的 EEPROM（如果启用）
    if [ "$USE_NX30PRO_EEPROM" = "true" ] && [ -f "eeprom/nx30pro_eeprom.bin" ]; then
      echo "使用 NX30Pro 的 EEPROM 文件"
      cp mediatek-filogic/eeprom/nx30pro_eeprom.bin package/mtk/drivers/mt_wifi/files/mt7981-default-eeprom/MT7981_iPAiLNA_EEPROM.bin
    else
      echo "使用默认的 EEPROM 文件（需要后续从设备提取）"
      touch package/mtk/drivers/mt_wifi/files/mt7981-default-eeprom/MT7981_iPAiLNA_EEPROM.bin
    fi
  fi

fi
###############################################################



# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files"

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
