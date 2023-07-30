#!/bin/bash

function die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
function display_usage() {
    echo "Usage: $0 [-l <lv_name>] [-v <vg_name>] [-s <server_name>]"
    exit 1
}
shopt -s expand_aliases
alias sssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'

while getopts "s:v:l:" opt; do
    case $opt in
        l) lv_name=$OPTARG ;;
        v) vg_name=$OPTARG ;;
        s) server_name=$OPTARG ;;
        \?) echo "Invalid option: -$OPTARG" >&2; display_usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; display_usage ;;
    esac
done

if [[ -z "$lv_name" || -z "$vg_name" || -z "$server_name" ]]; then
    die "Missing required options. Usage: $0 -l <lv_name> -v <vg_name>"
fi

#ssh_cmd="sudo /sbin/vgdisplay $vg_name &>/dev/null && sudo /sbin/lvdisplay $vg_name/$lv_name &>/dev/null"
#if sssh ${server_name} "${ssh_cmd}"; then
#    die "vg or lv not existing on target host"
#fi

inventory_content=$(cat <<EOF
all:
    hosts:
        ${server_name}:
EOF
)
inventory_file="./extendlv_inventory.yml"
echo "$inventory_content" > "$inventory_file"

ansible-playbook -i "$inventory_file" extendlv.yml -e "server_name=$server_name vg=$vg_name lv=$lv_name"

rm "$inventory_file"
  