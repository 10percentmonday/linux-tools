#!/usr/bin/env bash
# ==========================================================================================================
#     name: health_check
#   author: Jake Rogers <jacob.rogers@amerisourcebergen.com>
#  purpose: report on the health of OS services and configuration as well as checking for known issues
# requires: facter from puppet-agent
# ==========================================================================================================
[ "$EUID" -ne 0 ] && echo 'this script must be ran as root, exiting' && exit 1 # exit if script not ran as root

script_name='health_check'                                                     # define script name
script_version='2.5.2'                                                         # define script version
LANG='en_US.UTF-8'; LC_NUMERIC='en_US.UTF-8'; LC_TIME='en_US.UTF-8'            # explicitly set lang, number, & time format
umask 0022                                                                     # set umask for created files
log_dir="/sysadmin/reports"                                                    # set logfile directory
[ -d "$log_dir" ] || mkdir -pm 2750 "$log_dir"                                 # ensure log_dir exists
[ $(stat -c '%U' "$log_dir") = 'root' ] || chown -R root "$log_dir"            # ensure log dir owned by root
[ $(stat -c '%a' "$log_dir") = '2750' ] || chmod 2750 "$log_dir"               # ensure log dir perms are 2750
tty=$(tty | sed 's/\/dev\///')                                                 # get current TTY
ran_by=$(who | grep -i "$tty" | cut -d' ' -f1)                                 # who ran the script
date_rqst=$(date "+%F")                                                        # today's date in YYYY-MM-DD format
server=$(hostname | tr '[A-Z]' '[a-z]' | cut -d. -f1)                          # get lowercase short hostname
server_fqdn=$(hostname -f | tr '[A-Z]' '[a-z]')                                # get lowercase fqdn
domain=$(hostname -d | tr '[A-Z]' '[a-z]')                                     # get domain
kernel=$(uname -r)                                                             # get running kernel version
os=$(/opt/puppetlabs/bin/facter os.distro.description)                         # get os version
os_ver=$(/opt/puppetlabs/bin/facter os.release.full)                           # get os release version
platform=$(/opt/puppetlabs/bin/facter virtual)                                 # get hardware/virtual platform
log_file="${log_dir}/healthcheck-${server}"                                    # set logfile name
[ -e ${log_file} ] && mv ${log_file}{,.lastrun}                                # backup output of last run
issues=()                                                                      # init issues array
mnt_fstab=()                                                                   # init mount array
puppet_report=''; storage_report=''; vcs_report=''                             # init content var

#-FUNCTIONS--------------------------------------------------------------------#
function add_issue() { issues+=("$(printf '%s' "$1")"); }                      # add string to issues array
function die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }                      # print error message and exit

function validate_forward_dns {                                                # validate forward dns lookups
  local host_name=${1}
  local response=$(dig +search +short "${host_name}.${domain}")                # forward lookup
  if [ -z "$response" ]; then                                                  # check if empty
    if getent hosts "$host_name" > /dev/null; then                             # check for domain mismatch
      add_issue "${host_name} forward lookup found in wrong domain"            # raise error
    else                                                                       # else forward missing
      add_issue "${host_name} forward lookup missing"                          # raise error
    fi
  elif egrep -q '\\|/' <<<"$response"; then                                    # check for invalid response (\)
    add_issue "${host_name} forward lookup invalid"                            # raise error
  elif [ $(wc -l <<<"$response") -gt 1 ]; then                                 # check for multiple responses
    add_issue "${host_name} lookup returned more than one response"            # raise error
  else                                                                         # no errors found
    printf '%s\n' "$response"                                                  # print result
  fi
}
function validate_reverse_dns {                                                # validate reverse dns lookups
  local ip=${1}
  local response=$(dig +search +short -x "${ip}")                              # reverse lookup
  if [ -z "$response" ]; then                                                  # check if empty
    add_issue "${ip} reverse lookup missing"                                   # raise error
  elif egrep -q '\\|/' <<<"$response"; then                                    # check for invalid response (\)
    add_issue "${ip} reverse lookup invalid"                                   # raise error
  elif [ $(wc -l <<<"$response") -gt 1 ]; then                                 # check for multiple responses
    add_issue "${ip} returned more than one response"                          # raise error
  elif [[ "$response" =~ '_pri' ]]; then                                       # check for _pri
    add_issue "${ip} reverse lookup contains _pri"                             # raise error
  elif [[ "$response" =~ '_dr' ]]; then                                        # check for _dr
    add_issue "${ip} reverse lookup contains _dr"                              # raise error
  elif [ $(cut -d. -f2- <<<"$response") != "$domain" ]; then                   # check for domain mismatch
    add_issue "${ip} reverse lookup domain mismatch"                           # raise error
  else                                                                         # no errors found
    printf '%s\n' "$(cut -d. -f1 <<<"$response")"                              # print result
  fi
}

