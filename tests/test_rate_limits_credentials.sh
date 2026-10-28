#!/bin/bash
# ABOUTME: Synthetic credential parsing and outbound-call regressions.
# ABOUTME: Run with: bash tests/test_rate_limits_credentials.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/barista-credentials-test.XXXXXX")" || exit 1
trap 'rm -rf "$TEST_ROOT"' EXIT
umask 077
export HOME="$TEST_ROOT/home"
export CLAUDE_CONFIG_DIR="$HOME/.claude"
export TMPDIR="$TEST_ROOT/tmp"
mkdir -p "$CLAUDE_CONFIG_DIR" "$TMPDIR"
DEBUG_MODE=false
PASS=0
FAIL=0
CURL_CALLS="$TEST_ROOT/curl-called"
KEYCHAIN_CALLS="$TEST_ROOT/keychain-called"
CURL_CONFIG="$TEST_ROOT/curl-config"
: > "$CURL_CALLS"
: > "$KEYCHAIN_CALLS"
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        FAIL=$((FAIL + 1))
    fi
}
# Never consult a real Keychain or run a real curl. Force generic curl on Git Bash.
security() { printf 'unexpected call\n' >> "$KEYCHAIN_CALLS"; return 1; }
uname() { printf '%s\n' BaristaCredentialTest; }
curl() {
    local output="" headers="" config=""
    printf 'call\n' >> "$CURL_CALLS"
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -o) output="$2"; shift 2 ;;
            -D) headers="$2"; shift 2 ;;
            --config) config="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [ -n "$output" ] && [ -n "$headers" ] && [ -n "$config" ] || return 1
    cat "$config" > "$CURL_CONFIG"
    printf '%s' synthetic-usage > "$output"
    : > "$headers"
    printf '%s' 200
}
# All defaults resolve inside TEST_ROOT, including cache and logs.
# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/utils.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/rate-limits.sh"
CREDS_FILE="$CLAUDE_CONFIG_DIR/.credentials.json"
write_credentials() { printf '%s' "$1" > "$CREDS_FILE"; chmod 600 "$CREDS_FILE"; }
assert_rejected_file() {
    local desc="$1" token usage rc
    : > "$CURL_CALLS"
    token=$(_get_claude_token)
    assert_eq "$desc: no token" "" "$token"
    usage=$(_get_claude_usage); rc=$?
    assert_eq "$desc: usage fails" "1" "$rc"
    assert_eq "$desc: no usage" "" "$usage"
    assert_eq "$desc: no outbound call" "" "$(cat "$CURL_CALLS")"
}
assert_rejected() { write_credentials "$2"; assert_rejected_file "$1"; }
assert_accepted() {
    local desc="$1" expected="$3" token usage rc
    write_credentials "$2"
    : > "$CURL_CALLS"
    token=$(_get_claude_token)
    assert_eq "$desc: token preserved" "$expected" "$token"
    usage=$(_get_claude_usage); rc=$?
    assert_eq "$desc: usage succeeds" "0" "$rc"
    assert_eq "$desc: synthetic response" "synthetic-usage" "$usage"
    assert_eq "$desc: exactly one stubbed call" "call" "$(cat "$CURL_CALLS")"
    assert_eq "$desc: correct authorization" \
        "$(printf 'header = "Authorization: Bearer %s"\n' "$expected")" "$(cat "$CURL_CONFIG")"
}
echo '=== Credential Parser and Request Tests ==='
assert_accepted "normal token" '{"claudeAiOauth":{"accessToken":"fake-token"}}' "fake-token"
assert_accepted "MCP token is not selected" '{"mcpOAuth":{"server":{"accessToken":"fake-mcp"}},"claudeAiOauth":{"accessToken":"fake-claude"}}' "fake-claude"
assert_accepted "echo-option-like token" '{"claudeAiOauth":{"accessToken":"-n"}}' "-n"
assert_rejected "empty file" ''
assert_rejected "malformed JSON" '{not-json'
assert_rejected "valid token then malformed trailing JSON" '{"claudeAiOauth":{"accessToken":"fake-token"}} {'
assert_rejected "two credential documents" '{"claudeAiOauth":{"accessToken":"fake-one"}} {"claudeAiOauth":{"accessToken":"fake-two"}}'
assert_rejected "valid token then empty document" '{"claudeAiOauth":{"accessToken":"fake-token"}} {}'
assert_rejected "array root" '[{"claudeAiOauth":{"accessToken":"fake-token"}}]'
assert_rejected "null root" 'null'
assert_rejected "missing OAuth object" '{}'
assert_rejected "non-object OAuth value" '{"claudeAiOauth":"fake-token"}'
assert_rejected "MCP-only credentials" '{"mcpOAuth":{"server":{"accessToken":"fake-mcp"}}}'
assert_rejected "missing token" '{"claudeAiOauth":{}}'
assert_rejected "null token" '{"claudeAiOauth":{"accessToken":null}}'
assert_rejected "false token" '{"claudeAiOauth":{"accessToken":false}}'
assert_rejected "true token" '{"claudeAiOauth":{"accessToken":true}}'
assert_rejected "numeric token" '{"claudeAiOauth":{"accessToken":123}}'
assert_rejected "array token" '{"claudeAiOauth":{"accessToken":["fake-token"]}}'
assert_rejected "object token" '{"claudeAiOauth":{"accessToken":{"value":"fake-token"}}}'
assert_rejected "empty token" '{"claudeAiOauth":{"accessToken":""}}'
write_credentials '{"claudeAiOauth":{"accessToken":"fake-token"}}'
chmod 640 "$CREDS_FILE"
assert_rejected_file "group-readable file"
chmod 604 "$CREDS_FILE"
assert_rejected_file "world-readable file"
rm -f "$CREDS_FILE"
assert_rejected_file "missing file"
# Check jq status independently of its filter.
write_credentials '{"claudeAiOauth":{"accessToken":"fake-token"}}'
jq() { printf '%s\n' fake-partial-output; return 1; }
assert_rejected_file "jq failure after producing output"
unset -f jq
jq() { return 127; }
assert_rejected_file "jq unavailable"
unset -f jq
assert_eq "no scenario accesses Keychain" "" "$(cat "$KEYCHAIN_CALLS")"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
