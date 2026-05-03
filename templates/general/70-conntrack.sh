# Allow all outgoing traffic initiated by this server
$IPT -A OUTPUT -o $WAN -j ACCEPT

# Allow responses to established connections
$IPT -A INPUT  -p all -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -p all -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
