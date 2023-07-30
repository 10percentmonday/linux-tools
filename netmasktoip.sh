#!/bin/bash

netmask_to_ip() {
    local netmask=$1
    local ip=""
    
    # Validate the netmask value
    if ! [[ $netmask =~ ^[0-9]+$ ]]; then
        echo "Invalid netmask: $netmask"
        return 1
    fi
    
    # Calculate the number of set bits in the netmask
    local bits=$(($netmask))
    
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

# Usage example
converted=$(netmask_to_ip "$1")
echo "Netmask $1 in IP format: $converted"