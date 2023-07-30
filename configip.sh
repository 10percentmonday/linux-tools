#!/bin/bash

#source /tmp/functions.sh
function die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; } 

shopt -s expand_aliases
alias sssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
alias sscp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
if [ $# -lt 3 ]; then
    die "$0 Usage: target-server ip/mask con-name ifname [gateway] [hwaddr] [domain name]"
fi

if [ -n "$1" ]; then
    server=$1
fi
if [ -n "$2" ]; then
    ip_addr_net=$2
    server_ip="${2%/*}"
    netmask_bi="${2#*/}"
    if ! [[ $netmask_bi =~ ^[0-9]+$ ]]; then
        die "Invalid netmask: $netmask_bi"
    fi
fi
if [ -n "$3" ]; then
    conname=$3
fi
if [ -n "$4" ]; then
    ifname=$4
fi
if [ -n "$5" ]; then
    gateway=$5
fi

if [ -n "$6" ]; then
    hwaddr=$6
fi

if [ -n "$7" ]; then
    domain=$7
fi

netmask_to_ip() {
    # Calculate the number of set bits in the netmask
    local bits=$(($1))
    
    # Convert the bits to IP format
    for ((i=0; i<4; i++)); do
        if ((bits >= 8)); then
            ip+="255"
            bits=$(($bits-8))
        elif ((bits > 0)); then
            ip+=$((256 - 2**(8-$bits)))
            bits=0
        else
            ip+="0"
        fi
        
        if ((i < 3)); then
            ip+="."
        fi
    done
    
    echo "$ip"
}

config_rhel_ip() {
    if nmcli con show "$conname" &>/dev/null; then
        nmcli con modify "$conname" ipv4.address "$ip_addr_net"    \
            ipv4.method manual 
    else
        nmcli con add "$conname" ifname "$ifname" type ethernet ip4 "$ip_addr_net" 
    fi
}

# Check OS distribution
ssh_command="grep -o '^ID=[a-zA-Z]*' /etc/os-release | cut -d'=' -f2"
os_id=$(sssh ${server} ${ssh_command} 2>&1)
if [ $? -ne 0 ]; then
    die "$os_id"
fi
if [[ "$os_id" == "rhel" ]]; then
    version_id=$(sssh ${server} "grep -o '^VERSION_ID=[0-9]*' /etc/os-release | cut -d'=' -f2")
    if [[ "$version_id" -lt 7 ]]; then
        die "RHEL version less than 7"
    fi
    result=sscp ~/tool/functions.sh ${server}:/tmp/ >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        die "$result"
    fi
    sssh ${server} 'bash -s' <<-EOF
        source /tmp/functions.sh 
        config_rhel_ip "$conname" "$ifname" "$ip_addr_net"
EOF
elif [[ "$os_id" == "sles" ]]; then
    echo "use sles command"
    netmask_ip=$(netmask_to_ip $netmask_bi)
    result=sscp ~/tool/functions.sh ${server}:/tmp/ >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        die "$result"
    fi
    sssh ${server} 'bash -s' <<-EOF
        source /tmp/functions.sh 
        config_sles_ip "$ifname" "$server_ip" "$netmask_ip" "$gateway" "$hwaddr" 
EOF
elif [[ "$os_id" == "ubuntu" ]]; then
    echo "use ubuntu command"
    netmask_ip=$(netmask_to_ip $netmask_bi)
    result=sscp ~/tool/functions.sh ${server}:/tmp/ >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        die "$result"
    fi
    sssh ${server} 'bash -s' <<-EOF
        source /tmp/functions.sh 
        config_sles_ip "$ifname" "$server_ip" "$netmask_ip" "$gateway" "$hwaddr" 
EOF
else
    die "OS neither RHEL nor SLES"
fi
