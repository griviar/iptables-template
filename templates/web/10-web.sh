# Allow HTTP and HTTPS
$IPT -A INPUT -p tcp --dport 80  -j ACCEPT
$IPT -A INPUT -p tcp --dport 443 -j ACCEPT
