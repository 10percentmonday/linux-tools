config_sles_ip() {
    # Prepare the network configuration file path
    local config_file="/etc/sysconfig/network/ifcfg-$1"

    # Check if the configuration file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Network configuration file $config_file not found. Creating a new one"

        sudo -E config_file=$config_file \
                ifname=$1  \
                server_ip=$2 \
                netmask_ip=$3  \
                gateway=$4    \
                hwaddr=$5  \
            bash -c '
                echo "BOOTPROTO=static" > "$config_file"
                echo "NAME=$ifname" >> "$config_file"
                echo "DEVICE=$ifname" >> "$config_file"
                echo "ONBOOT=yes" >> "$config_file"
                echo "IPADDR=$server_ip" >> "$config_file"
                echo "NETMASK=$netmask_ip" >> "$config_file"
                if [ -n "$gateway" ]; then
                    echo "GATEWAY=$gateway" >> "$config_file"
                fi
                if [ -n "$hwaddr" ]; then
                    echo "HWADDR=$hwaddr" >> "$config_file"
                fi
            '
    else
        echo "Network configuration file $config_file already exists, please manually change the file"
        #echo "Network configuration file $config_file already exists"
        ## Backup the original configuration file
        #sudo cp "$config_file" "$config_file.bak"
        ## Update the configuration file with static IP address settings
        #sudo -E config_file=$config_file \
        #        ifname=$ifname  \
        #        server_ip=$server_ip \
        #        netmask_ip=$netmask_ip  \
        #        gateway=$gateway    \
        #        hwaddr=$hwaddr  \
        #    bash -c '
        #        sed -i "s/^BOOTPROTO=.*/BOOTPROTO='static'/" "$config_file"
        #        sed -i "s/^IPADDR=.*/IPADDR='$server_ip'/" "$config_file"
        #        sed -i "s/^NETMASK=.*/NETMASK='$netmask_ip'/" "$config_file"
        #        sed -i "s/^GATEWAY=.*/GATEWAY='$gateway'/" "$config_file"
        #        if [ -n "$gatway" ]; then
        #            sed -i "s/^GATEWAY=.*/GATEWAY='$gateway'/" "$config_file"
        #        fi
        #        if [ -n "$hwaddr" ]; then
        #            sed -i "s/^HWADDR=.*/HWADDR='$hwaddr'/" "$config_file"
        #        fi
        #    '
    fi

    echo "Static IP address configured for interface $1."
    echo "Please restart the network service for the changes to take effect."
}

config_rhel_ip() {
    conname=$1
    ifname=$2
    ip_addr_net=$3

    if sudo nmcli con show "$conname" &>/dev/null; then
        sudo nmcli con modify "$conname" ipv4.address "$ip_addr_net"    \
            ipv4.method manual 
    else
        sudo nmcli con add "$conname" ifname "$ifname" type ethernet ip4 "$ip_addr_net" 
    fi
}