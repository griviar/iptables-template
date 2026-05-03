# Allow ICMP (ping and network diagnostics)
$IPT -A INPUT -p icmp --icmp-type echo-reply            -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type time-exceeded         -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type echo-request          -j ACCEPT
