# =============================================================================
# Update Module - Daily check for Barista updates
# =============================================================================
# Checks GitHub once per day for a newer release. If found, shows a brief
# notification on the statusline. Respects rate limits and caches aggressively.
#
# Configuration options:
#   UPDATE_CHECK_INTERVAL   - Seconds between checks (default: 86400 = 24h)
#   UPDATE_REPO             - GitHub repo to check (default: pstuart/Barista)
#   UPDATE_ICON             - Icon for update notification (default: arrow up)
# =============================================================================

_check_barista_update() {
    local repo="${UPDATE_REPO:-pstuart/Barista}"
    local cache_key="update_check"
    local check_interval="${UPDATE_CHECK_INTERVAL:-86400}"

    # Validate repo format (owner/name) to prevent URL injection
    case "$repo" in
        *[!A-Za-z0-9_./-]*)
            log_debug "update: rejected unsafe UPDATE_REPO value"
            return
            ;;
    esac

    # Check cache first (default: 24 hours)
    local cached
    cached=$(cache_get "$cache_key" "$check_interval")
    if [ -n "$cached" ]; then
        echo "$cached"
        return
    fi

    # Read local version
    local local_version=""
    local version_file="$SCRIPT_DIR/VERSION"
    if [ -f "$version_file" ]; then
        local_version=$(cat "$version_file" 2>/dev/null | tr -d '[:space:]')
    fi

    if [ -z "$local_version" ]; then
        cache_set "$cache_key" "unknown"
        return
    fi

    # Fetch latest release tag from GitHub API (unauthenticated, low rate limit)
    local response
    response=$(curl -s --max-time 5 --proto =https --max-redirs 3 -w "\n%{http_code}" \
        "https://api.github.com/repos/${repo}/releases/latest" \
        -H "Accept: application/vnd.github+json" 2>/dev/null)

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" != "200" ]; then
        log_debug "update: GitHub API returned HTTP $http_code"
        # Cache the failure so we don't retry for a while (1 hour)
        cache_set "$cache_key" "current"
        return
    fi

    local remote_version
    remote_version=$(echo "$body" | jq -r '.tag_name // empty' 2>/dev/null)
    # Strip leading 'v' if present
    remote_version="${remote_version#v}"

    if [ -z "$remote_version" ]; then
        cache_set "$cache_key" "current"
        return
    fi

    # Compare versions (simple string comparison works for semver)
    if [ "$remote_version" != "$local_version" ] && _version_gt "$remote_version" "$local_version"; then
        cache_set "$cache_key" "available:${remote_version}"
        echo "available:${remote_version}"
    else
        cache_set "$cache_key" "current"
        echo "current"
    fi
}

# Compare two semver strings: returns 0 if $1 > $2
_version_gt() {
    local v1="$1" v2="$2"
    # Split on dots and compare numerically
    local v1_major v1_minor v1_patch v2_major v2_minor v2_patch
    v1_major=$(echo "$v1" | cut -d. -f1)
    v1_minor=$(echo "$v1" | cut -d. -f2)
    v1_patch=$(echo "$v1" | cut -d. -f3)
    v2_major=$(echo "$v2" | cut -d. -f1)
    v2_minor=$(echo "$v2" | cut -d. -f2)
    v2_patch=$(echo "$v2" | cut -d. -f3)

    v1_major=$((v1_major + 0)); v1_minor=$((v1_minor + 0)); v1_patch=$((v1_patch + 0))
    v2_major=$((v2_major + 0)); v2_minor=$((v2_minor + 0)); v2_patch=$((v2_patch + 0))

    if [ "$v1_major" -gt "$v2_major" ]; then return 0; fi
    if [ "$v1_major" -lt "$v2_major" ]; then return 1; fi
    if [ "$v1_minor" -gt "$v2_minor" ]; then return 0; fi
    if [ "$v1_minor" -lt "$v2_minor" ]; then return 1; fi
    if [ "$v1_patch" -gt "$v2_patch" ]; then return 0; fi
    return 1
}

module_update() {
    local result
    result=$(_check_barista_update)

    case "$result" in
        available:*)
            local new_version="${result#available:}"
            local icon
            icon=$(get_icon "${UPDATE_ICON:-⬆}" "UPD:")
            echo "${icon} v${new_version}"
            ;;
    esac
    # Output nothing if current or unknown — module stays silent
}
