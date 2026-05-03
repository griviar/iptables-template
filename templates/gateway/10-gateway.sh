# Requires in user/.env:  LAN1=eth1  and  LAN1_IP_RANGE=10.1.3.0/24
: "${LAN1:?LAN1 is not set — add to user/.env for gateway tag (e.g. export LAN1=eth1)}"
: "${LAN1_IP_RANGE:?LAN1_IP_RANGE is not set — add to user/.env for gateway tag (e.g. export LAN1_IP_RANGE=10.0.0.0/24)}"

# Allow traffic from/to LAN interface
$IPT -A INPUT  -i $LAN1 -j ACCEPT
$IPT -A OUTPUT -o $LAN1 -j ACCEPT

# Allow LAN → WAN forwarding; block direct WAN → LAN
$IPT -A FORWARD -i $LAN1 -o $WAN -j ACCEPT
$IPT -A FORWARD -i $WAN  -o $LAN1 -j REJECT
$IPT -A FORWARD -p all -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# NAT masquerade for LAN traffic going out through WAN
$IPT -t nat -A POSTROUTING -o $WAN -s $LAN1_IP_RANGE -j MASQUERADE
