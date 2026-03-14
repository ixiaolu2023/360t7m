#!/bin/bash

# 1. 基础信息修改
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXbxq2pRaw5eKhU79vpg1:18856:0:99999:7:::/g' package/base-files/files/etc/shadow
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 2. 生成自动化配置脚本 (使用直接写入法，避开 cat 转义地狱)
OUT="package/base-files/files/etc/uci-defaults/99-custom-setup"
mkdir -p $(dirname $OUT)

echo "#!/bin/sh" > $OUT
echo "uci -q batch <<EOT" >> $OUT

for i in $(seq 1 20); do
    IP_THIRD=$((i + 4))
    NET_NAME="lan${i}"
    
    # 写入基础网络和隔离规则
    cat >> $OUT <<EOF
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
EOF

    # 写入无线设置
    if [ $i -le 10 ]; then
        echo "set wireless.wv24_${i}=wifi-iface" >> $OUT
        echo "set wireless.wv24_${i}.device='radio0'" >> $OUT
        echo "set wireless.wv24_${i}.ssid='OpenWrt-2.4G-${i}'" >> $OUT
    else
        echo "set wireless.wv5g_${i}=wifi-iface" >> $OUT
        echo "set wireless.wv5g_${i}.device='radio1'" >> $OUT
        echo "set wireless.wv5g_${i}.ssid='OpenWrt-5G-${i}'" >> $OUT
    fi
    
    # 补全无线公共参数
    cat >> $OUT <<EOF
set wireless.wv24_${i}.mode='ap'
set wireless.wv24_${i}.network='${NET_NAME}'
set wireless.wv24_${i}.encryption='psk2'
set wireless.wv24_${i}.key='12345678'
add passwall acl_rule
set passwall.@acl_rule[-1].enabled='1'
set passwall.@acl_rule[-1].remarks='ACL-LAN${i}'
set passwall.@acl_rule[-1].sources='192.168.${IP_THIRD}.0/24'
EOF
done

echo "commit network" >> $OUT
echo "commit dhcp" >> $OUT
echo "commit firewall" >> $OUT
echo "commit wireless" >> $OUT
echo "commit passwall" >> $OUT
echo "EOT" >> $OUT
echo "exit 0" >> $OUT

chmod +x $OUT
