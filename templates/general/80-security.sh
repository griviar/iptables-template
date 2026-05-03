# Drop invalid packets
$IPT -A INPUT -m conntrack --ctstate INVALID -j DROP

# Drop null packets (TCP with no flags set)
$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# SYN-flood protection
$IPT -A INPUT  -p tcp ! --syn -m state --state NEW -j DROP
$IPT -A OUTPUT -p tcp ! --syn -m state --state NEW -j DROP
