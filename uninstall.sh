#!/system/bin/sh
# ============================================================
#  Global IPv6 Disabler - uninstall.sh
#  Runs before the module directory is removed.
#  1) stop the resident guard daemon
#  2) remove its log file
#  3) restore IPv6 on all interfaces (so no "half-off" state)
# ============================================================

# 1) kill the guard process (match script path to avoid hitting others)
for pid in $(ps -e -o pid,args 2>/dev/null | grep -F 'ipv6_guard.sh' | grep -v grep | awk '{print $1}'); do
  kill -9 "$pid" 2>/dev/null
done
# fallback: pkill by name if available
command -v pkill >/dev/null 2>&1 && pkill -f 'ipv6_guard.sh' 2>/dev/null

# 2) remove log
rm -f /data/local/tmp/ipv6_guard.log 2>/dev/null

# 3) restore IPv6 on every common interface
for iface in /proc/sys/net/ipv6/conf/*; do
  [ -d "$iface" ] || continue
  echo 0 > "$iface/disable_ipv6" 2>/dev/null
  echo 0 > "$iface/disable_ra" 2>/dev/null
  echo 0 > "$iface/disable_policy" 2>/dev/null
done

# all/default fallback
[ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null
[ -f /proc/sys/net/ipv6/conf/default/disable_ipv6 ] && echo 0 > /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null

exit 0
