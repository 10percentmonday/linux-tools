#!/usr/bin/env bash
# ==========================================================================================================
#     name: validate_server.sh
#   author: Jake Rogers <jacob.rogers@amerisourcebergen.com>
#  purpose: This script will validate linux server health
# ==========================================================================================================
LANG='en_US.UTF-8'                                                                       # set language in order to
LC_NUMERIC='en_US.UTF-8'                                                                 # avoid formatting problems
LC_TIME='en_US.UTF-8'                                                                    # set time format
server=$(hostname | tr '[A-Z]' '[a-z]' | cut -d. -f1)                                    # get lowercase short hostname
datacenter=''
vcs_check='n/a'

show_help() {
  cat <<HELP_MSG
This script can be used to validate server health for local file systems, nfs mounts, IP addresses, and VCS.
It can help with validating server health following patching, outages, or DR events.

Usage: validate_server.sh [-h|-?|--help] [-d|--dr]

-h, -?, --help   show this help message
-d, --dr         perform disaster recovery IP and NFS mount validation

HELP_MSG
}

# assume PROD site by default
site=''
while :; do
  case $1 in
    -h|-\?|--help)
      show_help; exit ;;                                                                 # display a usage synopsis.
    -d|--dr)
      site='_dr' ;;                                                                      # perform DR site validation
    --)                                                                                  # end of all options.
      shift; break ;;
    -?*)
      printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2 ;;
    *)                                                                                   # no more options, so break
      break
  esac
  shift
done


# validate local and nfs mounts by comparing counts between fstab and what is actually mounted
mnt_local_fstab=$(egrep -c '^[/a-zA-Z].*\s(ext[3,4]|v?xfs)\s' /etc/fstab)                # count local file systems in fstab
mnt_local=$(egrep -c '^[/a-zA-Z].*\s(ext[3,4]|v?xfs)\s' /proc/mounts)                    # count mounted local file systems
if [ "$site" == '_dr' ]; then                                                            # if dr validation check datacenter
  datacenter=$(/opt/puppetlabs/bin/facter -p datacenter | tr '[A-Z]' '[a-z]')            # use IP to determine current DC
  mnt_nfs_fstab=$(egrep -c "^${datacenter}[/a-zA-Z].*\s(nfs|none.*bind)\s" /etc/fstab)   # count NFS file systems in fstab
else
  mnt_nfs_fstab=$(egrep -c "^[/a-zA-Z].*\s(nfs|none.*bind)\s" /etc/fstab)                # count NFS file systems in fstab
fi
mnt_nfs=$(egrep -c '^[/a-zA-Z].*\s(nfs|none.*bind)\s' /proc/mounts)                      # count mounted NFS file systesms
[ "$mnt_local_fstab" -eq "$mnt_local" ] && mnt_local_check='pass' || mnt_local_check='FAIL'
[ "$mnt_nfs_fstab" -eq "$mnt_nfs" ] && mnt_nfs_check='pass' || mnt_nfs_check='FAIL'


# validate IP addresses by looping over current IPs and comparing to hostnames in dns
all_ips=($(/?bin/ip -4 -o a|grep -v '\slo\s'|tr -s ' '|cut -d' ' -f4|cut -d'/' -f1))     # put all assigned IPs in array
for ipaddr in "${all_ips[@]}"; do
  egrep -q '^(192|10\.254)' <<<"$ipaddr" && continue                                     # skip backup and replication networks
  reverse=$(dig +search +short -x "$ipaddr" | cut -d. -f1)                               # reverse lookup short hostname
  dns_ip=$(dig +search +short "${reverse}${site}")                                       # forward lookup short hostname
  [ "$ipaddr" != "$dns_ip" ] && ip_check='FAIL'                                          # if ipaddr != to dns_ip; FAIL
done
[ "$ip_check" != 'FAIL' ] && ip_check='pass'                                             # if ip_check != FAIL; PASS

if rpm -q VRTSvcs > /dev/null 2>&1; then                                                 # test if server has  VCS installed
  vcs_status=$(/opt/VRTSvcs/bin/hastatus -sum | grep -im1 "$server" | awk '{print $3}')  # get vcs status for this server
  [ "$vcs_status" == 'RUNNING' ] && vcs_check='pass' || vcs_check='FAIL'                 # test if VCS cluster is running
fi

if [ "$site" == '_dr' ]; then                                                            # if dr validation check datacenter
  headers='HOSTNAME,DC,LOCAL_FS,NFS,IPs,VCS'
  output="${server},${datacenter},${mnt_local_check},${mnt_nfs_check},${ip_check},${vcs_check}"
else
  headers='HOSTNAME,LOCAL_FS,NFS,IPs,VCS'
  output="${server},${mnt_local_check},${mnt_nfs_check},${ip_check},${vcs_check}"
fi

if /usr/bin/tty -s; then                                                                 # if script ran interactively
  echo -e "${headers}\n${output}" | column -s, -t                                        # output in columns with header
else                                                                                     # if script ran over ssh
  echo "$output"                                                                         # one-line csv output only
fi

exit 0
