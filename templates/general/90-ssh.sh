# Allow SSH from anywhere on standard port
$IPT -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow application management port — whitelist only
$IPT -A INPUT -m set --match-set $APP_SET src -p tcp --dport $PORT_APP -j ACCEPT
