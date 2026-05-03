# Log and drop all remaining traffic (list 'logging' LAST in .tag)
$IPT -N block_in
$IPT -N block_out
$IPT -N block_fw

$IPT -A INPUT   -j block_in
$IPT -A OUTPUT  -j block_out
$IPT -A FORWARD -j block_fw

$IPT -A block_in  -j LOG --log-level info --log-prefix "IPT-IN-DROP: "
$IPT -A block_in  -j DROP
$IPT -A block_out -j LOG --log-level info --log-prefix "IPT-OUT-DROP: "
$IPT -A block_out -j DROP
$IPT -A block_fw  -j LOG --log-level info --log-prefix "IPT-FW-DROP: "
$IPT -A block_fw  -j DROP
