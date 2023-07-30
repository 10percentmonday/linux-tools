#!/usr/bin/env bash
#Daniel Kwok 06/04/2023

function die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
read -p "Enter your username: " username
read -sp "Enter your password: " password
echo

dnssearch()
{
    echo "Search HOST record:"
    ifip $1 || curl -k -u "$username":"$password" -X GET "https://infoblox.myabcit.net/wapi/v2.7.3/record:host?name=$1"
    echo
    echo "Search A record:"
    ifip $1 || curl -k -u "$username":"$password" -X GET "https://infoblox.myabcit.net/wapi/v2.7.3/record:a?name=$1"
    echo
    echo "Search CNAME record:"
    ifip $1 || curl -k -u "$username":"$password" -X GET "https://infoblox.myabcit.net/wapi/v2.7.3/record:cname?name=$1"
    echo
    echo "Search TXT record:"
    ifip $1 || curl -k -u "$username":"$password" -X GET "https://infoblox.myabcit.net/wapi/v2.7.3/record:txt?name=$1"
    echo
    echo "Search PTR record:"
    curl -k -u "$username":"$password" -X GET "https://infoblox.myabcit.net/wapi/v2.7.3/record:ptr?name=$1"
    echo
}
ifip()
{
    if [[ \$1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0 
    else
        return 1
    fi
}

if [ $# -ge 1 ]; then
    for arg in "$@"; do
        echo "--------------------------$arg----------------------------"
        dnssearch $arg
    done
else
    namelist="/home/a127769_tr1/tool/svrlist.txt"
    for name in $(cat "$namelist"); do
        echo "--------------------------$name----------------------------"
        dnssearch $name
    done
fi
