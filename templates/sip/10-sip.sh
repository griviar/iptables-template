# SIP signaling
$IPT -A INPUT -p udp --dport 5060 -j ACCEPT
$IPT -A INPUT -p tcp --dport 5060 -j ACCEPT

# RTP media streams
$IPT -A INPUT -p udp --dport 10000:15000 -j ACCEPT
