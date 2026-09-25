# SDK licensing review

Reviewed 2026-09-25. This records the available evidence and release decision, not a legal opinion.

## Subsequent release update

At the maintainer's explicit direction, v0.2.0 now also offers a `with-sdk.dmg` application bundle. It includes the previously tested SDK binaries, SDK-specific end-user terms, privacy information, available upstream notices and provenance disclosures. The binary-specific third-party compliance questions below remain unresolved; publishing the bundle does not establish that those requirements have been satisfied. The following sections preserve the original review rationale. The repository and default build still exclude vendor binaries.

## What the vendor permits

The [VITURE SDK License Agreement](https://www.viture.com/viture-sdk-license-agreement), effective September 2025, is proprietary, not an open-source license. Section 1.3 permits object-code distribution as a component of a developed application, subject to the rest of the agreement. It does not grant permission to publish a standalone SDK or relicense it under MIT. A community wrapper's BSD/MIT license does not cover the vendor binaries.

Section 2 requires an end-user agreement restricting reverse engineering of the SDK, formats and protocols, and requiring users to indemnify, defend and hold VITURE harmless for claims relating to application use/distribution. It also requires applicable notices and imposes other restrictions. Section 8 requires a prominent privacy policy. Branding, support responsibilities and the remaining vendor terms also apply.

## Why this release remains SDK-free

The vendor's [open-source component notice](https://www.viture.com/viture-sdk-license-agreement-sider) lists components including Eigen (MPL 2.0) and libusb (LGPL 2.1) for the XR Glasses SDK. Their obligations are separate from the proprietary SDK grant.

The locally tested 2.4.0 macOS libraries came from the `doppeltilde/viture_kit` community mirror, revision `dd05bbd99da42828203c5127722bcb9609f7e7b0`. That revision has no accompanying macOS-specific license/notice package. Its Android directory contains notices, but those do not establish which components, versions, modifications or linking arrangements apply to the macOS binary. We have not matched the binary to an official vendor checksum.

We therefore have **not verified all prerequisites for publicly redistributing this particular binary**. This is not a finding that VITURE forbids all bundled applications. The public DMG excludes the SDK; users select their separately obtained library. Private local bundles remain possible for a developer's own licensed use, but are not public release assets.

## Before a public bundled release

Obtain the official macOS 2.4.0 distribution and its applicable terms, complete notices and component/source-compliance materials. Confirm which components are actually included and how applicable LGPL/MPL requirements are satisfied; a generic upstream project link alone is not that verification. Add the required SDK-specific end-user agreement/acceptance flow, preserve notices, review privacy and branding, and keep proprietary SDK licensing separate from MIT application code. Publish only the resulting application component bundle, never a standalone SDK archive.

Upstream references:

- [Developer downloads](https://www.viture.com/developer)
- [SDK agreement](https://www.viture.com/viture-sdk-license-agreement)
- [SDK component notice](https://www.viture.com/viture-sdk-license-agreement-sider)
- [Vendor privacy policy](https://www.viture.com/privacy-policy)
