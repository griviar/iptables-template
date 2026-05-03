# Port forwarding examples — copy to user/custom.sh and uncomment as needed
#
# Forward TCP port 23543 on WAN to internal host 10.1.3.50:3389 (RDP):
# $IPT -t nat -A PREROUTING -i $WAN -p tcp --dport 23543 -j DNAT --to 10.1.3.50:3389
# $IPT -A FORWARD -i $WAN -d 10.1.3.50 -p tcp --dport 3389 -j ACCEPT
