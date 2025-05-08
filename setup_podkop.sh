#!/bin/sh

PODKOP_CONF="/etc/config/podkop"
REFERENCE_CONF="/tmp/podkop_reference_check"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31m❌ This script must be run as root.\033[0m"
    exit 1
fi

# Define the expected config (reference)
cat <<'EOF' > "$REFERENCE_CONF"
config main 'main'
	option mode 'proxy'
	#option interface ''
	option proxy_config_type 'url'
	#option outbound_json ''
	option proxy_string ''
	option domain_list_enabled '1'
	list domain_list 'russia_inside'
	option subnets_list_enabled '0'
	option custom_domains_list_type 'disabled'
	#list custom_domains ''
	#option custom_domains_text ''
	option custom_local_domains_list_enabled '0'
	#list custom_local_domains ''
	option custom_download_domains_list_enabled '0'
	#list custom_download_domains ''
	option custom_domains_list_type 'disable'
	#list custom_subnets ''
	#custom_subnets_text ''
	option custom_download_subnets_list_enabled '0'
	#list custom_download_subnets ''
	option all_traffic_from_ip_enabled '0'
	#list all_traffic_ip ''
	option delist_domains_enabled '0'
	#list delist_domains ''
	option exclude_from_ip_enabled '0'
	#list exclude_traffic_ip ''
	option yacd '0'
	option socks5 '0'
	option exclude_ntp '0'
	option quic_disable '0'
	option dont_touch_dhcp '0'
	option update_interval '1d'
	option dns_type 'doh'
	option dns_server '8.8.8.8'
	option dns_rewrite_ttl '60'
	option cache_file '/tmp/cache.db'
	list iface 'br-lan'
	option mon_restart_ifaces '0'
	#list restart_ifaces 'wan'
	option ss_uot '0'
        option detour '0'
EOF

# Compare current config to reference
if ! cmp -s <(grep -v '^\s*#' "$PODKOP_CONF" | grep -v '^\s*$') <(grep -v '^\s*#' "$REFERENCE_CONF" | grep -v '^\s*$'); then
    echo -e "\033[0;33m⚠️  The current /etc/config/podkop file does not match the expected default configuration.\033[0m"
    echo -e "\033[0;31m❌ Aborting script to prevent unintended changes.\033[0m"
    rm -f "$REFERENCE_CONF"
    exit 1
fi

rm -f "$REFERENCE_CONF"
echo -e "\033[0;32m✅ podkop configuration verified. Proceeding...\033[0m"

# 1. Clear the existing configuration
echo -e "\033[0;32mClearing existing configuration...\033[0m"
> "$PODKOP_CONF"

# 2. Ask the user for the VLESS link for the main connection (with validation)
while true; do
    echo -e "\033[0;32mEnter the VLESS link for the main connection (main):\033[0m"
    read VLESS_MAIN
    if [[ $VLESS_MAIN =~ ^vless:// ]]; then
        break
    else
        echo -e "\033[0;31m❌ The link must start with 'vless://'. Please enter it again.\033[0m"
    fi
done

# 3. Ask the user for the VLESS links for YouTube (yt) (with validation for each link)
YT_LINKS=""
while true; do
    echo -e "\033[0;32mEnter VLESS links for YouTube (yt) — separate links with spaces or new lines (for multiple links):\033[0m"
    read -r YT_INPUT

    # Check if each link starts with 'vless://'
    valid=true
    for link in $YT_INPUT; do
        if [[ ! $link =~ ^vless:// ]]; then
            valid=false
            break
        fi
    done

    if $valid; then
        YT_LINKS="$YT_INPUT"
        break
    else
        echo -e "\033[0;31m❌ All YouTube links must start with 'vless://'. Please enter them again.\033[0m"
    fi
done

# 4. Write the new configuration
echo -e "\033[0;32mWriting new configuration...\033[0m"
cat <<EOF > "$PODKOP_CONF"

config main 'main'
	option mode 'proxy'
	option proxy_config_type 'url'
	option domain_list_enabled '1'
	option subnets_list_enabled '0'
	option custom_domains_list_type 'disabled'
	option custom_local_domains_list_enabled '0'
	option custom_download_domains_list_enabled '0'
	option custom_download_subnets_list_enabled '0'
	option all_traffic_from_ip_enabled '0'
	option delist_domains_enabled '0'
	option exclude_from_ip_enabled '0'
	option yacd '0'
	option socks5 '0'
	option exclude_ntp '0'
	option quic_disable '0'
	option dont_touch_dhcp '0'
	option update_interval '1d'
	option dns_type 'doh'
	option dns_server 'dns.adguard-dns.com'
	option dns_rewrite_ttl '60'
	option cache_file '/tmp/cache.db'
	list iface 'br-lan'
	option proxy_string '$VLESS_MAIN'
	option custom_subnets_list_enabled 'disabled'
	option ss_uot '0'
	list domain_list 'geoblock'
	list domain_list 'block'
	list domain_list 'discord'
	list domain_list 'meta'
	list domain_list 'twitter'
	list domain_list 'tiktok'

config extra 'yt'
	option mode 'proxy'
	option proxy_config_type 'url'
	option proxy_string '$YT_LINKS'
	option domain_list_enabled '1'
	list domain_list 'youtube'
	option custom_domains_list_type 'disabled'
	option custom_local_domains_list_enabled '0'
	option custom_download_domains_list_enabled '0'
	option custom_subnets_list_enabled 'disabled'
	option custom_download_subnets_list_enabled '0'
	option all_traffic_from_ip_enabled '0'

EOF

# 5. Check if the new configuration was written
if [ ! -s "$PODKOP_CONF" ]; then
    echo -e "\033[0;31m❌ Failed to write the new configuration to $PODKOP_CONF.\033[0m"
    exit 1
fi

# 6. Restart the service
echo -e "\033[0;32mRestarting podkop service...\033[0m"
service podkop restart

echo -e "\033[0;32m✅ The podkop configuration has been updated and the service restarted.\033[0m"
