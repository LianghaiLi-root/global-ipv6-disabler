#!/system/bin/sh
# ============================================================
#  Global IPv6 Disabler/Enabler  -  resident daemon
#  (ipv6_guard.sh)
#
#  Purpose:
#    The kernel/system networking layer may reset an interface's
#    disable_ipv6=0 at runtime (WiFi reconnect, data switch,
#    virtual iface (vgate/wondertap/ovnet...) (re)creation, etc.).
#    The original module only applied the setting once at boot,
#    so IPv6 can silently "come back" later. This daemon keeps
#    re-applying the desired state so IPv6 stays off.
#
#  Behavior (reads toggle every loop):
#    toggle = 1 (default) -> force IPv6 OFF on every interface
#    toggle = 0           -> remain silent (IPv6 allowed)
#  It therefore reacts to the toggle change live and never fights
#  an explicit "enable" choice made via action.sh / toggle file.
#
#  Installed & auto-started from service.sh.
# ============================================================

MODDIR=${0%/*}
TOGGLE_FILE="$MODDIR/toggle"
LOG="/data/local/tmp/ipv6_guard.log"

# short normalisation loop counter guard to keep log bounded
flushed=""

# bounds the log so it never grows unbounded over weeks of runtime
log_line() {
    : >> "$LOG" 2>/dev/null
    if [ "$(wc -c < "$LOG" 2>/dev/null)" -gt 262144 ]; then
        : > "$LOG" 2>/dev/null   # 256 KB cap -> keep newest events rolling
    fi
    echo "$1" >> "$LOG" 2>/dev/null
}

write_all_disable() {
    for iface in /proc/sys/net/ipv6/conf/*/; do
        [ -f "$iface/disable_ipv6" ] && echo 1 > "$iface/disable_ipv6" 2>/dev/null
        [ -f "$iface/disable_ra" ]    && echo 1 > "$iface/disable_ra"    2>/dev/null
        [ -f "$iface/disable_policy" ]&& echo 1 > "$iface/disable_policy" 2>/dev/null
    done
    [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]     && echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null
    [ -f /proc/sys/net/ipv6/conf/default/disable_ipv6 ] && echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null
    # drop any global ipv6 addresses that reappeared
    for i in $(ls /sys/class/net/ 2>/dev/null); do
        ip -6 addr flush dev "$i" scope global 2>/dev/null
    done
}

: > "$LOG" 2>/dev/null
log_line "guard start $(date '+%F %T')"

while :; do
    TOGGLE=$(cat "$TOGGLE_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -z "$TOGGLE" ]; then TOGGLE=1; fi

    if [ "$TOGGLE" = "0" ]; then
        # user wants IPv6 ON -> stay out of the way
        sleep 3
        continue
    fi

    # toggle=1 : force-disable IPV6. Find any iface that slipped to 0.
    reapply=0
    for iface in /proc/sys/net/ipv6/conf/*/; do
        v=$(cat "$iface/disable_ipv6" 2>/dev/null)
        if [ "$v" = "0" ]; then
            reapply=1
            break
        fi
    done

    if [ "$reapply" = "1" ]; then
        write_all_disable
        log_line "[$(date '+%F %T')] ipv6 slipped to 0 -> re-disabled"
    fi

    sleep 2
done