function title() {
  echo -e "   Script: ${script_name}\tVersion: ${script_version}"
  echo "-----------------------------------------------------------------------------"
}
function show_help() {
title;
cat << EOF
This script gather information about the system for the purpose of troubleshooting and RCA investigations.
It was designed to support redhat and suse linux servers and leverages facter from the puppet-agent package.

usage: ${script_name}.sh [-d|--date <YYYY-MM-DD>] [-e|--email <EMAIL_ADDRESS> ] [-h|--help]
  -d, --date    specify date other than today in YYYY-DD-MM format
  -e, --email   send script output to provided email address
  -h, --help    show this help message
EOF
}

# Initialize all the option variables. This ensures they are not contaminated by variables from the environment.
email='false'
while :; do
  case "${1:-default}" in
    -d|--date) 
      if [ "$2" ]; then
        if [[ "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$2" >/dev/null 2>&1; then
          date_rqst=$2
          shift
        else
          die '--date requires a valid date argument in YYYY-MM-DD format'
        fi
      else
        die '--date requires a non-empty option argument in YYYY-MM-DD format'
      fi ;;
    -e|--email)
      if [ "$2" ]; then
        if [[ "$2" =~ ^[a-zA-Z0-9._-]*@amerisourcebergen.com$ ]]; then
          email=$2
          shift
        else
          die '--email requires a valid *@amerisourcebergen.com email'
        fi
      else
        die '--email requires a non-empty option argument'
      fi ;;
    -h|-\?|--help)
      show_help
      exit
      ;;
    --)                                                                        # do NOT accept additional options
      shift
      break
      ;;
    -?*) printf 'ERROR: Unknown option (ignored): %s\n' "$1" >&2; exit 1;;
    *) break                                                                   # Default: No more options, break
  esac
  shift
done

# case statement for physical vs virtual servers
case "$platform" in
  physical)
    read -r -d '' platform_report <<PLATFORM_INFO
  Manufacturer: $(/usr/sbin/dmidecode -s system-manufacturer)
  Product Name: $(/usr/sbin/dmidecode -s system-product-name)
        Serial: $(/usr/sbin/dmidecode -s system-serial-number)

BIOS Information
        Vendor: $(/usr/sbin/dmidecode -s bios-vendor)
       Version: $(/usr/sbin/dmidecode -s bios-version)
  Release Date: $(/usr/sbin/dmidecode -s bios-release-date)
PLATFORM_INFO
    read -r -d '' storage_report <<STORAGE_INFO
**** WWPNs ****
$(grep . /sys/class/fc_host/host*/port_name)

**** HBA Firmware Versions ****
$(grep . /sys/class/scsi_host/host*/*_version | sort -t \/ -k6)

**** Multipath Status ****
$(/sbin/chkconfig --list boot.multipath 2> /dev/null;/sbin/chkconfig --list multipathd 2> /dev/null)
$(/etc/init.d/multipathd status)"
STORAGE_INFO
  ;;
  *)
    read -r -d '' platform_report <<PLATFORM_INFO
Virtualization: ${platform}
  $([ "$platform" = "vmware" ] && echo "VMware Tools: $(/usr/bin/vmware-toolbox-cmd --version)")
PLATFORM_INFO
  ;;
esac

#TODO nimsoft robot check: ps aux | grep nimbus | grep -v grep
# rhel5, sles11 and 12.1 do not support --brief option for ip command.
case "$os_ver" in
  5.*|11.*|12.1) ip_info=$(/?bin/ip -o a | grep -v ': lo' | sed 's/^[0-9]\+\:\s*//;s/\// \//' | cut -d '\' -f1 | column -t) ;;
              *) ip_info=$(echo -e "interface state address\n$(/?bin/ip --brief a | grep -v '^lo\s')" | column -t) ;;
esac

