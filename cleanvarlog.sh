#!/usr/bin/env bash
#Daniel Kwok 06/03/2023

function die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[[ $# -lt 1 ]] && die 'Usage: $0 target-server-name [topN] [del]'
server=$1
toplist=${2:-10}
host $server > /dev/null 2>&1 || die "${server} not recogonized by DNS"

ping -c 1 $server > /dev/null 2>&1 || die "${server} failed to ping"

shopt -s expand_aliases
alias sssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
alias sscp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'

echo "List top $toplist directories or files under /var sorted by size"
sssh ${server} "sudo du -hs /var/* 2>/dev/null | sort -rh | head -n ${toplist}"

echo "List top $toplist files under /var sorted by file size"
sssh ${server} "sudo find /var -type f -exec du -hs {} + 2>/dev/null | sort -rh | head -n $toplist"
echo -e "\n/var size before cleanup"
sssh $server "df -h /var"

if [ "$3" == "del" ]; then
    #sssh ${server} "sudo find /var/log -not -path '*/puppetlabs/*' -type f -name '*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].xz' | xargs rm"
    sssh ${server} "sudo find /home/a127769_tr1/test -not -path '*/puppetlabs/*' -type f -name '*.txt' | xargs rm"
    echo -e "\nAll archived log files are cleaned - puppetlabs excluded"
else
    echo -e "List archived log files"
    #sssh $server "sudo find /var/log -not -path '*/puppetlabs/*' -type f -name '*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9].xz'  | xargs -I {} echo {}"
    sssh $server "sudo find /home/a127769_tr1/test -not -path '*/puppetlabs/*' -type f -name '*.txt'  | xargs echo"
fi

echo -e "\n/var size after cleanup"
sssh $server "df -h /var"

