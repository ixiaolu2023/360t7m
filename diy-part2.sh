#!/bin/bash

# 1. 基础信息修改
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate
# 设置默认密码为 password
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXbxq2pRaw5eKhU79vpg1:18856:0:99999:7:::/g' package/base-files/files/etc/shadow
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 2. 自动化配置脚本生成
mkdir -p package/base-files/files/etc/uci-defaults
# 注意：这里使用 <<'EOF' (加引号)，防止变量在写入文件前被提前解析
cat <<'EOF' > package/base-files/files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q batch <<EOT
$(for i in $(seq 1 20); do
    IP_THIRD=$((i + 4))
    NET_NAME="lan${i}"
    
    # 网络接口
    set network.${NET_NAME}=interface
    set network.${NET_NAME}.proto='static'
    set network.${NET_NAME}.ipaddr="192.168.${IP_THIRD}.1"
    set network.${NET_NAME}.netmask='255.255.255.0'
    set network.${NET_NAME}.device='br-lan'
    
    # DHCP
    set dhcp.${NET_NAME}=dhcp
    set dhcp.${NET_NAME}.interface=${NET_NAME}
    set dhcp.${NET_NAME}.start='100'
    set dhcp.${NET_NAME}.limit='150'
    
    # 防火墙区域：将新接口加入到 lan 区域
    add_list firewall.@zone[0].network=${NET_NAME}
    
    # 隔离规则
    set firewall.block_${NET_NAME}=rule
    set firewall.block_${NET_NAME}.name="Block-Inter-LAN-${i}"
    set firewall.block_${NET_NAME}.src="${NET_NAME}"
    set firewall.block_${NET_NAME}.dest='*'
    set firewall.block_${NET_NAME}.dest_ip='192.168.0.0/16'
    set firewall.block_${NET_NAME}.target='REJECT'

    # 无线 SSID (radio0通常是2.4G, radio1是5G)
    if [ $i -le 10 ]; then
        set wireless.wv24_${i}=wifi-iface
        set wireless.wv24_${i}.device='radio0'
        set wireless.wv24_${i}.mode='ap'
        set wireless.wv24_${i}.network=${NET_NAME}
        set wireless.wv24_${i}.ssid="OpenWrt-2.4G-${i}"
        set wireless.wv24_${i}.encryption='psk2'
        set wireless.wv24_${i}.key='12345678'
    else
        set wireless.wv5g_${i}=wifi-iface
        set wireless.wv5g_${i}.device='radio1'
        set wireless.wv5g_${i}.mode='ap'
        set wireless.wv5g_${i}.network=${NET_NAME}
        set wireless.wv5g_${i}.ssid="OpenWrt-5G-${i}"
        set wireless.wv5g_${i}.encryption='psk2'
        set wireless.wv5g_${i}.key='12345678'
    fi

    # Passwall ACL 规则
    add passwall acl_rule
    set passwall.@acl_rule[-1].enabled='1'
    set passwall.@acl_rule[-1].remarks="ACL-LAN${i}"
    set passwall.@acl_rule[-1].sources="192.168.${IP_THIRD}.0/24"
done)
commit network
commit dhcp
commit firewall
commit wireless
commit passwall
EOT
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-setup
