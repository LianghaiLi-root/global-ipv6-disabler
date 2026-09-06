#!/system/bin/sh
# ============================================================
#  Global IPv6 Disabler/Enabler  (with toggle switch)
#
#   Module folder:  /data/adb/modules/global_ipv6_off/
#   Toggle file:    <module>/toggle
#       1 (default)  -> DISABLE IPv6 globally (recommend default)
#       0            -> ENABLE  IPv6 globally  (re-enable)
#
#   Change the switch instantly:
#       echo 1 > <module>/toggle   (disable)
#       echo 0 > <module>/toggle   (enable)
#
#   Runs once at boot, then spawns a resident guard (ipv6_guard.sh)
#   that keeps the chosen state applied at runtime (the kernel/netd
#   may otherwise reset disable_ipv6 to 0 later, re-enabling IPv6).
# ============================================================
MODDIR=${0%/*}
TOGGLE_FILE="$MODDIR/toggle"
GUARD="$MODDIR/ipv6_guard.sh"

# default = 1 (disable)
TOGGLE=1
[ -f "$TOGGLE_FILE" ] && TOGGLE=$(cat "$TOGGLE_FILE" 2>/dev/null | tr -d '[:space:]')
[ -z "$TOGGLE" ] && TOGGLE=1

# ========== dis/enable helper ==========
set_all() { # $1 = 0|1
    for iface in /proc/sys/net/ipv6/conf/*/; do
        echo "$1" > "${iface}disable_ipv6"    2>/dev/null
        echo "$1" > "${iface}disable_ra"       2>/dev/null
        echo "$1" > "${iface}disable_policy"  2>/dev/null
    done
    echo "$1" > /proc/sys/net/ipv6/conf/all/disable_ipv6      2>/dev/null
    echo "$1" > /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null
}

# ========== apply one-shot state per toggle ==========
if [ "$TOGGLE" = "0" ]; then
    # re-enable ipv6 stack + acceptance on every interface
    set_all 0
    echo "IPv6 toggle=0 -> IPv6 ENABLED"
else
    # disable (default)
    set_all 1
    # flush live global ipv6 addrs
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        ip -6 addr flush dev "$iface" scope global 2>/dev/null
    done
    echo "IPv6 toggle=$TOGGLE -> IPv6 DISABLED"
fi

# ========== start resident guard (idempotent) ==========
# The guard always runs and re-reads toggle each loop, so it reacts to
# runtime state changes (action.sh / toggle file edits) without a reboot.
if [ -f "$GUARD" ] && [ ! -x "$GUARD" ]; then
    chmod 755 "$GUARD" 2>/dev/null
fi
if [ -x "$GUARD" ] && ! pgrep -f "ipv6_guard.sh" >/dev/null 2>&1; then
    nohup "$GUARD" >/dev/null 2>&1 &
fi

exit 0