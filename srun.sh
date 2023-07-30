#!/bin/bash
#Author:Daniel Kwok
#06/22/23

shopt -s expand_aliases
alias sssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
# Check if command is provided as the first argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [<server_file>]"
    exit 1
fi

# Extract the command name from the arguments
command_name=$1

# Set the default server file if not provided
server_file=${2:-"server_list.txt"}

#domain username and domain password used for copysshkey()
username="a127769_tr1"
domainpass='b|SB8M=hyV*milRQ?Z2Gu6POoJpY'

# Check if server_file exists and is readable
if [ ! -f "$server_file" ]; then
    echo "Server file not found: $server_file"
    exit 1
fi

# Read the server names from the file and execute the specified command on each server
#while read -r server_name; do
#    if [ -n "$server_name" ]; then
#        case $command_name in
#            "uptime")
#                echo $server_name
#                sssh "$server_name" "uptime"
#                ;;
#            "getos")
#                echo $server_name
#                getos $server_name
#                ;;
#            "validate")
#                echo $server_name
#                sssh "$server_name" "sudo /usr/local/sbin/validate_server.sh"
#                ;;
#            *)
#                echo "Invalid command: $command_name"
#                ;;
#        esac
#    fi
#done < "$server_file"
getos () {
        local server=${1//[^a-zA-Z0-9.-]}
        if [[ -z "$server" ]]
        then
                echo "Usage: getos [ hostname ]"
                echo "Purpose: ssh to server and report hostname, OS, and kernel"
                echo "Example:"
                echo -e "  server> getos SOME_SERVER\n"
        else
                ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR ${server} 'hostname -f | sed "s/$/,$(cat /var/cache/pe_patch/patch_group 2>/dev/null || echo UNKNOWN),$(test -e /opt/puppetlabs/bin/facter && echo "$(/opt/puppetlabs/bin/facter os.name) $(/opt/puppetlabs/bin/facter os.release.full)" || echo "$(lsb_release -sir)"),$(uname -r)/"'
        fi
}

islatestkernel () {
    local server=${1//[^a-zA-Z0-9.-]}
    if [[ -n "$server" ]]
    then
        running_kernel=$(sssh "$server" "uname -r" 2>&1)
        latest_kernel=$(sssh "$server" "ls -1 /lib/modules | sort --version-sort | tail -1" 2>&1)

        if [ "$running_kernel" = "$latest_kernel" ]; then
            echo "System is running with the newest kernel: $running_kernel"
        else
            echo "System is not running with the newest kernel."
            echo "Latest installed kernel: $latest_kernel"
            echo "Running kernel: $running_kernel"
        fi
    fi
}
copysshkey () {
    local server=${1//[^a-zA-Z0-9.-]}
    if [[ -n "$server" ]]
    then
        sshpass -p "$domainpass" ssh-copy-id "$username"@"$server"
    fi
}

for server_name in $(cat "$server_file"); do
   case $command_name in
       "uptime")
           echo "$server_name"
           sssh "$server_name" "uptime"
           ;;
       "getos")
           echo "$server_name"
           getos "$server_name"
           ;;
       "validate")
           echo "$server_name"
           sssh "$server_name" "sudo /usr/local/sbin/validate_server.sh"
           ;;
       "top")
           echo "$server_name"
           sssh "$server_name" "top -b -n 1 | head -n 17"
           ;;
        "kernel")
           echo "$server_name"
           islatestkernel "$server_name"
           ;;
        "sshkey")
           echo "$server_name"
           copysshkey "$server_name"
           ;;
       *)
           echo "Invalid command: $command_name"
           ;;
   esac
done