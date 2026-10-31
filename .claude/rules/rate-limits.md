---
paths:
  - "modules/rate-limits.sh"
  - "tests/test_rate_limits*.sh"
---

# Rate Limits Module

## Rate Limits Module

The rate limits module (`rate-limits.sh`) is the most complex:
- Fetches usage from Anthropic API using OAuth token from macOS Keychain (handles hex-encoded Keychain output; also works on Linux and Windows/Git Bash)
- Caches responses to avoid excessive API calls
- Backs off after 429 responses, honoring `Retry-After` headers
- Maintains history file for projection calculations
- Implements file size caps to prevent memory issues
- Shows 4-level color indicators for usage thresholds, plus optional progress bars (`RATE_SHOW_PROGRESS_BAR`)
