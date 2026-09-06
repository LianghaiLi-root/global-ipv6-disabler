#!/system/bin/sh
# ============================================================
#  Global IPv6 Control  -  action.sh
#  Provides the module "action" (>) entry (KernelSU / Magisk).
#
#  Behavior (no argument = the <> button):
#    * Immediately shows current IPv6 status (ON/OFF)
#    * Volume UP   = enable  IPv6 globally  (toggle=0)
#    * Volume DOWN = disable IPv6 globally  (toggle=1)
#    Default state is DISABLED (OFF). toggle defaults to 1.
# ============================================================

MODDIR=/data/adb/modules/global_ipv6_off
TOGGLE_FILE=$MODDIR/toggle

# default the toggle to 1 (OFF / ipv6 disabled) if missing
[ -f "$TOGGLE_FILE" ] || echo -n "1" > "$TOGGLE_FILE"

status_of() {
    local st
    if [ -r /proc/sys/net/ipv6/conf/wlan0/disable_ipv6 ]; then
        st=$(cat /proc/sys/net/ipv6/conf/wlan0/disable_ipv6)
    else
        st=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo '1')
    fi
    if [ "$st" = "1" ]; then
        echo "OFF (Disable)"
    else
        echo "ON  (Enable)"
    fi
}

disable_now() {
    for iface in /proc/sys/net/ipv6/conf/*/; do
        echo 1 > "${iface}disable_ipv6" 2>/dev/null
        echo 1 > "${iface}disable_ra"    2>/dev/null
        echo 1 > "${iface}disable_policy" 2>/dev/null
    done
    # flush any global ipv6 addresses
    ls /proc/sys/net/ipv6/conf/ 2>/dev/null | while read -r i; do
        [ "$i" = "." ] || [ "$i" = ".." ] && continue
        ip -6 addr flush dev "$i" scope global 2>/dev/null
    done
}

enable_now() {
    for iface in /proc/sys/net/ipv6/conf/*/; do
        echo 0 > "${iface}disable_ipv6"  2>/dev/null
        echo 0 > "${iface}disable_ra"     2>/dev/null
        echo 0 > "${iface}disable_policy" 2>/dev/null
    done
}

# ---------------- CLI args (for manual terminal control) ----------------
case "$1" in
    1|disable|off)
        disable_now; echo -n "1" > "$TOGGLE_FILE"
        echo "[done] IPv6 DISABLED (toggle=1)"
        exit 0
        ;;
    2|enable|on)
        enable_now; echo -n "0" > "$TOGGLE_FILE"
        echo "[done] IPv6 ENABLED (toggle=0)"
        exit 0
        ;;
    3|status)
        echo "IPv6 status : $(status_of)"
        echo "Boot default : $(cat "$TOGGLE_FILE" 2>/dev/null)  (1=OFF / 0=ON)"
        exit 0
        ;;
    "")
        : # no arg -> volume-key interactive below
        ;;
    *)
        echo "usage: action.sh <1|2|3>"
        echo "  1 = disable ipv6, 2 = enable ipv6, 3 = status"
        exit 1
        ;;
esac

# ============================================================
#  < volume-key interactive screen >
# ============================================================
echo "=========================================="
echo "   Global IPv6 Control"
echo "=========================================="
echo ""
echo "   Current IPv6 : $(status_of)"
echo "   Boot default : $(cat "$TOGGLE_FILE")  (1=OFF / 0=ON)"
echo ""
echo "  Volume UP   -> ENABLE  IPv6 globally"
echo "  Volume DOWN -> DISABLE IPv6 globally"
echo ""
echo "   (waiting up to 30s for volume key...)"
echo "=========================================="

# ---- read raw volume-key event (single read, on key press) ----
# NOTE: on this device the physical keys arrive on DIFFERENT input devices:
#   * volume UP    -> event1 (mtk-pmic-keys)  code 0x73 (KEY_VOLUMEUP)
#   * volume DOWN  -> event0 (mtk-kpd)        code 0x72 (KEY_VOLUMEDOWN)
# getevent with NO device arg listens to ALL input devices together, so we can
# catch both regardless of which device they land on. Hence we no longer limit
# to a single $DEV.
wait_volkey() {
    local ev
    ev=$(getevent -c 1 2>/dev/null)   # no device = listen to all
    case "$ev" in
        *'0001 0073 00000001'*) return 0;;   # VOLUME UP   pressed (0x73=115, from event1)
        *'0001 0072 00000001'*) return 1;;   # VOLUME DOWN pressed (0x72=114, from event0/mtk-kpd)
        *'0001 0074 00000001'*) return 1;;   # VOLUME DOWN fallback (0x74=116, some mtk builds)
        *) return 2;;
    esac
}

# accumulate reads until a volume press is captured or timeout
vol_selection=""
i=0
while [ "$i" -lt 10 ]; do   # up to 10 key events / ~30s guard
    wait_volkey
    rc=$?
    if [ "$rc" -eq 0 ]; then
        vol_selection=up; break
    elif [ "$rc" -eq 1 ]; then
        vol_selection=down; break
    fi
    i=$((i+1))
    [ "$i" -ge 10 ] && break
done

case "$vol_selection" in
    up)
        enable_now; echo -n "0" > "$TOGGLE_FILE"
        echo ""
        echo "[+] IPv6 ENABLED  (Volume UP)"
        echo "    New boot default: 0 (ON)"
        ;;
    down)
        disable_now; echo -n "1" > "$TOGGLE_FILE"
        echo ""
        echo "[-] IPv6 DISABLED (Volume DOWN)"
        echo "    New boot default: 1 (OFF)"
        ;;
    *)
        echo ""
        echo "[!] No volume key detected. Aborted (state unchanged)."
        ;;
esac
exit 0