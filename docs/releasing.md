# Release guide

## Public release

1. Update `VERSION`, `Resources/Info.plist` build number and `CHANGELOG.md`.
2. Run `./scripts/check-repo.sh`, `./scripts/test.sh` and `./scripts/build-dmg.sh` from a clean checkout on Apple Silicon.
3. Ensure `VITURE_SDK_DIR` is **unset**. Inspect the mounted DMG: it must not contain vendor libraries, headers or sample media.
4. Verify with `hdiutil verify`, `codesign --verify --deep --strict` and the app's `--self-check` option. Test playback and headset behavior manually.
5. Follow Apple's Developer ID signing and notarization process if you have the appropriate credentials. This repository only automates ad-hoc signing; do not describe that as notarization.
6. Review the diff and tag the reviewed release. Upload only the public DMG and checksum from `dist/public/` to a GitHub Release.

The workflows build artifacts but **do not publish releases automatically**. A signed DMG does not establish permission to redistribute proprietary contents. Old files at `dist/` may be SDK-bundled personal prototypes; do not upload them.

## Build options

- `BEAST_BUILD_ROOT`: destination directory for the generated app; defaults to `dist/public`.
- `VITURE_SDK_DIR`: explicitly bundle a local SDK for private use. No automatic download.
- `BEAST_ALLOW_SDK_BUNDLE=1`: additional opt-in for a private SDK-bundled DMG. Result has `-private-sdk` in its name.
- `--self-check`: launch-independent package check; no hardware access. Metal may be unavailable in CI.
- `--require-sdk`, `--require-metal`: tighten the self-check for a suitable local environment.

## Before creating the GitHub repository

Create a public repository without generating another README/license, set its URL as this repository's remote, then push your reviewed commit. Enable Issues, private vulnerability reporting and branch protection requiring CI. No repository URL is hard-coded here because the hosting account/name has not been selected.
