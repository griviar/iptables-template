# Allow DNS queries (authoritative server)
$IPT -A INPUT -i $WAN -p udp --dport 53 -j ACCEPT
$IPT -A INPUT -i $WAN -p tcp --dport 53 -j ACCEPT
