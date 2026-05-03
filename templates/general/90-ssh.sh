# Allow SSH from anywhere on standard port
$IPT -A INPUT -p tcp --dport 22 -j ACCEPT