if rpm -q puppet-agent >/dev/null; then
  last_run=$(date -d@$(grep last_run /opt/puppetlabs/puppet/cache/state/last_run_summary.yaml | tr -d ' ' | cut -d: -f2) '+%F %T %Z')
  resources_out_of_sync=$(grep out_of_sync /opt/puppetlabs/puppet/cache/state/last_run_summary.yaml | tr -d ' ' | cut -d: -f2)
  read -r -d '' puppet_report <<EOF
**** Puppet Status ****
               Puppet Version: $(/opt/puppetlabs/bin/puppet -V)
          Puppet Code Version: $(grep 'config:' /opt/puppetlabs/puppet/cache/state/last_run_summary.yaml | tr -d ' ' | cut -d: -f2)
              Last Puppet Run: ${last_run}
  Resources Out of Compliance: ${resources_out_of_sync}

EOF
else
  add_issue 'puppet-agent is not installed'
fi

if rpm -q VRTSvcs > /dev/null; then
  # get vcs status for this server
  vcs_status=$(/opt/VRTSvcs/bin/hastatus -sum | grep -im1 "$server" | awk '{print $3}')
  # test if VCS cluster node is running
  [ "$vcs_status" == 'RUNNING' ] || add_issue 'Cluster node is not in a running state'
  read -r -d '' vcs_report <<EOF
\n**** Veritas Cluster Status ****
                   VCS Version: $(/opt/VRTSvcs/bin/haclus -value EngineVersion)
                Cluster Status: $(/opt/VRTSvcs/bin/hastatus -summary)

  Low Latency Transport Status:
$(/sbin/lltstat -vvn configured | grep -v information)
EOF
fi

[ -e /usr/sbin/ntpq ] && time_status=$(/usr/sbin/ntpq -p)                      # check time drift with ntpq
[ -e /usr/bin/chronyc ] && time_status=$(/usr/bin/chronyc sources)             # check time drift with chronyc

# validate local and nfs mounts by comparing fstab entries with /proc/mounts
mnt_fstab=($(egrep '^[/a-zA-Z].*\s(btrfs|ext[3,4]|v?xfs|vfat|nfs|none.*bind)\s' /etc/fstab | awk '{ print $2 }'))

for mnt in "${mnt_fstab[@]}"; do
  grep -q " ${mnt} " /proc/mounts && continue                                  # if mounted, skip
  mnt_dev=$(grep "^[/a-zA-Z].*\s${mnt}\s" /etc/fstab | awk '{ print $1 }')     # get mount point device name
  add_issue "${mnt_dev} not mounted to ${mnt}"
done

vas_status=$([ -e /opt/quest/bin/vastool ] && /opt/quest/bin/vastool status)   # get quest authentication status

#-BEGIN-BUILDING-HEALTH-CHECK-REPORT-------------------------------------------#
echo -e "\n... CREATING HEALTH CHECK v${script_version} REPORT ..."

read -r -d '' health_report <<BODY
*** ${server_fqdn} - Health Check v${script_version} ran by ${ran_by} on $(date +'%a %e %b %Y %r %Z') ***

System Information
          CPUs: $(/opt/puppetlabs/bin/facter processors.count)
        Memory: $(/usr/sbin/dmidecode -t 17 | grep 'Size.*\(M\|G\)B' | awk '{s+=$2} END {print s " " $3}')
            OS: ${os}
        Kernel: ${kernel}
        Uptime: $(/opt/puppetlabs/bin/facter system_uptime.uptime)
      App Tier: $(/opt/puppetlabs/bin/facter -p application_tier)
    Datacenter: $(/opt/puppetlabs/bin/facter -p datacenter)
         pySar: https://perfrpt.amerisourcebergen.com/pysar/byServer/${server%%\.*}/$(date "+%Y/%m/%d" -d "$date_rqst")/


Platform Information
${platform_report}


Networking Information
**** IP Addresses ****
${ip_info}

**** Routing Table ****
$(/?bin/ip route list)$([ -e /proc/net/bonding/ ] && { echo -e "\n**** Bond Health ****\n"; grep ".*" /proc/net/bonding/bond* | egrep "Mode|Active Sla|Interface|Status|ports" || echo 'no bonds found'; })


Storage Information
${storage_report}**** Volume Group Report ****
$({ /sbin/vgs 2>/dev/null || /usr/sbin/vgs 2>/dev/null; } | column -t)

**** Disk Free Report ****
$(df -lmPT -x devtmpfs -x tmpfs | sed 's/Mounted on/Mounted_on/' | column -t)

