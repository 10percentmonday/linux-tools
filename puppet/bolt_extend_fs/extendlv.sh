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

if ! sssh $server_name "sudo /sbin/vgs $vg_name >/dev/null 2>&1"; then
    die "Volume group ${vg_name} does not exist." 
fi

if ! sssh $server_name "sudo /sbin/lvs ${vg_name}/${lv_name} >/dev/null 2>&1"; then
    die "Logical volume '$vg_name/$lv_name' does not exist."
fi

# Get the free space of the VG in bytes
#free_space=$(sssh ${server_name} "sudo /sbin/vgs --noheadings -o vg_free --units g $vg_name | awk '{print \$1}' | tr -d 'g'")
#echo "$vg_name has free space: '$free_space'GB"
#fs_type=$(sssh $server_name "/usr/sbin/blkid -o value -s TYPE /dev/$vg_name/$lv_name")
#echo "$lv_name has volume type: $fs_type"

ssh_command="sudo /sbin/vgs --noheadings -o vg_free --units g $vg_name | awk '{print \$1}' | tr -d 'g'; /usr/sbin/blkid -o value -s TYPE /dev/$vg_name/$lv_name"

result=$(sssh ${server_name} "$ssh_command")

# Separate the output
free_space=$(echo "$result" | awk 'NR==1')
fs_type=$(echo "$result" | awk 'NR==2')

echo "VG[$vg_name] free space: '$free_space'GB"
echo "LV[$lv_name] filesystem type: $fs_type"

#export FACTER_vg_name="$vg_name"
#export FACTER_lv_name="$lv_name"
#export FACTER_fs_type="$fs_type"

# Define the minimum required free space in bytes (1GB in this case)
min_free_space=1

cat << EOF > ./custom_facts.json
{
    "lv_name": "$lv_name",
    "vg_name": "$vg_name",
    "fs_type": "$fs_type"
}
EOF

# Check if free space is larger than the minimum required
if [ ${free_space%.*} -gt "$min_free_space" ]; then
  echo "VG[$vg_name] free space is larger than 1GB. Proceeding with LV[$lv_name] extension..."
  
  # Use Puppet Bolt to run a manifest to increase the LV size
  #bolt_command="bolt apply -t $server_name -e 'include extend_lv' --modulepath /home/a127769_tr1/tool/puppet/mylvm/manifests --noop -l debug"
  #bolt_command="bolt apply manifests/extendlv.pp -t $server_name --noop -l debug"
  # bolt_command="bolt apply manifests/extendlv.pp -t $server_name --noop"
  # eval $bolt_command
  bolt apply manifests/bolt_extend_fs.pp -t $server_name --log-level info
  #bolt task run mytask --params "{\"param1\":\"$var1\", \"param2\":\"$var2\", \"param3\":\"$var3\"}" --nodes <node>
  
  # Check if the manifest execution was successful
  [ $? -ne 0 ] && die "Puppet bolt failed to extend LV" 
  echo "LV and FS size extension successful"
else
  die "VG[$vg_name] free space is less than 1GB. Extend VG[$vg_name] first" 
fi
