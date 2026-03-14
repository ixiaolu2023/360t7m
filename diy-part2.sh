#!/bin/bash

# 1. 基础信息修改
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXbxq2pRaw5eKhU79vpg1:18856:0:99999:7:::/g' package/base-files/files/etc/shadow
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 2. 生成 uci-defaults 脚本
OUT="package/base-files/files/etc/uci-defaults/99-custom-setup"
mkdir -p $(dirname $OUT)

# 先写入脚本头部
echo "#!/bin/sh" > $OUT
echo "uci -q batch <<EOT" >> $OUT

# 使用本地循环生成 UCI 指令集
for i in $(seq 1 20); do
    IP_THIRD=$((i + 4))
    NET_NAME="lan${i}"
    
    cat <<EOT_LOOP >> $OUT
set network.${NET_NAME}=interface
set network.${NET_NAME}.proto='static'
set network.${NET_NAME}.ipaddr='192.168.${IP_THIRD}.1'
set network.${NET_NAME}.netmask='255.255.255.0'
set network.${NET_NAME}.device='br-lan'
set dhcp.${NET_NAME}=dhcp
set dhcp.${NET_NAME}.interface=${NET_NAME}
set dhcp.${NET_NAME}.start='100'
set dhcp.${NET_NAME}.limit='150'
add_list firewall.@zone[0].network=${NET_NAME}
set firewall.block_${NET_NAME}=rule
set firewall.block_${NET_NAME}.name='Block-Inter-LAN-${i}'
set firewall.block_${NET_NAME}.src='${NET_NAME}'
set firewall.block_${NET_NAME}.dest='*'
set firewall.block_${NET_NAME}.dest_ip='192.168.0.0/16'
set firewall.block_${NET_NAME}.target='REJECT'
EOT_LOOP

    if [ $i -le 10 ]; then
        cat <<EOT_WIFI24 >> $OUT
set wireless.wv24_${i}=wifi-iface
set wireless.wv24_${i}.device='radio0'
set wireless.wv24_${i}.mode='ap'
set wireless.wv24_${i}.network='${NET_NAME}'
set wireless.wv24_${i}.ssid='OpenWrt-2.4G-${i}'
set wireless.wv24_${i}.encryption='psk2'
set wireless.wv24_${i}.key='12345678'
EOT_WIFI24
    else
        cat <<EOT_WIFI5G >> $OUT
set wireless.wv5g_${i}=wifi-iface
set wireless.wv5g_${i}.device='radio1'
set wireless.wv5g_${i}.mode='ap'
set wireless.wv5g_${i}.network='${NET_NAME}'
set wireless.wv5g_${i}.ssid='OpenWrt-5G-${i}'
set wireless.wv5g_${i}.encryption='psk2'
set wireless.wv5g_${i}.key='12345678'
EOT_WIFI5G
    fi

    cat <<EOT_ACL >> $OUT
add passwall acl_rule
set passwall.@acl_rule[-1].enabled='1'
set passwall.@acl_rule[-1].remarks='ACL-LAN${i}'
set passwall.@acl_rule[-1].sources='192.168.${IP_THIRD}.0/24'
EOT_ACL
done

# 写入结尾
echo "commit network" >> $OUT
echo "commit dhcp" >> $OUT
echo "commit firewall" >> $OUT
echo "commit wireless" >> $OUT
echo "commit passwall" >> $OUT
echo "EOT" >> $OUT
echo "exit 0" >> $OUT

chmod +x $OUT