**** Disk Layout Report ****
$(lsblk -o NAME,FSTYPE,SCHED,SIZE,LABEL,MOUNTPOINT)


Miscellaneous Information
${puppet_report}
${vcs_report}

$([ -e /opt/quest/bin/vastool ] && echo -e "**** Quest AD Authentication Status ****\nOU:\t$(/opt/quest/bin/vastool -u host attrs host/${server} distinguishedName | cut -d':' -f2 | sed 's/^\s*//')\n${vas_status}")

**** Memory ****
$(free -m)

**** Time Drift from Source (Offset is in milliseconds) ****
${time_status}

**** Reboot History (last 10 lines of /var/log/bootlog) ****
$(tail -10 /var/log/bootlog 2>/dev/null)

**** Last 5 Users ****
$({ last -dwFn5 2>/dev/null || last -dwn5 2>/dev/null || last -dFn5 2>/dev/null || last -dn5 2>/dev/null; } | grep -v '^wtmp')
$([ $(ls -1 /var/crash | wc -l) -gt 0 ] && echo -e "\nKERNEL DUMPS FOUND:\n$(ls -1 /var/crash)")

BODY


#-CHECK-FOR-KNOWN-ISSUE--------------------------------------------------------#
echo -e "... CHECKING SERVER FOR KNOWN ISSUES ...\n"
/?bin/ip -6 -o a | grep -qv '^1: lo' && add_issue 'IPv6 should be disabled'    # check for ipv6
grep -q 'No tests failed' <<<"$vas_status" || add_issue 'quest failure detected'

#-CHECK-FILE-SYSTEM-FREE-SPACE-------------------------------------------------#
while read -r filesys size used avail cap mounted_on; do
  if [ $cap -gt 95 ]; then
    add_issue "$mounted_on is > 95% full and has only ${avail}Mb free"
  fi
done < <(df -mlP -x devtmpfs -x tmpfs | grep -v Filesystem | tr -s '[:blank:]' | tr -d '%')

#-CHECK-FOR-DNS-ISSUES----------------------------------------------------------#
# validate IP addresses by looping over current IPs and comparing to hostnames in dns
all_ips=($(/?bin/ip -4 -o a|grep -v '\slo\s'|tr -s ' '|cut -d' ' -f4|cut -d'/' -f1))
for ipaddr in "${all_ips[@]}"; do
  host_name=''; fwd_ip=''
  egrep -q '^(192|10\.254)' <<<"$ipaddr" && continue                           # skip backup and replication networks
  host_name=$(validate_reverse_dns "$ipaddr")
  fwd_ip=$([ -n "$host_name" ] && validate_forward_dns "$host_name")
  if [ -n "$fwd_ip" ]; then
    [ "$fwd_ip" != "$ipaddr" ] && add_issue "forward lookup for ${host_name} does not match reverse for ${fwd_ip}"
  fi
done

#-CHECK-FOR-VM-ISSUES----------------------------------------------------------#
# if vmware and tools not running, raise issue
[ "$platform" = 'vmware' ] && { ps -C vmtoolsd >/dev/null || add_issue 'vmware tools does not appear to be running'; }

#-CHECK-FOR-PUPPET-ISSUES------------------------------------------------------#
if rpm -q puppet-agent >/dev/null; then
  ps -C puppet >/dev/null || add_issue 'puppet agent service does not appear to be running, this will allow the configration to drift'
  ps -C pxp-agent >/dev/null || add_issue 'puppet pxp-agent service does not appear to be running, this will inhibit orchestration for PE console'
  [ $resources_out_of_sync -ne 0 ] && add_issue "last puppet run shows ${resources_out_of_sync} resources were out of compliance. Ensure puppet runs clean, w/ no modifications made"
fi

#-WRITE-KNOWN-ISSUES-TO-LOGFILE------------------------------------------------#
if [ ${#issues[@]} -gt 0 ]; then
  health_report+="\n\n**** KNOWN ISSUES: ${#issues[@]} ****\n"
  for issue in "${issues[@]}"; do health_report+=" -@- ${issue}\n"; done
fi

# send email if --email option was passed
[ $email != 'false' ]  && echo -e "$health_report" | mutt -s "[hc] ${server_fqdn} @ $(date '+%F %T')" "$email"


echo -e "$health_report" | tee -a "$log_file"
chmod 440 "$log_file"
echo -e "\nHealth Check Report Created: ${log_file/.\/}\n";

exit 0
