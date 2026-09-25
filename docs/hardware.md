# Hardware observations

These are limited observations on one Apple Silicon Mac and one VITURE Beast with SDK 2.4.0, not a compatibility guarantee for all firmware.

## Pose coordinates

The generic header describes NWU. On the tested Beast, callback quaternions used Y for yaw, X for pitch and Z for roll. Applying an additional NWU conversion swapped motion axes. `mappedPose` therefore normalizes the Beast quaternion directly. The callback array is read as `[roll, pitch, yaw, qw, qx, qy, qz]`.

The regression suite includes a left-turn sample and checks pitch, roll, held orientation and recentering. Actual direction and lack of automatic recentering were confirmed by a wearer.

## Smooth Follow

The pose stream decayed toward center when the native DOF setting was Smooth Follow, even after entering Bypass. Selecting fixed 3DoF before Bypass prevented this on the test device. The adapter saves the original native/display/DOF settings and attempts to restore them on normal disconnect. Force quit cannot run restoration.

## Refresh rate

The SDK's support matrix lists native 2D 120Hz and Bypass SBS 90Hz. During tests, native 120Hz with both DOF 0 and DOF 1, and Bypass SBS 90Hz, all returned success for writes but read back display mode `0x31`. macOS also remained at 60Hz and only enumerated 60Hz modes.

The app's 120Hz option is experimental. It checks device readback and host timing and falls back to 60Hz on failure. Do not advertise working 120Hz until it is verified. The 90Hz SBS probe is not a supported playback mode.

## Brightness and flicker

The test device reported brightness 8/8, tint 8/8 and duty cycle 50%. After selecting 98% duty cycle, the wearer reported improved brightness and less perceived flicker. This is subjective evidence, not a measured flicker certification. Display mode switches may affect device settings; read values again after switching.

## Other limitations

- 5760×2880 HEVC 50fps panorama playback was observed; performance depends on codec, media and hardware.
- HDR is an SDR preview; accurate tone mapping is not implemented.
- SDK calls and media inspection can block the main thread.
- Reconnection, long-term drift, all brightness modes and restoration failure recovery need more testing.
- CI cannot validate device behavior, optical output or perceived comfort.
