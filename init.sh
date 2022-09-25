echo "Uname info: $(uname -a)"
# Check for wireguard module
ip link del dev test 2>/dev/null
if ip link add dev test type wireguard; then
  echo "**** It seems the wireguard module is already active. ****"
  ip link del dev test
else
  echo "**** The wireguard module is not active. Please mount it using volumes. Exiting ****"
  exit 1
fi

# If the LOCAL_NETWORK var is set -> register network related informations
if [[ -n "${LOCAL_NETWORK-}" ]]; then
  read -r gw dev <<<$(/sbin/ip route list match 0.0.0.0 | awk '{ print $3,$5 }')
  echo "adding route to local network ${LOCAL_NETWORK} via ${gw} dev ${dev}"
  /sbin/ip route add "${LOCAL_NETWORK}" via "${gw}" dev "${dev}"
fi

# Prepare symlinks
rm -rf /etc/wireguard
mkdir -p /etc/wireguard
ln -s /config/wg0.conf /etc/wireguard/wg0.conf

if [ ! -f /config/wg0.conf ]; then
  echo "**** No client conf found. Provide your own client conf as \"/config/wg0.conf\" and restart the container. ****"
  exit 1
fi

# iptables
# Allow ONLY traffic through WireGuard's interface (wg0) and to/from LAN
vpn_server_ip=$(sed -n 's/Endpoint = \(.*\):.*/\1/p' /etc/wireguard/wg0.conf)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i wg0 -j ACCEPT
iptables -A INPUT -s ${vpn_server_ip}/32 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -s ${vpn_server_ip}/32 -j ACCEPT
iptables -A FORWARD -d ${vpn_server_ip}/32 -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o wg0 -j ACCEPT
iptables -A OUTPUT -d ${vpn_server_ip}/32 -j ACCEPT

if [[ -n "${LOCAL_NETWORK-}" ]]; then
  iptables -A INPUT -s ${LOCAL_NETWORK} -j ACCEPT
  iptables -A FORWARD -s ${LOCAL_NETWORK} -j ACCEPT
  iptables -A FORWARD -d ${LOCAL_NETWORK} -j ACCEPT
  iptables -A OUTPUT -d ${LOCAL_NETWORK} -j ACCEPT
fi

# WireGuard
_term() {
  echo "Caught SIGTERM signal!"
  bash /app/wireguard-tools/wg-quick down wg0
}

trap _term SIGTERM

/app/wireguard-tools/wg-quick up wg0

sleep infinity &

wait
