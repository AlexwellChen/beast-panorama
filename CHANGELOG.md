# Changelog

## 0.3.0 — 2026-09-26 (public preview)

- Allow mouse dragging while head tracking remains active; R clears both offsets and the head reference.
- Fix vertical dragging turning into roll after looking sideways by applying pitch about the tracked camera's local right axis. Add regression checks across multiple head orientations.
- Add 40–200% picture scaling, expand vertical FOV to 20–90°, and add a 100% / 45° viewing preset. Scale and FOV preferences persist across launches.
- Add 1920×1080 and 1920×1200 output selection at 60Hz without leaving software head tracking. Verify SDK readback and macOS pixel dimensions/timing; request a matching host mode when available and attempt rollback if verification fails.
- Verify native 1920×1200 at 60Hz on the local Apple Silicon / Beast / SDK 2.4.0 setup. HiDPI desktop scaling alone does not qualify as native 1200p.
- Ship an SDK-bundled DMG with the existing SDK terms and provenance disclosures, plus an optional SDK-free DMG.

120Hz remains experimental and unverified. Resolution selection currently uses 60Hz; picture zoom does not change optical focus or physical viewing distance. See [release notes](docs/releases/v0.3.0.md).

## 0.2.0 — 2026-09-25 (public preview)

- Prepare the repository for public development with documentation, CI and contribution templates.
- Make SDK-free app and DMG builds the default; select an external SDK for head tracking.
- Document the conditional SDK redistribution grant and unresolved binary-specific compliance materials; include a privacy notice accessible from the app menu.
- Add clean-checkout and repository hygiene checks.

### Player features

- Native panorama image/video playback and experimental Beast 3DoF tracking.
- Floating playback controls, seeking, audio, fullscreen and remembered preferences.
- Device display settings and guarded 120Hz attempt with 60Hz fallback.
- Correct Beast axis mapping, Smooth Follow behavior and fullscreen canvas sizing.
