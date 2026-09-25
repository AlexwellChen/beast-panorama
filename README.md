# Beast Panorama

A native macOS 360° panorama player with experimental VITURE Beast head tracking.

[简体中文](docs/README.zh-CN.md) · [Development](CONTRIBUTING.md) · [Hardware notes](docs/hardware.md)

Built with Swift, AppKit, Metal and AVFoundation. Open local equirectangular images or videos, then look around with a mouse or a connected Beast headset.

## Features

- 2:1 panorama images and videos, audio playback and automatic video looping.
- 3DoF head tracking, manual recentering and adjustable field of view.
- Auto-hiding playback controls, seeking, volume, mute and drag-and-drop.
- Device brightness, lens tint and display duty-cycle controls when supported.
- Validated 60Hz path; experimental 120Hz switching with readback and fallback.

**120Hz has not worked on the tested headset.** Commands were accepted but the device and macOS remained at 60Hz. HDR is currently an SDR preview; stereoscopic video is not supported. This is an independent community project, not an official VITURE product.

## Requirements

For a ready-to-use installation, download **`Beast-Panorama-0.2.0-arm64-with-sdk.dmg`** from [Releases](https://github.com/AlexwellChen/beast-panorama/releases/tag/v0.2.0). It includes the locally tested proprietary SDK; no separate SDK selection is needed. Review its SDK terms, provenance and outstanding third-party compliance disclosures in the release notes. An SDK-free DMG is also available. The source repository and default builds remain SDK-free.

- Apple Silicon Mac, macOS 13 or later.
- Xcode or Apple Command Line Tools with Swift 5.9 or newer to build.
- Optional: VITURE Beast and a separately obtained macOS arm64 VITURE XR Glasses SDK. Development was tested against SDK 2.4.0.

The proprietary SDK, vendor headers, sample media and personal test recordings are **not included**. Building, running mouse mode and running tests do not require the SDK.

## Build and run

```sh
./scripts/test.sh
./scripts/build-app.sh
open 'dist/public/Beast Panorama.app'
```

For head tracking, obtain the SDK from [VITURE's developer website](https://www.viture.com/developer), keep its macOS libraries together, and choose **眼镜 → 选择 SDK…** in the app. The app remembers your local selection. See [SDK setup](SDK/README.md).

The current UI is in Simplified Chinese.

| Control | Action |
| --- | --- |
| ⌘O / drop a file | Open panorama media |
| Space | Play / pause |
| R | Recenter |
| F / Esc | Enter / leave fullscreen |
| ← / → | Seek five seconds |
| M | Toggle mute |
| ⌘, | Glasses display settings |
| Mouse drag / scroll | Look around without tracking / adjust field of view |

## Package a DMG

```sh
./scripts/build-dmg.sh
```

Produces `dist/public/Beast-Panorama-0.2.0-arm64.dmg` and a SHA-256 checksum. The default DMG contains **no vendor SDK** and supports selecting an external SDK after installation. It is ad-hoc signed, not Developer ID signed or notarized. Do not publish the earlier private, SDK-bundled test DMG as an open-source release.

The vendor permits conditional SDK bundling, but this release has not verified all distribution requirements for the available binary. See [SDK licensing](docs/sdk-licensing.md) and [privacy](Resources/Privacy.txt).

See [release instructions](docs/releasing.md) for clean builds and the optional private SDK-bundled build.

## Project structure

```text
Sources/BeastPanorama/   Application, playback, rendering and SDK adapter
Tests/Smoke/            Hardware-independent regression checks
Resources/              Application icon and user instructions
scripts/                Build, test and packaging tools
SDK/README.md           External SDK setup (no vendor files tracked)
docs/                   Hardware findings and release guide
.github/                CI, issue forms and pull request template
```

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing device behavior. Include device/firmware details and distinguish hardware observations from assumptions. Please do not attach private media, serial numbers or raw USB captures to public reports.

See [SECURITY.md](SECURITY.md) for security reporting and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for dependency boundaries. See [LICENSE](LICENSE) for the application source license; it does not cover the VITURE SDK.
