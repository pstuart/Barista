# =============================================================================
# Network Module - Shows IP address and network info
# =============================================================================
# Configuration options:
#   NETWORK_ICON        - Icon for network (default: 🌐)
#   NETWORK_SHOW_LAN    - Show LAN IP (default: true)
#   NETWORK_SHOW_WAN    - Show WAN IP (default: false)
#   NETWORK_WAN_REDACT  - Redact WAN IP for privacy (default: true)
#                         When true, shows e.g. "203.0.xxx.xxx" instead of full IP
#                         Set to "false" to display full public IP
#   NETWORK_SHOW_SSID   - Show WiFi SSID (default: false)
#   NETWORK_COMPACT     - Compact mode (default: false)
#
# Privacy note: When NETWORK_SHOW_WAN is enabled, this module contacts
# external services (ifconfig.me / icanhazip.com) to determine your
# public IP address. Results are cached for 5 minutes at /tmp/.claude_wan_ip.
# =============================================================================

module_network() {
    local icon=$(get_icon "${NETWORK_ICON:-🌐}" "NET:")
    local show_lan="${NETWORK_SHOW_LAN:-true}"
    local show_wan="${NETWORK_SHOW_WAN:-false}"
    local wan_redact="${NETWORK_WAN_REDACT:-true}"
    local show_ssid="${NETWORK_SHOW_SSID:-false}"
    local compact="${NETWORK_COMPACT:-false}"

    local result="$icon"
    local parts=""

    # Get LAN IP
    if [ "$show_lan" = "true" ]; then
        local lan_ip
        if [ "$(uname)" = "Darwin" ]; then
            lan_ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
        else
            lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        fi
        if [ -n "$lan_ip" ]; then
            parts="$lan_ip"
        fi
    fi

    # Get WiFi SSID (macOS)
    if [ "$show_ssid" = "true" ] && [ "$(uname)" = "Darwin" ]; then
        local ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I 2>/dev/null | grep ' SSID' | awk '{print $2}')
        if [ -n "$ssid" ]; then
            if [ -n "$parts" ]; then
                parts="$parts ($ssid)"
            else
                parts="$ssid"
            fi
        fi
    fi

    # Get WAN IP (slow - cached)
    if [ "$show_wan" = "true" ] && ! is_compact "$compact"; then
        local wan_cache="/tmp/.claude_wan_ip"
        local wan_ip=""

        if [ -f "$wan_cache" ]; then
            local cache_age=$(($(date +%s) - $(stat -f %m "$wan_cache" 2>/dev/null || echo 0)))
            if [ "$cache_age" -lt 300 ]; then
                wan_ip=$(cat "$wan_cache")
            fi
        fi

        if [ -z "$wan_ip" ]; then
            wan_ip=$(curl -s --max-time 2 ifconfig.me 2>/dev/null || curl -s --max-time 2 icanhazip.com 2>/dev/null)
            if [ -n "$wan_ip" ]; then
                echo "$wan_ip" > "$wan_cache"
            fi
        fi

        if [ -n "$wan_ip" ]; then
            # Redact WAN IP for privacy by default (e.g., "203.0.xxx.xxx")
            if [ "$wan_redact" = "true" ]; then
                # Handle IPv4: keep first two octets, replace rest with xxx
                if echo "$wan_ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
                    local octet1 octet2
                    octet1=$(echo "$wan_ip" | cut -d. -f1)
                    octet2=$(echo "$wan_ip" | cut -d. -f2)
                    wan_ip="${octet1}.${octet2}.xxx.xxx"
                else
                    # IPv6 or other: show first segment, redact rest
                    wan_ip=$(echo "$wan_ip" | cut -d: -f1-2):xxxx:xxxx
                fi
            fi
            if [ -n "$parts" ]; then
                parts="$parts | $wan_ip"
            else
                parts="$wan_ip"
            fi
        fi
    fi

    if [ -n "$parts" ]; then
        echo "$result $parts"
    fi
}
