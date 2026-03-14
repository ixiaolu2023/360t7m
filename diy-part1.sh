#!/bin/bash
# 添加 Passwall 及其依赖的数据源
#sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall' feeds.conf.default
# (可选) 添加其他常用插件源
#sed -i '$a src-git helloworld https://github.com/fw876/helloworld' feeds.conf.default
# 强制 Mediatek Filogic 系列使用 5.15 内核
sed -i 's/KERNEL_PATCHVER:=6.6/KERNEL_PATCHVER:=5.15/g' target/linux/mediatek/Makefile
