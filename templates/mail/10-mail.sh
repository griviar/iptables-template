# SMTP / SMTPS
$IPT -A INPUT -p tcp --dport 25  -j ACCEPT
$IPT -A INPUT -p tcp --dport 465 -j ACCEPT

# POP3 / POP3S
$IPT -A INPUT -p tcp --dport 110 -j ACCEPT
$IPT -A INPUT -p tcp --dport 995 -j ACCEPT

# IMAP / IMAPS
$IPT -A INPUT -p tcp --dport 143 -j ACCEPT
$IPT -A INPUT -p tcp --dport 993 -j ACCEPT
