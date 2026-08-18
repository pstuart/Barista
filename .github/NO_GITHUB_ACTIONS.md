# No GitHub Actions

This repository does **not** use GitHub Actions for CI, tests, lint, deploy, or releases.

Run lint, tests, and builds locally.

- Deployed Nuxt sites: `stuartdeploy`
- `stuarttech-shared` releases: `scripts/validate-release.sh` then a local git tag
- `stuarttech-nuxt-shared` releases: `bun run verify` then local `changeset publish`

Do not add `.github/workflows/*.yml`.
