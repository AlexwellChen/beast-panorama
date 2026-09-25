# Contributing

## Local workflow

Use an Apple Silicon Mac with macOS 13+ and Swift 5.9+. No SDK is needed for normal builds or automated checks.

```sh
./scripts/test.sh
swift build -c release
./scripts/build-app.sh
```

Keep changes focused. Include a short description of the user-visible behavior and the checks you ran in your pull request. A bug fix should have a regression check at the relevant boundary when possible. Keep device tests separate from hardware-independent checks.

## Hardware changes

Review [hardware notes](docs/hardware.md). Record SDK version, glasses firmware, macOS version, input mode and observed output. A successful command return is not evidence that a display mode changed. Verify readback, host timing and actual motion behavior. Preserve restoration and fallback paths; never automatically update firmware.

Pose callbacks run on the SDK thread. Copy minimal state under a lock; do not touch AppKit there. Keep vendor ABI declarations in `SDK.swift`. UI copy should describe what people control, not internal SDK details.

## Repository hygiene

Do not commit SDK binaries/headers, media, personal paths, device identifiers, logs, signing identities or credentials. The SDK is dynamically loaded and intentionally absent from CI. Use your own licensed panorama media for visual tests.

`scripts/check-repo.sh` checks the tracked-file boundary and common accidental private content. It supplements, rather than replaces, a review of `git diff --cached`.

## Scope

Useful contributions include asynchronous media loading, measured frame pacing, proper HDR tone mapping, accessibility, localization and reproducible high-refresh support. Avoid claiming hardware support that has not been observed on an actual device.
