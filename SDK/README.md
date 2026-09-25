# External VITURE SDK

Obtain the **XR Glasses SDK** (not the Unity SDK) from https://www.viture.com/developer. Use macOS arm64 libraries and retain their sibling dependencies. The adapter was tested with 2.4.0; other versions need hardware validation.

The repository does not distribute vendor headers or binaries. `SDK/` is ignored except for this file. You may store a locally obtained SDK here or elsewhere.

## Normal use

Build the SDK-free app. Choose **眼镜 → 选择 SDK…** and select `libglasses.dylib`. The selected local path is remembered in macOS preferences, not in the repository. You can also pass `--sdk /path/to/libglasses.dylib` to the app executable.

## Optional private bundle

```sh
VITURE_SDK_DIR='/path/to/macos/libraries' ./scripts/build-app.sh
VITURE_SDK_DIR='/path/to/macos/libraries' BEAST_ALLOW_SDK_BUNDLE=1 ./scripts/build-dmg.sh
```

Only use this when your SDK license permits your intended use. The private DMG is named `*-private-sdk.dmg` to distinguish it from public artifacts. The build signs copies locally; it does not modify the original SDK files. Do not commit or upload the SDK or private bundle without redistribution rights.
