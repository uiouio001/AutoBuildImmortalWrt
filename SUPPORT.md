# 本项目支持的机型列表

>  ### x86-64 工作流

| 🖥️ 工作流分类            | 处理器            | 备注         | luci版本        |
| ---------------- | -------------- | ---------- |---------- |
| x86-64 efi.img.gz  | Intel/AMD | EFI向下兼容传统BIOS |24.10.x |
| x86-64 OpenWrt安装器   | Intel/AMD | ISO格式适用于任何虚拟机和任何物理机 引导后输入ddd来安装 |24.10.x |

>  ### MediaTek 路由器工作流（大约103种）build-wireless-router.yml 

| 机型 | 机型 | 机型 |
|------|------|------|
| cmcc_rax3000m | cmcc_rax3000me |  |
| **cmcc_rax3000m-emmc-ubootmod** | **cmcc_rax3000m-nand-ubootmod** |   |

> ### 硬路由固件格式说明

| 文件类型 | 用途        | 内容               | 常用场景             |
| ---- | --------- | ---------------- | ---------------- |
| FIP  | Arm 固件包   | BL1/BL2/BL31 等   | CPU 上电启动         |
| BIN  | 泛二进制      | Bootloader/内核等   | 烧录或加载执行          |
| UBI  | NAND 文件系统 | UBIFS 镜像         | 嵌入式 NAND 路由器/开发板 |
| ITB  | U-Boot 镜像 | 内核+设备树+initramfs | U-Boot 启动镜像      |

